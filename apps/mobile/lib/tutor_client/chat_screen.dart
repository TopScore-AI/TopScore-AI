import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'widgets/chat_history_sidebar.dart';
import 'widgets/empty_state_widget.dart';
import 'widgets/session_rating_dialog.dart';

import '../shared/utils/markdown_stripper.dart';
import '../models/video_result.dart';
import '../services/clipboard_service.dart';

import '../utils/paste_handler/paste_handler.dart';
import 'message_model.dart';
import 'camera_screen.dart';
import '../providers/tutor_connection_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../config/api_config.dart';
import 'enhanced_websocket_service.dart';
import '../screens/voice_chat_screen.dart';
import '../providers/navigation_provider.dart';
import '../config/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic>? chatThread;
  final File? initialImageFile;
  final XFile? initialImage;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.chatThread,
    this.initialImageFile,
    this.initialImage,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _backendUrl => ApiConfig.baseUrl;

  final TextEditingController _textController = TextEditingController();

  // Getter for the global WebSocket service
  EnhancedWebSocketService get _wsService =>
      Provider.of<TutorConnectionProvider>(context, listen: false).wsService!;

  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();

  // Voice message playback state
  String? _playingAudioMessageId;
  bool _isPlayingAudio = false;
  final Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  bool _isTyping = false;
  // Add this new variable to track cancellation
  bool _userStoppedGeneration = false;
  String? _currentStreamingMessageId;

  // Throttling timers for streaming UI updates
  Timer? _chunkUpdateTimer;
  Timer? _scrollDebounceTimer;
  final Map<String, String> _pendingChunks = {};

  // TTS state tracking (manual chat bubbles)
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _speakingMessageId;

  // Image Picker instance
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, String>> _dynamicSuggestions = [];

  Timer? _typingTimer;
  Timer? _placeholderTimer;
  int _currentPlaceholderIndex = 0;
  final List<String> _placeholderMessages = [
    'Ask me anything...',
    'How can I help you today?',
    'I can help with math, science, and more!',
    'Try asking for a study plan!',
    'Need help with a problem? Send a photo!'
  ];

  // Settings

  // WebSocket Subscriptions
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsConnectionSub;

  // Firebase RTDB Listener Management
  Query? _messagesRef;
  StreamSubscription? _childAddedSub;
  StreamSubscription? _childChangedSub;
  StreamSubscription? _childRemovedSub;

  // History
  Set<String> _bookmarkedMessageIds = {};
  bool _isLoadingMessages = false;

  // Current chat title — displayed in top bar and synced with sidebar
  String _currentTitle = 'New Chat';

  // Sidebar Search
  String _historySearchQuery = '';
  final TextEditingController _historySearchController =
      TextEditingController();

  // Performance optimization: cache for fast title loading
  final Map<String, String> _titleCache = {};

  // Pagination
  static const int _initialMessageLimit = 50;

  // Message Queuing
  final List<Map<String, dynamic>> _messageQueue = [];

  final FocusNode _messageFocusNode = FocusNode();
  bool _isSidebarInitialized = false;

  // Speech to text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isRecording = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isSidebarInitialized) {
      _isSidebarInitialized = true;
    }
  }

  bool _showScrollDownButton = false;
  ChatMessage? _replyingToMessage;

  // Attachment Staging
  String? _pendingPreviewData; // Base64 Data URI (For local display ONLY)
  String? _pendingFileUrl; // Firebase Storage URL (For sending to AI)
  String? _pendingFileType; // Type of file (image/jpeg, application/pdf, etc.)

  String? _pendingFileName; // Display name
  bool _isUploading = false; // To show spinner

  // Chat folders/tags (TODO: implement folder filtering UI)
  // String? _currentFolder;
  // final List<String> _folders = [
  //   'All',
  //   'Math',
  //   'Science',
  //   'History',
  //   'Language',
  //   'Other'
  // ];

  // Dynamic Suggestions Data Source
  /*
  final List<Map<String, dynamic>> _allSuggestions = [
    {
      'title': 'Explain Quantum Physics',
      'subtitle': 'in simple terms',
      'icon': Icons.science_outlined,
    },
    ...
  ];
  late List<Map<String, dynamic>> _currentSuggestions;
  */

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final connProvider =
          Provider.of<TutorConnectionProvider>(context, listen: false);

      // Auto-connect if not connected
      if (!connProvider.isConnected) {
        connProvider.reconnect();
      }

      // 1. Initial Logic
      _initTts();
      _initSpeech(); // Initialize speech-to-text
      _fetchBookmarks();
      _startPlaceholderRotation();

      // NEW: Listen to global WebSocket messages
      _wsMessageSub = _wsService.messageStream.listen(_handleIncomingMessage);
      _wsConnectionSub = _wsService.isConnectedStream.listen((connected) {
        if (mounted) setState(() {});
      });

      // 2. Load thread if passed from another screen
      _fetchThreadList(silent: true);
      if (widget.chatThread != null) {
        _loadThread(widget.chatThread!['thread_id']);
      }

      // 3. Handle initial data
      final navProvider =
          Provider.of<NavigationProvider>(context, listen: false);

      if (navProvider.pendingThreadId != null) {
        _loadThread(navProvider.pendingThreadId!);
        navProvider.clearPendingData();
      } else if (navProvider.pendingMessage != null ||
          navProvider.pendingImage != null) {
        if (navProvider.pendingImage != null) {
          _processProviderImage(navProvider.pendingImage!, autoSend: true);
        } else if (navProvider.pendingMessage != null) {
          _sendMessage(text: navProvider.pendingMessage);
        }
        navProvider.clearPendingData();
      } else if (widget.initialImage != null) {
        _processProviderImage(widget.initialImage!, autoSend: true);
      } else if (widget.initialImageFile != null) {
        _processProviderImage(XFile(widget.initialImageFile!.path),
            autoSend: true);
      } else if (widget.initialMessage != null) {
        _sendMessage(text: widget.initialMessage);
      }
    });

    // Add scroll listener for smart scroll-to-bottom button
    _scrollController.addListener(_scrollListener);

    // Handle Enter key to send message and Paste shortcut
    _messageFocusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        if (_textController.text.trim().isNotEmpty) {
          _sendMessage();
          return KeyEventResult.handled;
        }
      }

      final isPaste = event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed);

      if (isPaste) {
        if (kIsWeb) return KeyEventResult.ignored;
        _handlePaste();
        return KeyEventResult.ignored;
      }

      return KeyEventResult.ignored;
    };

    registerPasteHandler(
      onImagePasted: (dataUri) async {
        if (!mounted) return;
        final base64Str = dataUri.split(',')[1];
        final bytes = base64Decode(base64Str);
        setState(() {
          _pendingPreviewData = dataUri;
          _pendingFileName = "Pasted Image.png";
          _isUploading = true;
        });
        final url = await _uploadToFirebase(
          bytes,
          'pasted_web_image.png',
          'image/png',
        );
        if (mounted && url != null) {
          setState(() => _pendingFileUrl = url);
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Graceful cleanup: stop generation if still streaming
    if (_isTyping || _currentStreamingMessageId != null) {
      _stopGeneration();
    }

    _wsMessageSub?.cancel();
    _wsConnectionSub?.cancel();
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();
    _chunkUpdateTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _placeholderTimer?.cancel();
    _audioPlayer.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    removePasteHandler();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the app is closed, backgrounded, or detached:
    // stop any pending generation and discard incomplete responses.
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused) {
      if (_isTyping || _currentStreamingMessageId != null) {
        developer.log(
          'App lifecycle: $state — stopping generation and cleaning up',
          name: 'ChatScreen',
        );
        _stopGeneration();

        // Remove the incomplete AI message if it was still streaming
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          final lastMsg = _messages.last;
          if (lastMsg.text.isEmpty || lastMsg.text.trim().isEmpty) {
            _messages.removeLast();
          }
        }

        // Clear the message queue
        _messageQueue.clear();
      }
    }
  }

  // --- Scroll Listener for Smart Scroll Button ---
  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final showBtn =
        (maxScroll - currentScroll) > 400; // Show if scrolled up > 400px

    if (showBtn != _showScrollDownButton) {
      setState(() => _showScrollDownButton = showBtn);
    }
  }

  void _scrollToBottomForce() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _showScrollDownButton = false);
  }

  // --- Helper Methods (Data Loading) ---
  // Suggested questions removed - replaced by dynamic backend suggestions in Empty State

  // REMOVED _loadSuggestedQuestions logic as we use dynamic backend suggestions now
  Future<void> _processProviderImage(
    XFile image, {
    bool autoSend = false,
  }) async {
    try {
      final bytes = await image.readAsBytes();

      // 1. Immediately show preview (Paste)
      final base64Image = base64Encode(bytes);
      if (mounted) {
        setState(() {
          _pendingPreviewData = 'data:image/png;base64,$base64Image';
          _pendingFileName = "Screenshot.png";
          _isUploading = true;
        });
      }

      // 2. Upload in background
      final url = await _uploadToFirebase(
        bytes,
        'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png',
        'image/png',
      );

      if (mounted) {
        setState(() {
          _pendingFileUrl = url;
          _isUploading = false;
        });

        // 3. Auto-Send if requested (e.g., from PDF Viewer) and we have a message
        if (autoSend && _textController.text.isNotEmpty) {
          _sendMessage();
        }
      }
    } catch (e) {
      developer.log("Error processing provider image: $e");
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _fetchBookmarks() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId =
        authProvider.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final ref = FirebaseDatabase.instance.ref('users/$userId/bookmarks');
      final snapshot = await ref.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        setState(() {
          _bookmarkedMessageIds = data.keys.cast<String>().toSet();
          // Update any currently loaded messages
          for (var i = 0; i < _messages.length; i++) {
            if (_bookmarkedMessageIds.contains(_messages[i].id)) {
              _messages[i] = _messages[i].copyWith(isBookmarked: true);
            }
          }
        });
      }
    } catch (e) {
      developer.log("Error fetching bookmarks: $e");
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // --- SMART RATE SETTING ---
    if (kIsWeb) {
      // Web: 1.3 for slightly faster, more engaging pace (Web Speech API scale: 0.1 to 10.0)
      await _flutterTts.setSpeechRate(1.3);
    } else {
      // Android/iOS: 0.5 is roughly "normal" conversational speed
      // (1.0 is often too fast on mobile engines)
      await _flutterTts.setSpeechRate(0.5);
    }

    // Set up TTS state handlers
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = true;
          _isTtsPaused = false;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _isTtsPaused = false;
          _speakingMessageId = null;
        });
      }
    });

    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _isTtsSpeaking = false;
          _isTtsPaused = false;
          _speakingMessageId = null;
        });
      }
    });

    _flutterTts.setPauseHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPaused = true;
        });
      }
    });

    _flutterTts.setContinueHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPaused = false;
        });
      }
    });
  }

  /// Initialize Speech-to-Text
  Future<void> _initSpeech() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      // Speech-to-text is not officially supported or stable on these desktop platforms
      // for this package. We'll disable it for now.
      setState(() {
        _speechEnabled = false;
      });
      return;
    }

    _speechEnabled = await _speechToText.initialize(
      onError: (errorNotification) {
        developer.log('Speech recognition error: ${errorNotification.errorMsg}',
            name: 'ChatScreen');
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Speech recognition error: ${errorNotification.errorMsg}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onStatus: (status) {
        developer.log('Speech recognition status: $status', name: 'ChatScreen');
        if (mounted) {
          setState(() {
            _isRecording = _speechToText.isListening;
          });
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// Toggle speech recognition (start/stop)
  Future<void> _toggleDictation() async {
    if (!_speechEnabled) {
      if (kIsWeb) {
        // Try to re-initialize if it failed before (might have been denied)
        final reInit = await _speechToText.initialize();
        if (reInit) {
          setState(() => _speechEnabled = true);
        } else {
          _showWebMicPermissionGuide();
          return;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Speech recognition not available or permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_isRecording) {
      await _speechToText.stop();
      setState(() {
        _isRecording = false;
      });
    } else {
      // Clear text field before starting new dictation
      _textController.clear();
      setState(() {
        _isRecording = true;
      });
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          }
        },
        listenFor: const Duration(minutes: 1), // Listen for up to 1 minute
        pauseFor:
            const Duration(seconds: 3), // Pause if no speech for 3 seconds
        listenOptions: SpeechListenOptions(
          partialResults: true,
        ),
        localeId: 'en_US',
      );
    }
  }

  Future<void> _saveLastThreadId(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_thread_id', threadId);
  }

  Future<void> _fetchThreadList({bool silent = false}) async {
    try {
      final historyProvider =
          Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId =
          authProvider.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      await historyProvider.fetchHistory(userId, forceRefresh: !silent);

      // Initialize with a new chat if empty
      if (historyProvider.threads.isEmpty) {
        final newId = const Uuid().v4();
        _wsService.setThreadId(newId);
        _saveLastThreadId(newId);

        historyProvider.addThread({
          'thread_id': newId,
          'title': 'New Chat',
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        if (mounted) {
          setState(() {
            _currentTitle = 'New Chat';
          });
        }
      } else {
        // Sync title cache from provider
        for (final t in historyProvider.threads) {
          final tId = t['thread_id'];
          final rawTitle = t['title'];
          if (tId != null && rawTitle != null) {
            _titleCache[tId] = MarkdownStripper.cleanTitle(
              rawTitle.toString(),
              fallback: _getFirstUserMessage() ?? 'New Chat',
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error loading history: $e', name: 'ChatScreen');
    }
  }

  Future<void> _loadThread(String threadId) async {
    // Clean up previous RTDB listeners
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();

    await _saveLastThreadId(threadId);

    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    // FAST: Set title from cache immediately if available
    final cachedTitle = _titleCache[threadId];

    setState(() {
      _isLoadingMessages = true;
      _messages.clear();
      _wsService.setThreadId(threadId);

      // Set the top bar title immediately from cache or history provider
      if (cachedTitle != null) {
        _currentTitle = MarkdownStripper.cleanTitle(
          cachedTitle,
          fallback: _getFirstUserMessage() ?? 'New Chat',
        );
      } else {
        final historyProvider =
            Provider.of<AiTutorHistoryProvider>(context, listen: false);
        final thread = historyProvider.threads.firstWhere(
          (t) => t['thread_id'] == threadId,
          orElse: () => <String, dynamic>{},
        );
        final rawTitle = thread['title'] as String? ?? 'New Chat';
        _currentTitle = MarkdownStripper.cleanTitle(
          rawTitle,
          fallback: _getFirstUserMessage() ?? 'New Chat',
        );
      }
    });

    // OPTIMIZED: Set up RTDB listeners with pagination
    // Load only the last N messages initially for faster load
    _messagesRef = FirebaseDatabase.instance
        .ref('chats/$threadId/messages')
        .orderByChild('timestamp')
        .limitToLast(_initialMessageLimit); // Only load recent messages

    // OPTIMIZED: Batch message updates to reduce setState calls
    final List<ChatMessage> batchedMessages = [];

    // Listen for new messages (also fires for initial load)
    _childAddedSub = _messagesRef!.onChildAdded.listen((event) {
      final key = event.snapshot.key;
      if (key == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final msg = _parseMessageFromFirebase(key, data);

      // Batch updates during initial load
      if (_isLoadingMessages) {
        batchedMessages.add(msg);

        // Commit batch after short delay (reduces redraws)
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted || batchedMessages.isEmpty) return;

          setState(() {
            for (final message in batchedMessages) {
              final existingIdx = _messages.indexWhere(
                (m) => m.id == message.id,
              );
              if (existingIdx == -1) {
                _messages.add(message);
              }
            }
            batchedMessages.clear();
            _isLoadingMessages = false;
          });
          _scrollToBottom();
        });
      } else {
        // Real-time updates: HYBRID STREAMING RECONCILIATION
        setState(() {
          // Check if we already have a temporary version from WebSocket
          final tempIndex = _messages.indexWhere(
            (m) => m.id == key && m.isTemporary,
          );

          if (tempIndex != -1) {
            // REPLACE temporary WebSocket message with final Firebase version
            developer.log(
              '📍 Reconciling: Replacing temporary message $key with Firebase version',
              name: 'ChatScreen',
            );
            _messages[tempIndex] = msg; // msg has isTemporary=false by default
          } else {
            // Check if message already exists (non-temporary)
            final existsIndex = _messages.indexWhere((m) => m.id == key);

            if (existsIndex == -1) {
              // Truly new message - add it
              developer.log(
                '📍 Adding new message from Firebase: $key',
                name: 'ChatScreen',
              );
              _messages.add(msg);

              // Sort by timestamp to maintain order
              _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            } else {
              // Already exists - update it (e.g., edited message)
              developer.log(
                '📍 Updating existing message from Firebase: $key',
                name: 'ChatScreen',
              );
              _messages[existsIndex] = msg;
            }
          }

          // Replace pending user message if matching
          if (msg.isUser) {
            final pendingIdx = _messages.indexWhere(
              (m) => m.id.startsWith('pending-') && m.text == msg.text,
            );
            if (pendingIdx != -1) {
              _messages.removeAt(pendingIdx);
            }
          }

          // Stop typing indicator if this is an assistant message
          if (!msg.isUser) {
            _isTyping = false;
            // _statusMessage = null;
          }

          // Proactive title update: if current title is default, try using first message snippet
          if (_currentTitle == 'New Chat') {
            final firstMsg = _getFirstUserMessage();
            if (firstMsg != null) {
              _currentTitle = MarkdownStripper.cleanTitle(null, fallback: firstMsg);
            }
          }
        });
      }
      _scrollToBottom();
    });

    // Listen for message updates (e.g., when backend finalizes assistant message)
    _childChangedSub = _messagesRef!.onChildChanged.listen((event) {
      final key = event.snapshot.key;
      if (key == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final updatedMsg = _parseMessageFromFirebase(key, data);

      final idx = _messages.indexWhere((m) => m.id == key);
      if (idx != -1) {
        // Always update with Firebase version (source of truth)
        developer.log(
          '📍 Firebase update for message: $key',
          name: 'ChatScreen',
        );

        setState(() {
          _messages[idx] = updatedMsg;
          if (!updatedMsg.isUser) {
            _isTyping = false;
            // _statusMessage = null;
          }
        });
        _scrollToBottom();
      }
    });

    // Listen for message deletions
    _childRemovedSub = _messagesRef!.onChildRemoved.listen((event) {
      final key = event.snapshot.key;
      final idx = _messages.indexWhere((m) => m.id == key);
      if (idx != -1) {
        setState(() => _messages.removeAt(idx));
      }
    });

    setState(() => _isLoadingMessages = false);

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  /// Parse a Firebase RTDB snapshot into a ChatMessage
  ChatMessage _parseMessageFromFirebase(
    String key,
    Map<dynamic, dynamic> data,
  ) {
    // Parse Sources
    List<SourceMetadata>? sources;
    if (data['sources'] != null) {
      sources = (data['sources'] as List)
          .map((s) => SourceMetadata.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    // Parse Quiz Data
    Map<String, dynamic>? quizData;
    if (data['quiz_data'] != null) {
      quizData = Map<String, dynamic>.from(data['quiz_data']);
    }

    // Parse Math Data
    List<String>? mathSteps;
    String? mathAnswer;
    if (data['math_data'] != null) {
      final mData = data['math_data'];
      if (mData['steps'] != null) {
        mathSteps = List<String>.from(mData['steps']);
      }
      mathAnswer = mData['final_answer'];
    }

    // Parse Video Data
    List<VideoResult>? videoResults;
    if (data['video_results'] != null) {
      videoResults = (data['video_results'] as List)
          .map((v) => VideoResult.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }

    // Robust Role Check
    final role = data['role']?.toString().toLowerCase() ?? '';
    final isUser = role == 'user' || role == 'student' || role == 'human';

    // LOGIC: Extract Reasoning from Content or use Reasoning field
    String textContent = data['content']?.toString() ?? '';
    String? reasoningContent = data['reasoning']?.toString();

    // Check for <think> tags in content if reasoning is missing or to clean content
    final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
    final match = thinkRegex.firstMatch(textContent);

    if (match != null) {
      // Found thinking block in content
      final extractedThinking = match.group(1)?.trim();
      if (extractedThinking != null && extractedThinking.isNotEmpty) {
        // Prefer extracted thinking or append if reasoning already exists
        reasoningContent = (reasoningContent ?? '') + extractedThinking;
      }
      // Remove valid thinking block from displayed text
      textContent = textContent.replaceAll(thinkRegex, '').trim();
    }

    return ChatMessage(
      id: key,
      text: textContent,
      isUser: isUser,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        data['timestamp'] is int
            ? data['timestamp']
            : DateTime.now().millisecondsSinceEpoch,
      ),
      imageUrl: data['file_url'],
      audioUrl: data['audio_url'],
      sources: sources,
      quizData: quizData,
      mathSteps: mathSteps,
      mathAnswer: mathAnswer,
      videos: videoResults,
      reasoning: reasoningContent,
      isBookmarked: _bookmarkedMessageIds.contains(key),
    );
  }

  void _startNewChat({bool closeDrawer = true}) {
    // Cancel previous RTDB listeners
    _childAddedSub?.cancel();
    _childChangedSub?.cancel();
    _childRemovedSub?.cancel();

    final newId = const Uuid().v4();
    _wsService.setThreadId(newId);
    _saveLastThreadId(newId);

    final historyProvider =
        Provider.of<AiTutorHistoryProvider>(context, listen: false);
    
    setState(() {
      _messages.clear();
      _currentTitle = 'New Chat';

      // Use provider to add the new thread so sidebar updates in real-time
      historyProvider.addThread({
        'thread_id': newId,
        'title': 'New Chat',
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    });

    if (closeDrawer && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'];
    final messageId = data['id'];

    if (type == null) return;

    // Skip chunks if user stopped generation
    if (_userStoppedGeneration &&
        (type == 'chunk' || type == 'reasoning_chunk')) {
      return;
    }

    switch (type) {
      case 'status':
        if (data['status'] != null) {
          setState(() {
            _isTyping = true;
            // Always show "Thinking..." regardless of backend status message
            // This hides technical messages like "No function needs to be called"
            // _statusMessage = "Thinking...";
          });
        }
        break;

      case 'response_start':
        // Create temporary AI message placeholder
        if (messageId != null) {
          _currentStreamingMessageId = messageId;

          // Check if we already have this message (temporary or permanent)
          final exists = _messages.any((m) => m.id == messageId);

          if (!exists) {
            setState(() {
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: "",
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true, // WebSocket message
                  isComplete: false, // Still streaming
                ),
              );
              _isTyping =
                  false; // Disable global indicator as we have a bubble now
              // _statusMessage = "Thinking...";
            });
            _scrollToBottom();
          }
        }
        break;

      case 'tool_start':
      // Don't show technical "Using tools..." message to users

      // Gemini Native Audio: TTS-only response
      // case 'speech': // Removed
      // case 'audio': // Removed
      //   break; // Removed

      case 'title_updated':
        final updatedThreadId = data['thread_id'] ?? _wsService.threadId;
        final rawTitle = data['title'];
        if (rawTitle != null && rawTitle.toString().isNotEmpty) {
          final newTitle = MarkdownStripper.cleanTitle(
            rawTitle.toString(),
            fallback: _getFirstUserMessage() ?? 'New Chat',
          );
          
          // Use history provider for reactive updates across the app
          final historyProvider = Provider.of<AiTutorHistoryProvider>(
            context,
            listen: false,
          );
          
          historyProvider.addThread({
            'thread_id': updatedThreadId,
            'title': newTitle,
            'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });

          // Update title cache and local top bar state
          _titleCache[updatedThreadId] = newTitle;
          
          if (updatedThreadId == _wsService.threadId) {
            setState(() {
              _currentTitle = newTitle;
            });
          }
        }
        break;

      case 'chunk':
        // Accumulate chunks and throttle setState to prevent UI freeze
        final chunkContent = data['content'] as String? ?? '';
        final targetId = messageId ?? _currentStreamingMessageId;

        if (targetId != null) {
          _pendingChunks[targetId] =
              (_pendingChunks[targetId] ?? '') + chunkContent;

          if (_chunkUpdateTimer?.isActive ?? false) {
            // Timer is running, just accumulate
            return;
          }

          // Trigger update every 100ms
          _chunkUpdateTimer = Timer(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            setState(() {
              for (final entry in _pendingChunks.entries) {
                final cId = entry.key;
                final accumulatedContent = entry.value;

                final index = _messages.indexWhere(
                  (m) => m.id == cId && m.isTemporary,
                );

                if (index != -1) {
                  final currentText = _messages[index].text;
                  _messages[index] = _messages[index].copyWith(
                    text: currentText + accumulatedContent,
                  );
                } else {
                  _messages.add(
                    ChatMessage(
                      id: cId,
                      text: accumulatedContent,
                      isUser: false,
                      timestamp: DateTime.now(),
                      isTemporary: true,
                      isComplete: false,
                    ),
                  );
                  _isTyping = false;
                  _currentStreamingMessageId = cId;
                }
              }
              _pendingChunks.clear();
            });
            _scrollToBottom();
          });
        }
        break;

      case 'reasoning_chunk':
        final rContent = data['content'] as String? ?? '';
        final targetId = messageId ?? _currentStreamingMessageId;

        if (targetId != null) {
          setState(() {
            // Find the temp message or create it if missing
            final index = _messages.indexWhere((m) => m.id == targetId);

            if (index != -1) {
              final oldMsg = _messages[index];
              _messages[index] = oldMsg.copyWith(
                // Append new chunk to existing reasoning
                reasoning: (oldMsg.reasoning ?? "") + rContent,
                // Ensure we don't accidentally mark it as complete yet
                isTemporary: true,
              );
            } else {
              // First chunk of reasoning arrived -> Create placeholder
              _messages.add(
                ChatMessage(
                  id: targetId,
                  text: "", // Empty text triggers the "isThinking" state in UI
                  reasoning: rContent,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: true,
                ),
              );
              _isTyping = false; // Disable global indicator
              _currentStreamingMessageId = targetId;
              _scrollToBottom();
            }
          });
        }
        break;

      case 'done':
      case 'complete':
      case 'end':
        // Flush any pending chunks first!
        _chunkUpdateTimer?.cancel();
        if (_pendingChunks.isNotEmpty) {
          setState(() {
            for (final entry in _pendingChunks.entries) {
              final cId = entry.key;
              final accumulatedContent = entry.value;
              final index = _messages.indexWhere(
                (m) => m.id == cId && m.isTemporary,
              );
              if (index != -1) {
                _messages[index] = _messages[index].copyWith(
                  text: _messages[index].text + accumulatedContent,
                );
              }
            }
            _pendingChunks.clear();
          });
        }

        // Mark temporary message as complete (streaming finished)
        // Firebase will have the final version soon
        final targetId = messageId ?? _currentStreamingMessageId;

        if (targetId != null) {
          setState(() {
            final index = _messages.indexWhere(
              (m) => m.id == targetId && m.isTemporary,
            );

            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                isComplete: true,
                isTemporary: false, // Mark as permanent when streaming ends
              );
            } else {
              // Fallback if already marked permanent
              final permIndex = _messages.indexWhere((m) => m.id == targetId);
              if (permIndex != -1) {
                // No action needed, it's already permanent
              }
            }

            // Update with any final content if provided
            if (data.containsKey('content')) {
              final content = data['content'] as String? ?? '';
              if (content.isNotEmpty && index != -1) {
                _messages[index] = _messages[index].copyWith(
                  text: content,
                  isTemporary: false, // Mark as permanent
                );
              }
            }
          });
        }

        _finalizeTurn();
        break;

      case 'message': // Legacy/Full message handling
        final content = data['content'] as String? ?? '';
        if (content.isNotEmpty && messageId != null) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == messageId);
            if (index != -1) {
              // Update existing message
              _messages[index] = _messages[index].copyWith(
                text: content,
                isComplete: true,
                isTemporary: false, // Mark as permanent
              );
            } else {
              // Add new message
              _messages.add(
                ChatMessage(
                  id: messageId,
                  text: content,
                  isUser: false,
                  timestamp: DateTime.now(),
                  isTemporary: false, // Mark as permanent
                  isComplete: true,
                ),
              );
            }
          });
        }
        _finalizeTurn();
        break;

      // Gemini Live: User interrupted the model mid-response
      case 'interrupted':
        developer.log('Interrupted', name: 'ChatScreen');
        break;

      case 'turn_complete':
        developer.log('Turn complete', name: 'ChatScreen');
        break;

      case 'response':
        // Cache the message
        break;

      case 'error':
        final errorMsg = data['message'] ?? 'Unknown error';
        if (!_messages.any((m) => m.text.contains(errorMsg))) {
          _addSystemMessage('Error: $errorMsg');
        }
        _finalizeTurn();
        break;

      case 'suggestions':
        if (data['suggestions'] != null && data['suggestions'] is List) {
          final rawList = data['suggestions'] as List;
          try {
            final parsedSuggestions = rawList.map((item) {
              final map = Map<String, dynamic>.from(item);
              return {
                'emoji': map['emoji']?.toString() ?? '✨',
                'title': map['title']?.toString() ?? '',
                'subtitle': map['subtitle']?.toString() ?? '',
              };
            }).toList();

            setState(() {
              _dynamicSuggestions = parsedSuggestions;
              // Clear chips below input area as requested
              // _displayedQuestions = []; // REMOVED
            });
            developer.log(
              "💡 Received dynamic suggestions: $parsedSuggestions",
            );
          } catch (e) {
            developer.log("Error parsing suggestions: $e");
          }
        }
        break;

      default:
        // Handle Sources
        if (data.containsKey('sources')) {
          _handleSources(data);
        }
        break;
    }
  }

  void _handleSources(Map<String, dynamic> data) {
    final sourcesData = data['sources'];
    if (sourcesData == null || sourcesData is! List) return;

    final sourcesList =
        sourcesData.map((s) => SourceMetadata.fromJson(s)).toList();

    setState(() {
      if (_currentStreamingMessageId != null) {
        final index = _messages.indexWhere(
          (m) => m.id == _currentStreamingMessageId,
        );
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(sources: sourcesList);
        }
      } else if (_messages.isNotEmpty && !_messages.last.isUser) {
        // Attach to the last AI message if no streaming message
        _messages[_messages.length - 1] = _messages.last.copyWith(
          sources: sourcesList,
        );
      }
    });
  }

  void _finalizeTurn() {
    if (mounted) {
      setState(() {
        _currentStreamingMessageId = null;
        _isTyping = false; // STOP LOADING
      });

      // Auto-refresh the chat title after the AI responds.
      // The backend generates a title after the first exchange;
      // trigger the refresh immediately when streaming finishes.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _refreshCurrentTitle();
      });

      // Check for queued messages
      if (_messageQueue.isNotEmpty) {
        final nextMessage = _messageQueue.removeAt(0);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        setState(() {
          _isTyping = true;
          _userStoppedGeneration = false;
        });

        _wsService.sendMessage(
          message: nextMessage['message'] ?? '',
          userId: authProvider.userModel?.uid ?? 'anon',
          fileUrl: nextMessage['fileUrl'],
          fileType: nextMessage['fileType'] ?? 'image',
        );
      }
    }
  }

  /// Refresh the current thread's title from the backend
  /// and update both the top bar and the sidebar entry.
  Future<void> _refreshCurrentTitle() async {
    try {
      final historyProvider =
          Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;
      if (userId == null) return;

      final currentThreadId = _wsService.threadId;
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/api/history/$userId?limit=20',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final threads = data is List ? data : (data['threads'] as List? ?? []);

        // Find the current thread and update the title
        for (final t in threads) {
          if (t['thread_id'] == currentThreadId) {
            final newTitle = MarkdownStripper.cleanTitle(
              t['title'],
              fallback: _getFirstUserMessage() ?? 'New Chat',
            );
            if (newTitle != _currentTitle && mounted) {
              setState(() {
                _currentTitle = newTitle;
              });
              // Update using provider
              historyProvider.addThread({
                'thread_id': currentThreadId,
                'title': newTitle,
                'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              });
            }
            break;
          }
        }
      }
    } catch (e) {
      developer.log('Title refresh error: $e', name: 'ChatScreen');
    }
  }

  void _addSystemMessage(String text) {
    _messages.add(
      ChatMessage(
        id: const Uuid().v4(),
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    _scrollToBottom();
  }

  String? _getFirstUserMessage() {
    try {
      final userMsgs = _messages.where((m) => m.isUser).toList();
      if (userMsgs.isEmpty) return null;
      return userMsgs.first.text;
    } catch (_) {
      return null;
    }
  }

  void _clearPendingAttachment() {
    setState(() {
      _pendingPreviewData = null;
      _pendingFileUrl = null;
      _pendingFileType = null;

      _pendingFileName = null;
      _isUploading = false;
    });
  }

  Future<String?> _uploadToFirebase(
    Uint8List data,
    String fileName,
    String mimeType,
  ) async {
    try {
      setState(() => _isUploading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId =
          authProvider.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;
      final uuid = const Uuid().v4();

      // Create a reference: uploads/{userId}/{uuid}_{filename}
      final ref = FirebaseStorage.instance.ref().child(
            'uploads/$userId/${uuid}_$fileName',
          );

      final metadata = SettableMetadata(contentType: mimeType);

      // Upload
      final snapshot = await ref.putData(data, metadata);

      // Get URL
      final url = await snapshot.ref.getDownloadURL();

      if (mounted) setState(() => _isUploading = false);
      return url;
    } catch (e) {
      developer.log('Upload Error: $e', name: 'ChatScreen');
      setState(() => _isUploading = false);
      return null;
    }
  }

  Future<void> _downloadImage(String url) async {
    if (!mounted) return;
    await ClipboardService.instance.shareImage(
      context,
      url,
      caption: 'Image from AI Tutor',
    );
  }

  // NEW: Method to stop generation
  void _stopGeneration() {
    setState(() {
      _isTyping = false;
      _currentStreamingMessageId = null;
      // _statusMessage = null;
      _userStoppedGeneration = true; // Ignore subsequent chunks
    });
    _finalizeTurn();
  }

  void _showDailyLimitReached() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Daily Limit Reached'),
        content: const Text(
          'You\'ve reached your daily message limit. Upgrade your plan or wait 24 hours for it to reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage({String? text, String? fileUrl}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final historyProvider =
        Provider.of<AiTutorHistoryProvider>(context, listen: false);
    if (!authProvider.canSendMessage) {
      _showDailyLimitReached();
      return;
    }

    String messageText = text ?? _textController.text;
    final fileUrlToSend = fileUrl ?? _pendingFileUrl;
    final fileTypeToSend =
        _pendingFileType ?? 'image'; // Default to image if null

    if (messageText.trim().isNotEmpty || fileUrlToSend != null) {
      await authProvider.incrementDailyMessage();
    }

    // Validation: Require text when sending an image
    if (messageText.trim().isEmpty && fileUrlToSend != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a message to accompany your image'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (messageText.trim().isEmpty && fileUrlToSend == null) return;

    // Reset user-stopped flag for new turn
    _userStoppedGeneration = false;

    // Generate pending ID for optimistic add (RTDB will replace with real ID)
    final pendingId = 'pending-${const Uuid().v4()}';

    // Check if AI is busy
    final isBusy = _isTyping || _currentStreamingMessageId != null;

    setState(() {
      _messages.add(
        ChatMessage(
          id: pendingId,
          text: messageText,
          isUser: true,
          timestamp: DateTime.now(),
          imageUrl: fileUrlToSend,
          replyToId: _replyingToMessage?.id,
          replyToText: _replyingToMessage?.text,
        ),
      );

      // Optimistic History Update via provider
      final threadId = _wsService.threadId;
      historyProvider.addThread({
        'thread_id': threadId,
        'title': _currentTitle,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      _isTyping = true;
      // _statusMessage = "Connecting...";

      _textController.clear();
      _replyingToMessage = null; // Clear reply state
      _pendingFileUrl = null;
      _pendingPreviewData = null;
      _pendingFileName = null;
      _pendingFileType = null;
      _isUploading = false;
    });

    _scrollToBottom();

    if (isBusy) {
      developer.log("AI is busy, queuing message", name: "ChatScreen");
      _messageQueue.add({
        'message': messageText,
        'fileUrl': fileUrlToSend,
        'fileType': fileTypeToSend,
      });
      return;
    }

    // SAFETY TIMEOUT: Stop loading if no response for 30s
    Timer(const Duration(seconds: 30), () {
      if (mounted && _isTyping) {
        _finalizeTurn();
        // Optional: show a small toast or snackbar silently
      }
    });

    try {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      final userModel = authProvider.userModel;

      _wsService.sendMessage(
        message: messageText,
        userId: userModel?.uid ?? 'anon',
        fileUrl: fileUrlToSend,
        fileType: fileTypeToSend,
        extraData: {
          'user_role': userModel?.role ?? 'student',
          'user_interests': userModel?.interests ?? [],
          'user_grade': userModel?.grade,
          'user_curriculum': userModel?.curriculum,
          if (_replyingToMessage != null) 'reply_to_id': _replyingToMessage!.id,
          if (_replyingToMessage != null)
            'reply_to_text': _replyingToMessage!.text,
        },
        dataSaver: settings.isLiteMode,
      );
    } catch (e) {
      _addSystemMessage("Failed to send: $e");
      _finalizeTurn();
    }
  }

  Future<void> _pickFile(
    FileType type, {
    List<String>? allowedExtensions,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        withData: true,
        allowMultiple: false,
      );

      if (result != null) {
        final file = result.files.single;
        final path = file.path;
        final bytes = file.bytes ??
            (path != null ? await File(path).readAsBytes() : null);
        if (bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to read file. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final extension = file.extension?.toLowerCase() ?? '';
        final isImage = [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
        ].contains(extension);

        final isDocument = [
          'pdf',
          'doc',
          'docx',
          'txt',
          'epub',
          'odt',
        ].contains(extension);

        // Determine MIME type
        String mimeType;
        if (isImage) {
          mimeType = 'image/$extension';
        } else if (isDocument) {
          switch (extension) {
            case 'pdf':
              mimeType = 'application/pdf';
              break;
            case 'doc':
              mimeType = 'application/msword';
              break;
            case 'docx':
              mimeType =
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
              break;
            case 'txt':
              mimeType = 'text/plain';
              break;
            case 'epub':
              mimeType = 'application/epub+zip';
              break;
            case 'odt':
              mimeType = 'application/vnd.oasis.opendocument.text';
              break;
            default:
              mimeType = 'application/octet-stream';
          }
        } else {
          mimeType = 'application/octet-stream';
        }

        // Preview Data (only for images)
        String? previewData;
        if (isImage) {
          final base64Data = base64Encode(bytes);
          previewData = 'data:$mimeType;base64,$base64Data';
        }

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = file.name;
          _pendingFileType = mimeType;
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
          mimeType,
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to upload file. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      developer.log('File Pick Error: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      XFile? photo;

      // Use ImagePicker for web and mobile browsers (better compatibility)
      if (kIsWeb) {
        photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } else {
        // Use native camera for mobile apps
        photo = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CameraScreen()),
        );
      }

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final extension = photo.path.split('.').last.toLowerCase();
        final validExtension =
            ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
                ? extension
                : 'jpg';
        final base64Image = base64Encode(bytes);
        final previewData = 'data:image/$validExtension;base64,$base64Image';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = "Camera Photo";
          _pendingFileType = 'image/$validExtension';
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          'camera_photo_${DateTime.now().millisecondsSinceEpoch}.$validExtension',
          'image/$validExtension',
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
            }
          });
        }
      }
    } catch (e) {
      developer.log('Error taking photo: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              kIsWeb
                  ? 'Camera access denied or not available. Please check browser permissions.'
                  : 'Failed to capture photo. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();
        final validExtension =
            ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)
                ? extension
                : 'jpg';
        final base64Image = base64Encode(bytes);
        final previewData = 'data:image/$validExtension;base64,$base64Image';

        if (!mounted) return;
        setState(() {
          _isUploading = true;
          _pendingPreviewData = previewData;
          _pendingFileName = image.name;
          _pendingFileType = 'image/$validExtension';
        });

        // Upload
        final url = await _uploadToFirebase(
          bytes,
          'gallery_image_${DateTime.now().millisecondsSinceEpoch}.$validExtension',
          'image/$validExtension',
        );

        if (mounted) {
          setState(() {
            _isUploading = false;
            if (url != null) {
              _pendingFileUrl = url;
            } else {
              _clearPendingAttachment();
            }
          });
        }
      }
    } catch (e) {
      developer.log('Error picking image: $e', name: 'ChatScreen');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _cleanMarkdown(String text) => MarkdownStripper.strip(text);

  Future<void> _speak(String text, {String? messageId}) async {
    // Clean the text before speaking
    final textToSpeak = _cleanMarkdown(text);
    if (textToSpeak.isNotEmpty) {
      setState(() {
        _speakingMessageId = messageId;
      });
      await _flutterTts.speak(textToSpeak);
    }
  }

  Future<void> _pauseTts() async {
    await _flutterTts.pause();
  }

  Future<void> _resumeTts() async {
    await _flutterTts.speak(""); // Resume speaking
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isTtsSpeaking = false;
        _isTtsPaused = false;
        _speakingMessageId = null;
      });
    }
  }

  // Voice message playback controls
  Future<void> _playVoiceMessage(String messageId, String audioUrl) async {
    try {
      // Stop if already playing this message
      if (_playingAudioMessageId == messageId && _isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
        return;
      }

      // Stop any currently playing audio
      if (_playingAudioMessageId != null &&
          _playingAudioMessageId != messageId) {
        await _audioPlayer.stop();
      }

      setState(() {
        _playingAudioMessageId = messageId;
        _isPlayingAudio = true;
        _audioPosition = Duration.zero;
      });

      // Play from URL (works for both local paths and remote URLs)
      if (audioUrl.startsWith('http')) {
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        await _audioPlayer.play(DeviceFileSource(audioUrl));
      }
    } catch (e) {
      developer.log('Error playing voice message: $e', name: 'ChatScreen');
      setState(() {
        _isPlayingAudio = false;
        _playingAudioMessageId = null;
      });
    }
  }

  Future<void> _resumeVoiceMessage() async {
    try {
      await _audioPlayer.resume();
      setState(() {
        _isPlayingAudio = true;
      });
    } catch (e) {
      developer.log('Error resuming voice message: $e', name: 'ChatScreen');
    }
  }

  Future<void> _pauseVoiceMessage() async {
    try {
      await _audioPlayer.pause();
      setState(() {
        _isPlayingAudio = false;
      });
    } catch (e) {
      developer.log('Error pausing voice message: $e', name: 'ChatScreen');
    }
  }

  void _copyToClipboard(String text) {
    ClipboardService.instance.copyWithFeedback(context, text);
  }

  Future<void> _handlePaste() async {
    try {
      final clipboard = ClipboardService.instance;
      final result = await clipboard.readClipboard();

      if (!result.hasContent) return;

      // Image paste — show preview and upload
      if (result.hasImage) {
        final base64Image = base64Encode(result.imageBytes!);

        setState(() {
          _pendingPreviewData = 'data:image/png;base64,$base64Image';
          _pendingFileName = "Pasted Image.png";
          _isUploading = true;
        });

        final url = await _uploadToFirebase(
          result.imageBytes!,
          'pasted_image.png',
          'image/png',
        );

        if (mounted) {
          if (url != null) {
            setState(() => _pendingFileUrl = url);
          } else {
            _clearPendingAttachment();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to upload image")),
            );
          }
        }
        return;
      }

      // Text paste — insert at cursor
      if (result.hasText) {
        clipboard.pasteIntoController(_textController, result.text!);
      }
    } catch (e) {
      developer.log('Paste Error: $e', name: 'ChatScreen');
    }
  }

  // Logic to handle "Edit and Send Back" with dialog
  void _handleUserEdit(ChatMessage message) {
    final TextEditingController editController = TextEditingController(
      text: message.text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final editedText = editController.text.trim();
              if (editedText.isEmpty) {
                Navigator.pop(context);
                return;
              }

              Navigator.pop(context);
              await _editAndResend(message, editedText);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // Delete old message pair and resend edited message
  Future<void> _editAndResend(
    ChatMessage userMessage,
    String editedText,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;
      final threadId = _wsService.threadId;

      if (userId == null) return;

      // Find the AI response that came after this user message
      final userIndex = _messages.indexWhere((m) => m.id == userMessage.id);
      String? aiResponseId;

      if (userIndex != -1 && userIndex < _messages.length - 1) {
        final nextMessage = _messages[userIndex + 1];
        if (!nextMessage.isUser) {
          aiResponseId = nextMessage.id;
        }
      }

      // Delete from Firebase RTDB
      final messagesRef = FirebaseDatabase.instance.ref(
        'chats/$threadId/messages',
      );

      // Delete user message
      await messagesRef.child(userMessage.id).remove();

      // Delete AI response if exists
      if (aiResponseId != null) {
        await messagesRef.child(aiResponseId).remove();
      }

      // Remove from local state (RTDB listener will handle this, but do it immediately for UX)
      setState(() {
        _messages.removeWhere(
          (m) =>
              m.id == userMessage.id ||
              (aiResponseId != null && m.id == aiResponseId),
        );
      });

      // Send the edited message as a new message
      await _sendMessage(text: editedText, fileUrl: userMessage.imageUrl);
    } catch (e) {
      developer.log('Error editing message: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to edit message')));
      }
    }
  }

  Future<void> _toggleBookmark(ChatMessage message) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userModel?.uid;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to bookmark messages.'),
        ),
      );
      return;
    }

    final newState = !message.isBookmarked;
    final index = _messages.indexWhere((m) => m.id == message.id);

    if (index != -1) {
      setState(() {
        _messages[index] = _messages[index].copyWith(isBookmarked: newState);
      });
    }

    final ref = FirebaseDatabase.instance.ref(
      'users/$userId/bookmarks/${message.id}',
    );

    if (newState) {
      // Save full message details
      try {
        await ref.set({
          'text': message.text,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'thread_id': _wsService.threadId,
          'role': message.isUser ? 'user' : 'ai',
          // Optional: save other metadata if needed
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved to Library')));
        }
      } catch (e) {
        developer.log('Bookmark Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save bookmark')),
          );
        }
      }
    } else {
      await ref.remove();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from Library')));
      }
    }
  }
  // ---------------------------

  // Logic for Sharing
  void _shareMessage(String text) {
    ClipboardService.instance.shareText(text);
  }

  // Regenerate response
  Future<void> _regenerateResponse(ChatMessage message) async {
    // Stop any active TTS playback first
    await _stopTts();

    // Find the user message that triggered this response
    final messageIndex = _messages.indexOf(message);
    if (messageIndex > 0) {
      final previousMessage = _messages[messageIndex - 1];
      if (previousMessage.isUser) {
        // Remove the current AI response and clear streaming state
        setState(() {
          _messages.remove(message);
          _currentStreamingMessageId = null;
          _isTyping = true;
        });
        // Re-send the user's message
        if (mounted) {
          _wsService.sendMessage(
            message: previousMessage.text,
            userId: Provider.of<AuthProvider>(
              context,
              listen: false,
            ).userModel!.uid,
          );
        }
      }
    }
  }

  // Provide feedback (thumbs up/down)
  void _provideFeedback(ChatMessage message, int feedback) {
    final index = _messages.indexOf(message);
    if (index != -1) {
      setState(() {
        // Toggle off if same feedback, otherwise set new feedback
        final newFeedback = message.feedback == feedback ? null : feedback;
        _messages[index] = message.copyWith(feedback: newFeedback);
      });
      // Optionally send feedback to backend
      developer.log(
        'Feedback for message ${message.id}: $feedback',
        name: 'ChatScreen',
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollDebounceTimer?.isActive ?? false) return;

    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      // Smart auto-scroll: Only scroll if user is already near bottom or it's a new user message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          final current = _scrollController.position.pixels;
          // Auto-scroll if within 400px of bottom OR the last message is from user
          if ((max - current) < 400 ||
              (_messages.isNotEmpty && _messages.last.isUser)) {
            _scrollController.animateTo(
              max,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    });
  }

  void _startPlaceholderRotation() {
    _placeholderTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _textController.text.isEmpty) {
        setState(() {
          _currentPlaceholderIndex =
              (_currentPlaceholderIndex + 1) % _placeholderMessages.length;
        });
      }
    });
  }

  Future<void> _deleteAllChatHistory() async {
    final historyProvider =
        Provider.of<AiTutorHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId =
        authProvider.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final success = await historyProvider.deleteAllThreads(userId);
    if (success && mounted) {
      setState(() {
        _messages.clear();
        _startNewChat();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All chats deleted')),
      );
    }
  }

  // Search Messages - Unused, cleanup
  // void _searchMessages(String query) { ... }
  // void _toggleSearch() { ... }

  // Generate Flashcards from Conversation - Unused, cleanup
  // void _generateFlashcards() { ... }
  // void _showFlashcardsDialog() { ... }

  // 1. Logic to delete from Firebase and update UI
  Future<void> _deleteThread(String threadId) async {
    try {
      // API CALL to delete thread
      await http.delete(
        Uri.parse('$_backendUrl/threads/$threadId'),
      );

      if (!mounted) return;
      final historyProvider =
          Provider.of<AiTutorHistoryProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;

      if (userId != null && await historyProvider.deleteThread(userId, threadId)) {
        setState(() {
          // If we deleted the active chat, start a new one
          if (_wsService.threadId == threadId) {
            _startNewChat(closeDrawer: false);
          }
        });
      } else {
        throw Exception('Delete failed');
      }
    } catch (e) {
      developer.log('Error deleting thread: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to delete chat')));
      }
    }
  }

  // 2. Confirmation Dialog
  void _confirmDeleteThread(String threadId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteThread(threadId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // 1. Update Firebase and Local State
  Future<void> _renameThread(String threadId, String newTitle) async {
    try {
      // API CALL to rename thread
      final response = await http.patch(
        Uri.parse('$_backendUrl/threads/$threadId/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': newTitle}),
      );

      if (response.statusCode == 200) {
        // Sync with provider
        if (!mounted) return;
        final historyProvider =
            Provider.of<AiTutorHistoryProvider>(context, listen: false);
        historyProvider.addThread({
          'thread_id': threadId,
          'title': newTitle,
          'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        });

        // Update Local UI immediately
        setState(() {
          // Sync cache
          final cleanTitle = MarkdownStripper.cleanTitle(newTitle);
          _titleCache[threadId] = cleanTitle;

          // Update top bar if renaming the active thread
          if (threadId == _wsService.threadId) {
            _currentTitle = cleanTitle;
          }
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Error renaming thread: $e', name: 'ChatScreen');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to rename chat')));
      }
    }
  }

  // 2. Show Input Dialog
  void _showRenameDialog(String threadId, String currentTitle) {
    final TextEditingController renameController = TextEditingController(
      text: currentTitle,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) {
            if (renameController.text.trim().isNotEmpty) {
              Navigator.pop(ctx);
              _renameThread(threadId, renameController.text.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _renameThread(threadId, renameController.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => SessionRatingDialog(
        onSubmit: () {
          // Logic to handle rating submission (e.g., analytics)
          developer.log("Session Rated", name: "ChatScreen");
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent, // Transparent to show gradient
      extendBodyBehindAppBar: true,
      drawer: _buildMobileDrawer(theme, isDark),
      appBar: _buildMobileAppBar(theme, isDark),
      body: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: _buildMainChatArea(theme),
        ),
      ),
    );
  }

  Future<void> _refreshChat() async {
    // threadId is non-nullable and always has a value in EnhancedWebSocketService
    await _loadThread(_wsService.threadId);
  }

  PreferredSizeWidget _buildMobileAppBar(ThemeData theme, bool isDark) {
    // Use theme's onSurface — guaranteed to contrast with scaffold background
    final appBarContentColor = theme.colorScheme.onSurface;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: 0,
        blur: 15,
        opacity: isDark ? 0.1 : 0.7,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1),
            width: 1,
          ),
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: appBarContentColor,
            ),
            tooltip: 'Chat history',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            MarkdownStripper.cleanTitle(_currentTitle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.quicksand(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: appBarContentColor,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.edit_square,
                color: appBarContentColor,
              ),
              tooltip: 'New Chat',
              onPressed: () => _startNewChat(closeDrawer: false),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(ThemeData theme, bool isDark) {
    final historyProvider = Provider.of<AiTutorHistoryProvider>(context);
    return Drawer(
      backgroundColor: Colors.transparent, // Transparent to show glass effect
      elevation: 0,
      child: ChatHistorySidebar(
        isDark: isDark,
        threads: historyProvider.threads,
        historySearchQuery: _historySearchQuery,
        historySearchController: _historySearchController,
        isLoadingHistory: historyProvider.isLoading,
        currentThreadId: _wsService.threadId,
        onCloseSidebar: () => Navigator.pop(context),
        onStartNewChat: _startNewChat,
        onLoadThread: _loadThread,
        onRenameThread: _showRenameDialog,
        onDeleteThread: _confirmDeleteThread,
        onDeleteAllThreads: _deleteAllChatHistory,
        onFinishLesson: _showRatingDialog,
        onSearchChanged: (value) {
          setState(() {
            _historySearchQuery = value;
            if (value.isEmpty) {
              _historySearchController.clear();
            }
          });
        },
      ),
    );
  }

  /* Widget _buildSearchResults(ThemeData theme) { ... } */

  // Widget _buildSuggestionCard(...) REMOVED

  /// Show attachment menu as bottom sheet
  void _showAttachmentMenu(ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              _buildAttachmentOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                color: isDark ? Colors.purpleAccent : Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.camera_alt_outlined,
                label: kIsWeb ? 'Capture Photo' : 'Take Photo',
                color: isDark ? Colors.lightBlueAccent : Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              _buildAttachmentOption(
                icon: Icons.description_outlined,
                label: 'Upload Document',
                color: isDark ? Colors.orangeAccent : Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _pickFile(
                    FileType.custom,
                    allowedExtensions: const [
                      'pdf',
                      'doc',
                      'docx',
                      'epub',
                      'txt',
                      'odt',
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Helper widget for attachment options
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _buildMainChatArea(ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Messages area
            Expanded(
              child: Stack(
                children: [
                  _isLoadingMessages
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        )
                      : _messages.isEmpty
                          ? EmptyStateWidget(
                              isDark: isDark,
                              theme: theme,
                              userName: authProvider.userModel?.displayName,
                              suggestions: _dynamicSuggestions,
                              onSuggestionTap: (prompt) =>
                                  _sendMessage(text: prompt),
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshChat,
                              color: theme.primaryColor,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 24,
                                ),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  final isStreaming =
                                      _currentStreamingMessageId == message.id;
                                  return ChatMessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    isStreaming: isStreaming,
                                    playingAudioMessageId:
                                        _playingAudioMessageId,
                                    isPlayingAudio: _isPlayingAudio,
                                    audioDuration: _audioDuration,
                                    audioPosition: _audioPosition,
                                    speakingMessageId: _speakingMessageId,
                                    isTtsSpeaking: _isTtsSpeaking,
                                    isTtsPaused: _isTtsPaused,
                                    onPlayVoice: () => _playVoiceMessage(
                                      message.id,
                                      message.audioUrl!,
                                    ),
                                    onPauseVoice: _pauseVoiceMessage,
                                    onResumeVoice: _resumeVoiceMessage,
                                    onSpeak: (text) =>
                                        _speak(text, messageId: message.id),
                                    onStopTts: _stopTts,
                                    onPauseTts: _pauseTts,
                                    onResumeTts: _resumeTts,
                                    onCopy: () =>
                                        _copyToClipboard(message.text),
                                    onToggleBookmark: () =>
                                        _toggleBookmark(message),
                                    onShare: () => _shareMessage(message.text),
                                    onRegenerate: () =>
                                        _regenerateResponse(message),
                                    onFeedback: (feedback) =>
                                        _provideFeedback(message, feedback),
                                    onEdit: () => _handleUserEdit(message),
                                    onDownloadImage: () =>
                                        _downloadImage(message.imageUrl!),
                                    onReply: (msg) {
                                      setState(() => _replyingToMessage = msg);
                                      _messageFocusNode.requestFocus();
                                    },
                                    onLongPress: () =>
                                        _copyToClipboard(message.text),
                                    user: authProvider.userModel,
                                  );
                                },
                              ),
                            ),

                  // Scroll to Bottom Button
                  if (_showScrollDownButton)
                    Positioned(
                      bottom: 16,
                      right: 20,
                      child: FloatingActionButton.small(
                        backgroundColor: theme.primaryColor,
                        onPressed: _scrollToBottomForce,
                        elevation: 4,
                        child: const Icon(
                          Icons.arrow_downward,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Input Area
            _buildInputArea(theme, isDark),

            // AI Disclaimer
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Text(
                'TopScore AI can make mistakes, please verify important information.',
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, bool isDark) {
    return ChatInputArea(
      textController: _textController,
      messageFocusNode: _messageFocusNode,
      pendingFileName: _pendingFileName,
      pendingPreviewData: _pendingPreviewData,
      pendingFileUrl: _pendingFileUrl,
      isUploading: _isUploading,
      isTyping: _isTyping,
      isGenerating: _isTyping || _currentStreamingMessageId != null,
      suggestions: _dynamicSuggestions,
      placeholderMessages: _placeholderMessages,
      onSendMessage: _sendMessage,
      onSendMessageWithText: _sendMessage,
      onShowAttachmentMenu: () => _showAttachmentMenu(theme, isDark),
      isRecording: _isRecording,
      onToggleRecording: _toggleDictation,
      onLiveVoice: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VoiceChatScreen()),
        );
      },
      onPaste: _handlePaste, // New explicit handler for generic paste
      onStopGeneration: _stopGeneration,
      onClearPendingAttachment: _clearPendingAttachment,
      onShuffleQuestions: () {}, // Not used
      replyingToMessage: _replyingToMessage,
      onCancelReply: () => setState(() => _replyingToMessage = null),
    );
  }

  void _showWebMicPermissionGuide() {
    _showPermissionGuideDialog(
      title: 'Microphone Restricted',
      message:
          'Your browser is blocking microphone access. To use voice input:\n\n'
          '1. Click the lock icon 🔒 next to the web address.\n'
          '2. Toggle the Microphone switch to "Allow".\n'
          '3. Refresh the page to start chatting with your voice!',
    );
  }

  void _showPermissionGuideDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mic_off, color: Colors.orange),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.quicksand(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.quicksand(fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Simply re-tries init as a gesture of "fixing it"
              _initSpeech();
            },
            child: Text(
              'Try Again',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Typing Indicator Widget (moved outside _ChatScreenState)
// ===========================================================================

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Text(
        'Thinking...',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
