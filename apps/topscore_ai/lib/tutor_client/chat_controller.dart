import 'package:flutter/material.dart';
import '../shared/services/media_picker_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:collection';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

import 'package:isar_community/isar.dart' hide Query;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:waveform_flutter/waveform_flutter.dart' as wf;
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/feature_gate_service.dart';
import '../widgets/premium_feature_dialog.dart';
import '../widgets/trial_completed_overlay.dart';

import '../services/isar_service.dart';
import '../services/gemini_live_service.dart';
import '../services/clipboard_service.dart';
import '../services/analytics_service.dart';
import '../services/tts_service.dart';
import '../services/ocr_service.dart';
import '../services/scanner_service.dart';
import '../services/auth_headers.dart';
import '../utils/text_utils.dart';
import '../services/recovery_service.dart';
import '../router.dart' as app_router;
import '../config/app_config.dart';
import '../constants/colors.dart';
import 'message_model.dart';
import 'enhanced_websocket_service.dart';
import 'services/language_detect_service.dart';
import 'widgets/language_suggestion_banner.dart';
import 'connection_manager.dart' as cm;
import 'utils/audio_input.dart';
import 'utils/audio_output.dart';
import 'utils/video_input.dart';
import 'widgets/session_rating_dialog.dart';

part 'parts/chat_thread.dart';
part 'parts/chat_messaging.dart';
part 'parts/chat_attachments.dart';
part 'parts/chat_tts.dart';
part 'parts/chat_live_voice.dart';
part 'parts/chat_stt.dart';

class PendingAttachment {
  final String id;
  final String name;
  final String type;
  final Uint8List? bytes;
  final String? previewData;
  String? url;
  bool isUploaded;

  PendingAttachment({
    required this.id,
    required this.name,
    required this.type,
    this.bytes,
    this.previewData,
    this.url,
    this.isUploaded = false,
  });
}

class ChatController extends ChangeNotifier {
  final Map<String, dynamic>? chatThread;
  final XFile? initialImage;
  final String? initialMessage;
  final String? subject;
  final String? initialFileUrl;
  final String? initialFileName;
  final String? initialFileType;
  final String? initialInputText;
  final Uint8List? initialFileBytes;
  final bool isEmbedded;

  ChatController({
    this.chatThread,
    this.initialImage,
    this.initialMessage,
    this.subject,
    this.initialFileUrl,
    this.initialFileName,
    this.initialFileType,
    this.initialInputText,
    this.initialFileBytes,
    this.isEmbedded = false,
  });

  // --- STATE VARIABLES ---

  // Messaging state
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _currentStreamingMessageId;
  bool _userStoppedGeneration = false;
  bool _firstTokenHapticFired = false;
  final Map<String, String> _pendingChunks = {};
  final List<Map<String, dynamic>> _messageQueue = [];
  final Map<String, String> _titleCache = {};
  String _currentTitle = 'New Chat';
  String _historySearchQuery = '';
  ChatMessage? _replyTo;
  final Queue<String> _tokenQueue = Queue<String>();
  bool _isLoadingHistory = false;
  bool _isLoadingMessages = false;
  List<Map<String, String>> _dynamicSuggestions = [];
  String? _currentAiStatus;
  final bool _showScrollDownButton = false;
  final bool _scrollToBottomForce = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final String _selectedModelKey = 'auto';
  bool _dismissedPersistenceBanner = false;

  /// Emits the error code when the server returns a message limit error.
  /// ChatScreen listens to this and calls AuthProvider.onServerLimitReached().
  final ValueNotifier<String?> limitReached = ValueNotifier(null);

  /// Language Buddy suggestion banner: emits non-null when we detect the user
  /// typed in a supported non-English language. ChatScreen renders the banner.
  /// Once a language has been suggested in this session it won't fire again.
  final ValueNotifier<LanguageSuggestion?> languageSuggestion =
      ValueNotifier(null);
  final Set<String> _suggestedThisSession = <String>{};

