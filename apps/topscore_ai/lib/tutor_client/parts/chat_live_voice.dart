part of '../chat_controller.dart';

extension ChatControllerLiveVoice on ChatController {
  // --- Constants ---
  static const Duration _silenceTimeout = Duration(seconds: 12);
  static const Duration _inactivityTimeout = Duration(minutes: 2);

  /// Robust permission check before starting the voice session.
  /// Handles "Denied" and "Permanently Denied" (Blocked) states with clean UX.
  Future<bool> requestMicrophoneAccess(BuildContext context) async {
    // 1. Check current status
    PermissionStatus status = await Permission.microphone.status;

    // 2. Request it if denied (Triggers the browser/system pop-up)
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    // 3. Success
    if (status.isGranted) {
      return true;
    }

    // 4. Recovery path for "Permanently Denied" (Blocked in settings)
    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context.mounted) {
        _showMicrophoneSettingsDialog(context);
      }
    }

    return false;
  }

  void _showMicrophoneSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(CupertinoIcons.mic_slash, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Text(
              "Microphone Blocked",
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "To use Voice Mode, we need access to your microphone. It looks like it's currently blocked.",
              style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildStep(1, "Click the 'Lock' 🔒 icon in the address bar."),
            _buildStep(2, "Toggle Microphone to 'Allow'."),
            _buildStep(3, "Click the 'Retry' button below."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.black45)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Small delay to allow the user to have actually changed settings
              await Future.delayed(const Duration(milliseconds: 500));
              if (context.mounted) {
                startLiveVoiceMode(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text("I've Fixed It - Retry", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
            child: Text("$num", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> startLiveVoiceMode(BuildContext context, {bool feynmanMode = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (_isVoiceMode) return;
    if (authProvider.userModel == null && !authProvider.isGuestMode) return;

    if (!authProvider.canSendMessage) {
      if (authProvider.isGuestMode) {
        if (context.mounted) {
          authProvider.exitGuestMode();
          context.go('/login');
        }
      }
      return;
    }

    _isVoiceMode = true;
    _isLoading = true;
    _liveVoiceErrorMessage = null; // Clear previous errors
    _lastVisualMessage = null; // Clear any old visuals
    _voiceSessionStartTime = DateTime.now();
    notify(); // Trigger UI immediately
    
    developer.log('🎙️ [STEP 0] Voice Session Started at $_voiceSessionStartTime', name: 'ChatController');

    try {
      developer.log('🎙️ [STEP 1] Requesting Permissions', name: 'ChatController');
      final hasPermission = await requestMicrophoneAccess(context);
      if (!hasPermission) {
        _isVoiceMode = false;
        _isLoading = false;
        notify();
        return;
      }
      
      await _audioInput.init();
      await _audioOutput.init();
      await _audioOutput.playStream(); 

      developer.log('🎙️ [STEP 3] Connecting to Gemini Live...', name: 'ChatController');

      final userId = authProvider.isGuestMode ? authProvider.deviceId : (authProvider.userModel?.uid ?? 'guest');
      final threadId = _wsService.threadId;
      var url = '${AppConfig.liveVoiceUrl}?student_id=$userId&thread_id=$threadId';
      if (feynmanMode) {
        url += '&feynman_mode=true';
      }
      
      await _geminiLiveService.connect(url);
      developer.log('🎙️ [STEP 4] Connected successfully', name: 'ChatController');

      // --- Audio Input Pipeline with Barge-In VAD ---
      _liveAudioSubscription = (await _audioInput.startRecordingStream())?.listen((data) {
        if (!_isMicMuted && _isVoiceMode) {
          _geminiLiveService.sendAudio(data);
        }
      });

      // --- AI Audio Output ---
      _liveGeminiAudioSubscription = _geminiLiveService.audioStream.listen((data) {
        if (_isVoiceMode) {
          _audioOutput.addDataToAudioStream(data);
          _resetSilenceTimer(); // AI is speaking → reset silence
        }
      });

      // --- Event Handling (Interruptions, Tool Calls, Turn Complete) ---
      _liveGeminiEventSubscription = _geminiLiveService.events.listen((event) {
        final bool wasNudge = _isSystemNudgeTurn;

        switch (event.type) {
          case GeminiLiveEventType.error:
            developer.log('Live Voice Session Error: ${event.error}');
            _liveVoiceErrorMessage = event.error;
            _isLoading = false;
            notify();
            break;
          case GeminiLiveEventType.interrupted:
            developer.log('Live Voice: AI was interrupted (barge-in)');
            _audioOutput.flushBuffer(); 
            _isSystemNudgeTurn = false;
            _resetInactivityTimer();
            break;
          case GeminiLiveEventType.turnComplete:
            developer.log('Live Voice: Turn complete');
            _resetSilenceTimer(); 
            if (!wasNudge) {
              _resetInactivityTimer();
            }
            _isSystemNudgeTurn = false;
            break;
          case GeminiLiveEventType.toolCall:
            _handleLiveToolCall(event);
            break;
          case GeminiLiveEventType.message:
          case GeminiLiveEventType.quiz:
          case GeminiLiveEventType.flashcards:
          case GeminiLiveEventType.interactiveGraph:
          case GeminiLiveEventType.mnemonic:
          case GeminiLiveEventType.punnettSquare:
          case GeminiLiveEventType.status:
            // Forward rich visuals/messages to the standard chat handler
            if (event.raw != null) {
               final message = handleIncomingMessage(event.raw!);
               // If it's a rich visual (contains more than just text, or is a specific tool type),
               // set it as the last visual message for the peek overlay.
               if (message != null && _isVoiceMode) {
                 final isRich = message.imageUrl != null || 
                                message.quizDataJson != null || 
                                message.flashcardDataJson != null || 
                                message.desmosDataJson != null ||
                                message.graphDataJson != null;
                 if (isRich) {
                    _lastVisualMessage = message;
                    notify();
                 }
               }

               // Auto-scroll so the user sees the new visual in the list behind the overlay
               Future.delayed(const Duration(milliseconds: 300), () {
                 scrollToBottom();
               });
            }
            break;
          default:
            break;
        }
      });

      _isLoading = false;
      notify();
      
      // Delay silence timer to ensure session is settled
      Future.delayed(const Duration(seconds: 2), () {
        if (_isVoiceMode) {
          _startSilenceTimer();
          _startInactivityTimer();
        }
      });
      
      AnalyticsService.instance.logEvent('voice_mode_engaged');
    } catch (e) {
      developer.log('Live Voice Error: $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to connect: $e');
      }
      stopLiveVoiceMode();
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Awkward Silence & Inactivity Handlers ---
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (!_isVoiceMode) return;
      developer.log('💤 Inactivity timeout reached. Stopping voice mode.', name: 'ChatController');
      if (scaffoldKey.currentContext != null && scaffoldKey.currentContext!.mounted) {
        _showErrorSnackBar(scaffoldKey.currentContext!, 'Live Voice session closed due to inactivity.');
      }
      stopLiveVoiceMode();
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_isVoiceMode) {
      _startInactivityTimer();
    }
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (!_isVoiceMode) {
        developer.log('🤫 Silence timer ignored (not in voice mode)', name: 'ChatController');
        return;
      }
      
      // Guard: Don't send a nudge if the session just started (avoid instant bombardment)
      final sessionDuration = DateTime.now().difference(_voiceSessionStartTime ?? DateTime.now());
      if (sessionDuration < const Duration(seconds: 15)) {
         developer.log('🤫 Silence timer ignored (session too new: ${sessionDuration.inSeconds}s)', name: 'ChatController');
         _startSilenceTimer(); // Reschedule if too new
         return;
      }
      
      developer.log('🤫 Awkward silence detected after ${_silenceTimeout.inSeconds}s. Sending hint nudge.', name: 'ChatController');
      
      _isSystemNudgeTurn = true;

      // Send a system injection to the Live API so the AI proactively helps
      _geminiLiveService.sendSystemContext(
        '[SYSTEM INSTRUCTION: The student has been silent for ${_silenceTimeout.inSeconds} seconds. '
        'They may be stuck or thinking. Gently ask if they would like a hint or if they need help '
        'getting started. Be warm and encouraging, not pushy.]'
      );
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    if (_isVoiceMode) {
      _startSilenceTimer();
    }
  }

  // --- Live Tool Call Handler (Function Calling → UI Sync) ---
  void _handleLiveToolCall(GeminiLiveEvent event) {
    developer.log('🔧 Tool call received: ${event.toolName}');
    
    switch (event.toolName) {
      case 'open_flashcard':
        final topic = event.toolArgs?['topic'] as String? ?? 'General';
        // Show a floating flashcard overlay
        addSystemMessage('📋 Opening flashcard: $topic');
        // Send tool response back to AI
        _geminiLiveService.sendText(jsonEncode({
          'type': 'tool_response',
          'name': event.toolName,
          'result': {'status': 'displayed', 'topic': topic}
        }));
        break;
        
      case 'show_diagram':
        final equation = event.toolArgs?['equation'] as String? ?? '';
        addSystemMessage('📊 Generating diagram: $equation');
        _geminiLiveService.sendText(jsonEncode({
          'type': 'tool_response',
          'name': event.toolName,
          'result': {'status': 'displayed', 'equation': equation}
        }));
        break;
        
      case 'highlight_concept':
        final concept = event.toolArgs?['concept'] as String? ?? '';
        addSystemMessage('💡 Key concept: $concept');
        _geminiLiveService.sendText(jsonEncode({
          'type': 'tool_response',
          'name': event.toolName,
          'result': {'status': 'highlighted', 'concept': concept}
        }));
        break;
        
      default:
        developer.log('Unknown tool call: ${event.toolName}');
    }
  }

  Future<void> stopLiveVoiceMode() async {
    _isVoiceMode = false;
    _isLoading = false;
    _isAppVisionEnabled = false;
    _isVideoEnabled = false;
    notify(); // Dismiss UI immediately

    _typingTimer?.cancel(); 
    _silenceTimer?.cancel();
    _appVisionTimer?.cancel();
    _liveAudioSubscription?.cancel();
    _liveVideoSubscription?.cancel();
    _liveGeminiAudioSubscription?.cancel();
    _liveGeminiEventSubscription?.cancel();
    _silenceTimer?.cancel();
    _inactivityTimer?.cancel();
    _appVisionTimer?.cancel();
    _voiceSessionStartTime = null;
    _appVisionTimer = null;
    _liveAudioSubscription = null;
    _liveVideoSubscription = null;
    _liveGeminiAudioSubscription = null;
    _liveGeminiEventSubscription = null;
    _silenceTimer = null;
    _inactivityTimer = null;

    try {
      await _audioInput.stopRecording();
      await _audioOutput.stopStream();
      await _videoInput.stopStreamingImages();
      _geminiLiveService.stop();
    } catch (e) {
      developer.log('Error during stopLiveVoiceMode: $e');
    }
  }

  void toggleMic() {
    _isMicMuted = !_isMicMuted;
    notify();
  }

  Future<void> toggleVideo() async {
    if (_isVideoEnabled) {
      _liveVideoSubscription?.cancel();
      _liveVideoSubscription = null;
      await _videoInput.stopStreamingImages();
      _isVideoEnabled = false;
      notify();
      return;
    }

    // Initialize video on first enable (deferred from startLiveVoiceMode)
    if (!videoIsInitialized) {
      try {
        await _videoInput.init();
        videoIsInitialized = true;
      } catch (e) {
        developer.log('Video init failed: $e');
        return;
      }
    }

    await _videoInput.initializeCameraController();
    _isVideoEnabled = true;
    _liveVideoSubscription = _videoInput.startStreamingImages().listen((frame) {
      if (_isVoiceMode) {
        _geminiLiveService.sendVideoFrame(base64Encode(frame));
      }
    });

    _geminiLiveService.sendSystemContext(
      '[SYSTEM: The user has enabled camera vision. Acknowledge what you see on their desk to confirm the connection.]'
    );
    notify();
  }

  Future<void> toggleAppVision() async {
    if (_isAppVisionEnabled) {
      _appVisionTimer?.cancel();
      _appVisionTimer = null;
      _isAppVisionEnabled = false;
      notify();
      return;
    }

    _isAppVisionEnabled = true;
    _geminiLiveService.sendSystemContext(
      '[SYSTEM: The user has enabled Co-Pilot app vision. Acknowledge that you can see their screen now to confirm the connection.]'
    );
    notify();

    _appVisionTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       if (!_isVoiceMode || !_isAppVisionEnabled) {
          timer.cancel();
          return;
       }

       try {
         final boundary = appRepaintBoundaryKey.currentContext?.findRenderObject();
         if (boundary is! RenderRepaintBoundary) return;

         // Get the image with a lower pixel ratio for compression
         final ui.Image imageInfo = await boundary.toImage(pixelRatio: 0.5);
         final ByteData? byteData = await imageInfo.toByteData(format: ui.ImageByteFormat.png);
         if (byteData == null) return;
         final Uint8List rawBytes = byteData.buffer.asUint8List();

         // Quick resize/jpeg compression with image package
         final img.Image? decoded = img.decodePng(rawBytes);
         if (decoded != null) {
            // resize to 512 width preserving aspect ratio
            final img.Image resized = img.copyResize(decoded, width: 512);
            final Uint8List jpegBytes = img.encodeJpg(resized, quality: 60);
            _geminiLiveService.sendVideoFrame(base64Encode(jpegBytes));
         }
       } catch (e) {
         developer.log('App Vision capture failed: $e');
       }
    });
  }

  void flipCamera() {
    _videoInput.flipCamera();
    notify();
  }

  void scrollDown() {
    scrollToBottom();
  }

  /// Height of the voice control bar for padding calculations.
  static const double voiceControlBarHeight = 140.0;

  /// Builds the floating voice control bar (bottom of screen).
  Widget buildVoiceControlBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Loading / Error inline
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Connecting...', style: GoogleFonts.plusJakartaSans(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            )
          else if (_liveVoiceErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.bolt_slash_fill, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _liveVoiceErrorMessage ?? 'Error',
                      style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      stopLiveVoiceMode();
                    },
                    child: Text('Retry', style: GoogleFonts.plusJakartaSans(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          // Voice visualizer
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(
                height: 40,
                width: double.infinity,
                child: StreamBuilder<wf.Amplitude>(
                  stream: aiAmplitudeStream,
                  builder: (context, snapshot) {
                    final amp = snapshot.data?.current ?? 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(15, (index) {
                        final height = 4.0 + (amp * 30 * (1.0 - (index - 7).abs() / 7));
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 80),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  }
                ),
              ),
            ),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionCircle(
                icon: _isMicMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic,
                color: _isMicMuted ? Colors.redAccent.withValues(alpha: 0.1) : Colors.blueAccent.withValues(alpha: 0.08),
                iconColor: _isMicMuted ? Colors.redAccent : Colors.blueAccent,
                onPressed: toggleMic,
              ),
              _buildActionCircle(
                icon: _isVideoEnabled ? CupertinoIcons.videocam_fill : CupertinoIcons.videocam,
                color: _isVideoEnabled ? Colors.blueAccent : Colors.black.withValues(alpha: 0.05),
                iconColor: _isVideoEnabled ? Colors.white : Colors.black87,
                onPressed: () {
                   if (_isAppVisionEnabled) toggleAppVision();
                   toggleVideo();
                },
              ),
              _buildActionCircle(
                icon: _isAppVisionEnabled ? CupertinoIcons.eyeglasses : CupertinoIcons.eye,
                color: _isAppVisionEnabled ? Colors.purpleAccent : Colors.black.withValues(alpha: 0.05),
                iconColor: _isAppVisionEnabled ? Colors.white : Colors.black87,
                onPressed: () {
                   if (_isVideoEnabled) toggleVideo();
                   toggleAppVision();
                },
              ),
              if (_isVideoEnabled)
                _buildActionCircle(
                  icon: CupertinoIcons.switch_camera,
                  color: Colors.black.withValues(alpha: 0.05),
                  iconColor: Colors.black87,
                  onPressed: flipCamera,
                ),
              _buildActionCircle(
                icon: CupertinoIcons.stop_fill,
                color: Colors.redAccent,
                iconColor: Colors.white,
                onPressed: stopLiveVoiceMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the LAB LIVE / CO-PILOT LIVE indicator badge.
  Widget? buildVoiceIndicatorBadge(BuildContext context) {
    if (!_isVideoEnabled && !_isAppVisionEnabled) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.circle_fill, color: Colors.white, size: 8),
          const SizedBox(width: 8),
          Text(
            _isVideoEnabled ? 'LAB LIVE' : 'CO-PILOT LIVE',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the floating camera preview widget.
  Widget? buildCameraPreview(BuildContext context) {
    if (!_isVideoEnabled || _videoInput.cameraController == null || !_videoInput.cameraController!.value.isInitialized) {
      return null;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
         width: 120,
         height: 180,
         decoration: BoxDecoration(
           border: Border.all(color: Colors.white24, width: 2),
           boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)],
         ),
         child: AspectRatio(
           aspectRatio: _videoInput.cameraController!.value.aspectRatio,
           child: CameraPreview(_videoInput.cameraController!),
         ),
      ),
    );
  }

  /// Legacy method — kept for backward compatibility but now delegates to individual builders.
  Widget buildVoiceOverlay(BuildContext context, ThemeData theme) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 10;
    return Stack(
      children: [
        // Camera preview
        if (buildCameraPreview(context) != null)
          Positioned(
            bottom: bottomPad + voiceControlBarHeight + 10,
            left: 20,
            child: buildCameraPreview(context)!,
          ),
        // Top indicator
        if (buildVoiceIndicatorBadge(context) != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [buildVoiceIndicatorBadge(context)!],
            ),
          ),
        // Bottom control bar
        Positioned(
          bottom: bottomPad,
          left: 12,
          right: 12,
          child: buildVoiceControlBar(context, theme),
        ),
      ],
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 24),
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

}