  // Voice & Audio state
  bool _isVoiceMode = false;
  bool _isLoading = false;
  bool _isMicMuted = false;
  bool _isRecording = false;
  bool _isVideoEnabled = false; // Lab mode
  bool _isAppVisionEnabled = false; // Co-Pilot Mode
  final GlobalKey appRepaintBoundaryKey = GlobalKey();
  Timer? _appVisionTimer;
  bool videoIsInitialized = false;
  bool liveStopRequested = false;
  bool isStoppingVoiceMode = false;
  final StreamController<wf.Amplitude> _aiAmplitudeController =
      StreamController<wf.Amplitude>.broadcast();
  bool _isPlayingAudio = false;
  String? _playingAudioMessageId;
  Duration? _audioDuration;
  Duration? _audioPosition;
  String? _speakingMessageId;
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _liveVoiceErrorMessage;
  ChatMessage?
      _lastVisualMessage; // The most recent rich/visual message received during voice mode
  final List<Map<String, dynamic>> _xpAwards =
      []; // Active XP awards to show as overlays
  List<Map<String, dynamic>> _voiceSuggestions =
      []; // Conversation starters pushed by the backend on voice connect

  // Inactivity Warning State
  bool _isShowingInactivityWarning = false;
  int _inactivitySecondsRemaining = 0;

  // Attachment state
  bool _isUploading = false;
  final List<PendingAttachment> _pendingAttachments = [];

  // Services & Controllers
  EnhancedWebSocketService? _wsService;
  StreamSubscription? _wsMessageSubscription;
  StreamSubscription? _wsConnectionSubscription;
  StreamSubscription? _wsStateSubscription;
  final GeminiLiveService _geminiLiveService = GeminiLiveService();
  final AudioInput _audioInput = AudioInput();
  final AudioOutput _audioOutput = AudioOutput();
  final VideoInput _videoInput = VideoInput();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final TtsService _ttsService = TtsService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _historySearchController =
      TextEditingController();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final IsarService _isarService = IsarService();
  final ImagePicker _imagePicker = ImagePicker();
  final GlobalKey _attachButtonKey = GlobalKey();
  GlobalKey get attachButtonKey => _attachButtonKey;
  AiTutorHistoryProvider? _historyProvider;

  void setHistoryProvider(AiTutorHistoryProvider provider) {
    _historyProvider = provider;
    fetchThreadList(silent: true);
  }

  // Timers & Subscriptions
  Timer? _chunkUpdateTimer;
  Timer? _aiSpeakingTimer;
  StreamSubscription? _liveAudioSubscription;
  StreamSubscription? _liveVideoSubscription;
  StreamSubscription? _liveGeminiAudioSubscription;
  StreamSubscription? _liveGeminiEventSubscription;
  Timer? _typingTimer;
  Timer? _silenceTimer;
  Timer? _inactivityTimer;
  Timer? _countdownTimer;
  Timer? _transcriptionDebounce;
  Timer? _responseTimeoutTimer;
  DateTime? _voiceSessionStartTime;
  bool _isSystemNudgeTurn = false;

  // --- GETTERS ---
  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  bool get isVoiceMode => _isVoiceMode;
  bool get isLoading => _isLoading;
  bool get isMicMuted => _isMicMuted;
  bool get isRecording => _isRecording;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAppVisionEnabled => _isAppVisionEnabled;
  bool get isUploading => _isUploading;
  String get currentTitle => _currentTitle;
  TextEditingController get textController => _textController;
  ChatMessage? get replyTo => _replyTo;
  set replyTo(ChatMessage? val) {
    _replyTo = val;
    notify();
  }

  List<Map<String, dynamic>> get voiceSuggestions =>
      List.unmodifiable(_voiceSuggestions);

  List<PendingAttachment> get pendingAttachments => _pendingAttachments;
  // Backward compatibility getters for UI segments that might still expect singular (optional, but safer to update everything)
  Uint8List? get pendingFileBytes =>
      _pendingAttachments.isNotEmpty ? _pendingAttachments.first.bytes : null;
  String? get pendingPreviewData => _pendingAttachments.isNotEmpty
      ? _pendingAttachments.first.previewData
      : null;
  String? get pendingFileType =>
      _pendingAttachments.isNotEmpty ? _pendingAttachments.first.type : null;
  String? get pendingFileName =>
      _pendingAttachments.isNotEmpty ? _pendingAttachments.first.name : null;
  String? get pendingFileId =>
      _pendingAttachments.isNotEmpty ? _pendingAttachments.first.id : null;
  Stream<wf.Amplitude> get aiAmplitudeStream => _aiAmplitudeController.stream;
  EnhancedWebSocketService? get wsServiceOrNull => _wsService;
  bool get isOnline =>
      _wsService?.connectionState == cm.ConnectionState.connected;
  bool get isConnecting =>
      _wsService?.connectionState == cm.ConnectionState.connecting ||
      _wsService?.connectionState == cm.ConnectionState.reconnecting;
  bool get isOffline =>
      !hasInternet && _wsService?.connectionState == cm.ConnectionState.offline;
  bool get hasInternet => _wsService?.hasInternet ?? true;
  Stream<cm.ConnectionState> get connectionStateStream =>
      _wsService?.connectionStateStream ??
      Stream.value(cm.ConnectionState.connected);
  cm.ConnectionState get connectionState =>
      _wsService?.connectionState ?? cm.ConnectionState.connected;

  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingMessages => _isLoadingMessages;
  List<Map<String, String>> get dynamicSuggestions => _dynamicSuggestions;
  ScrollController get scrollController => _scrollController;
  String? get currentAiStatus => _currentAiStatus;
  Duration get audioDuration => _audioDuration ?? Duration.zero;
  Duration get audioPosition => _audioPosition ?? Duration.zero;
  String? get speakingMessageId => _speakingMessageId;
  bool get isTtsSpeaking => _isTtsSpeaking;
  bool get isTtsPaused => _isTtsPaused;
  bool get showScrollDownButton => _showScrollDownButton;
  bool get scrollToBottomForce => _scrollToBottomForce;
  FocusNode get messageFocusNode => _messageFocusNode;
  List<String> get placeholderMessages => [];
  String? get currentStreamingMessageId => _currentStreamingMessageId;
  String? get playingAudioMessageId => _playingAudioMessageId;
  bool get isPlayingAudio => _isPlayingAudio;
  TextEditingController get historySearchController => _historySearchController;
  String get historySearchQuery => _historySearchQuery;
  String? get liveVoiceErrorMessage => _liveVoiceErrorMessage;
  ChatMessage? get lastVisualMessage => _lastVisualMessage;
  List<Map<String, dynamic>> get xpAwards => _xpAwards;
  bool get dismissedPersistenceBanner => _dismissedPersistenceBanner;
  bool get isShowingInactivityWarning => _isShowingInactivityWarning;
  int get inactivitySecondsRemaining => _inactivitySecondsRemaining;

  void dismissPersistenceBanner() {
    _dismissedPersistenceBanner = true;
    notify();
  }

  void reset() {
    _messages.clear();
    _wsService?.setThreadId(const Uuid().v4());
    _currentStreamingMessageId = null;
    _isTyping = false;
    _currentAiStatus = null;
    notify();
  }

  /// Sets this controller's thread ID without mutating the shared WebSocket
  /// service. Used by EmbeddedChatSheet so overlays get their own thread
  /// without corrupting the main AI Tutor tab's conversation.
  void setOwnThreadId(String threadId) {
    // Store it so sendMessage picks it up via wsService?.threadId
    // We override after init() sets the wsService reference.
    _ownThreadId = threadId;
  }

  String? _ownThreadId;
  String? _embeddedThreadId; // Set when this controller owns a private thread

  void clearVisualMessage() {
    _lastVisualMessage = null;
    notify();
  }

  void notify() => notifyListeners();

  String getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'md':
        return 'text/markdown';
      default:
        return 'application/octet-stream';
    }
  }

  String generateRandomId({int length = 4}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (index) {
      final i = (random + index * 31) % chars.length;
      return chars[i];
    }).join();
  }

  String getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (ext == 'pdf') return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'doc';
    if (['txt', 'csv', 'md'].contains(ext)) return 'text';
    return 'file';
  }

  String stripMarkdown(String text) {
    if (text.isEmpty) return '';

    // 1. Remove images and links (keep text)
    String cleaned = text
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1');

    // 2. Remove Code Blocks (typically too technical for TTS)
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), ' [code block] ');

    // 3. Handle LaTeX/Math: replace symbols with silence or readable equivalents
    // Strip dollar signs but keep content
    cleaned = cleaned.replaceAll(RegExp(r'\$\$?([\s\S]*?)\$\$?'), r'$1');
    // Remove backslash escapes common in LaTeX
    cleaned = cleaned.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    // Remove brackets and braces used in math
    cleaned = cleaned.replaceAll(RegExp(r'[{}()\[\]]'), ' ');

    // 4. Remove generic markdown symbols
    cleaned = cleaned.replaceAll(RegExp(r'[*_`#~|>]'), '');

    // 5. Final cleanup
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // --- INITIALIZATION ---
  void init(EnhancedWebSocketService wsService) {
    if (_wsService == wsService && _ownThreadId == null) return;

    // Cleanup previous subscriptions if any
    _wsMessageSubscription?.cancel();
    _wsConnectionSubscription?.cancel();
    _wsStateSubscription?.cancel();

    _wsService = wsService;

    // If this controller has its own thread ID (embedded overlay), apply it
    // now. We call setThreadId on the service here, but the caller (bootstrap)
    // must restore the original thread ID on the shared service after init.
    // Actually — we store it on the controller and override threadId getter.
    if (_ownThreadId != null) {
      _embeddedThreadId = _ownThreadId!;
      _ownThreadId = null;
      _wsService!.setThreadId(_embeddedThreadId!);
    }

    initTts();

    _wsMessageSubscription =
        _wsService!.messageStream.listen(handleIncomingMessage);

    // Reset typing state if connection is lost
    _wsConnectionSubscription =
        _wsService!.isConnectedStream.listen((connected) {
      if (!connected && _isTyping) {
        finalizeTurn(null);
      }
      notify();
    });

    // Drive the offline banner / send-button disable off the richer state
    _wsStateSubscription =
        _wsService!.connectionStateStream.listen((_) => notify());

    if (chatThread != null) {
      loadThread(chatThread!['thread_id']);
    } else {
      startNewChat(closeDrawer: false);
    }

    _initInitialAttachments();
    fetchThreadList(silent: true);
  }

  Future<void> handleInitialResources({
    XFile? image,
    String? text,
    String? fileUrl,
    String? fileName,
    String? fileType,
    Uint8List? fileBytes,
  }) async {
    if (text != null && text.isNotEmpty && _textController.text.isEmpty) {
      _textController.text = text;
    }
    if (image != null) {
      await _handleInitialImageExternal(image);
    }
    if (fileUrl != null || fileBytes != null) {
      final exists = _pendingAttachments
          .any((a) => a.url == fileUrl || a.name == fileName);
      if (!exists) {
        _pendingAttachments.add(PendingAttachment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: fileName ?? 'Document',
          type: fileType ?? 'application/octet-stream',
          bytes: fileBytes,
          url: fileUrl,
          isUploaded: fileUrl != null,
        ));
      }
    }
    notify();
  }

  Future<void> _handleInitialImageExternal(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final fileName = 'snap_${DateTime.now().millisecondsSinceEpoch}.png';
    const mimeType = 'image/png';
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final attachment = PendingAttachment(
      id: id,
      name: fileName,
      type: mimeType,
      bytes: bytes,
      previewData: 'data:image/png;base64,$base64Image',
      isUploaded: false,
    );

    _pendingAttachments.add(attachment);
    _isUploading = true;
    notify();

    final url = await uploadToFirebase(
      bytes: bytes,
      filePath: kIsWeb ? null : xFile.path,
      fileName: fileName,
      mimeType: mimeType,
    );

    attachment.url = url;
    attachment.isUploaded = true;
    _isUploading = false;
    notify();
  }

  // --- SHARED UI METHODS ---
  Future<void> preWarmAudio() async {
    developer.log('🎙️ Pre-warming audio for Web (gesture context)',
        name: 'ChatController');
    try {
      await _audioInput.requestPermission();
      await _audioOutput.init();
    } catch (e) {
      developer.log('🎙️ Pre-warm failed: $e', name: 'ChatController');
    }
  }

  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
    notify();
  }

  void toggleSidebar() {
    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
      scaffoldKey.currentState?.closeDrawer();
    } else {
      scaffoldKey.currentState?.openDrawer();
    }
  }

  void onSearchChanged(String query) {
    _historySearchQuery = query;
    notify();
  }

  void _initInitialAttachments() {
    if (initialFileUrl != null || initialFileBytes != null) {
      _pendingAttachments.add(PendingAttachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: initialFileName ?? 'File',
        type: initialFileType ?? 'application/octet-stream',
        bytes: initialFileBytes,
        url: initialFileUrl,
        isUploaded: initialFileUrl != null,
      ));
    }
  }

  void cancelReply() {
    _replyTo = null;
    notify();
  }

  Future<void> attachFileFromPath(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final fileName = file.path.split('/').last;
      final bytes = await file.readAsBytes();
      final extension = fileName.split('.').last.toLowerCase();

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final attachment = PendingAttachment(
        id: id,
        name: fileName,
        type: getFileType(extension),
        bytes: bytes,
        isUploaded: false,
      );

      _pendingAttachments.add(attachment);
      _isUploading = true;
      notify();

      final mimeType = getMimeType(extension);
      uploadToFirebase(
        bytes: bytes,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
      ).then((url) {
        attachment.url = url;
        attachment.isUploaded = true;
        _checkUploadsFinished();
        notify();
      });

      // Navigate to /ai-tutor if needed
      app_router.router.go('/ai-tutor');
    } catch (e) {
      developer.log('Error attaching file from path: $e',
          name: 'ChatController');
    }
  }

  void addXpAward(int amount, String reason) {
    final award = {
      'id': const Uuid().v4(),
      'amount': amount,
      'reason': reason,
      'timestamp': DateTime.now(),
    };
    _xpAwards.add(award);
    notify();

    // Auto-dismiss after 4 seconds
    Timer(const Duration(seconds: 4), () {
      _xpAwards.removeWhere((a) => a['id'] == award['id']);
      notify();
    });
  }

  @override
  void dispose() {
    // _wsService is managed by TutorConnectionProvider, do not dispose here
    _audioPlayer.dispose();
    _textController.dispose();
    _historySearchController.dispose();
    _aiAmplitudeController.close();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _chunkUpdateTimer?.cancel();
    _aiSpeakingTimer?.cancel();
    _wsConnectionSubscription?.cancel();
    _wsMessageSubscription?.cancel();
    _wsStateSubscription?.cancel();
    _liveAudioSubscription?.cancel();
    _liveVideoSubscription?.cancel();
    _liveGeminiAudioSubscription?.cancel();
    _liveGeminiEventSubscription?.cancel();
    _typingTimer?.cancel();
    _transcriptionDebounce?.cancel();
    _countdownTimer?.cancel();
    _responseTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startResponseTimeout(String messageId) {
    _responseTimeoutTimer?.cancel();

    // Progressive status updates to improve user experience
    Timer(const Duration(seconds: 30), () {
      if (_isTyping && _currentStreamingMessageId == messageId) {
        _currentAiStatus = "Still thinking... complex questions take time 🤔";
        notify();
      }
    });

    Timer(const Duration(seconds: 60), () {
      if (_isTyping && _currentStreamingMessageId == messageId) {
        _currentAiStatus = "Almost there... generating your response ✨";
        notify();
      }
    });

    Timer(const Duration(seconds: 90), () {
      if (_isTyping && _currentStreamingMessageId == messageId) {
        _currentAiStatus =
            "Taking longer than usual, but still working on it ⏳";
        notify();
      }
    });

    // Increased timeout from 60 to 120 seconds to reduce false timeouts
    _responseTimeoutTimer = Timer(const Duration(seconds: 120), () {
      _handleResponseTimeout(messageId);
    });
  }

  void _cancelResponseTimeout() {
    _responseTimeoutTimer?.cancel();
    _responseTimeoutTimer = null;
    _currentAiStatus = null; // Clear any status messages
  }
}

class CustomPasteEvent {
  final Uint8List? bytes;
  final String? text;
  CustomPasteEvent({this.bytes, this.text});
}
