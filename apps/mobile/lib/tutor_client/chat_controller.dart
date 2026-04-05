import 'package:flutter/material.dart';
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
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:isar/isar.dart' hide Query;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:waveform_flutter/waveform_flutter.dart' as wf;
import 'package:http/http.dart' as http;

import '../providers/auth_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/gamification_provider.dart';
import '../services/xp_service.dart';
import '../services/isar_service.dart';
import '../services/gemini_live_service.dart';
import '../services/clipboard_service.dart';
import '../services/analytics_service.dart';
import '../services/ocr_service.dart';
import '../services/auth_headers.dart';
import '../utils/text_utils.dart';
import '../config/api_config.dart';
import 'message_model.dart';
import 'enhanced_websocket_service.dart';
import 'utils/audio_input.dart';
import 'utils/audio_output.dart';
import 'utils/video_input.dart';
import 'widgets/session_rating_dialog.dart';
import '../screens/auth/guest_welcome_screen.dart';

part 'parts/chat_thread.dart';
part 'parts/chat_messaging.dart';
part 'parts/chat_attachments.dart';
part 'parts/chat_tts.dart';
part 'parts/chat_live_voice.dart';
part 'parts/chat_stt.dart';

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
  }) {
    init();
  }

  // --- STATE VARIABLES ---

  // Messaging state
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _currentStreamingMessageId;
  bool _userStoppedGeneration = false;
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

  // Gamification state
  int _totalXp = 0;
  int _currentStreak = 0;
  List<String> _gamificationAlerts = [];
  bool _showGamificationConfetti = false;
  bool _hasShownGuestPrompt = false;
  bool _dismissedPersistenceBanner = false;
  late final ConfettiController _confettiController;

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
  final StreamController<wf.Amplitude> _aiAmplitudeController = StreamController<wf.Amplitude>.broadcast();
  bool _isPlayingAudio = false;
  String? _playingAudioMessageId;
  Duration? _audioDuration;
  Duration? _audioPosition;
  String? _speakingMessageId;
  bool _isTtsSpeaking = false;
  bool _isTtsPaused = false;
  String? _liveVoiceErrorMessage;

  // Attachment state
  bool _isUploading = false;
  Uint8List? _pendingFileBytes;
  String? _pendingPreviewData;
  String? _pendingFileName;
  String? _pendingFileType;
  String? _pendingFileUrl;

  // Services & Controllers
  late final EnhancedWebSocketService _wsService;
  final GeminiLiveService _geminiLiveService = GeminiLiveService();
  final AudioInput _audioInput = AudioInput();
  final AudioOutput _audioOutput = AudioOutput();
  final VideoInput _videoInput = VideoInput();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _historySearchController = TextEditingController();
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final IsarService _isarService = IsarService();
  final ImagePicker _imagePicker = ImagePicker();

  // Timers & Subscriptions
  Timer? _chunkUpdateTimer;
  Timer? _aiSpeakingTimer;
  StreamSubscription? _liveAudioSubscription;
  StreamSubscription? _liveVideoSubscription;
  StreamSubscription? _liveGeminiAudioSubscription;
  StreamSubscription? _liveGeminiEventSubscription;
  Timer? _typingTimer;
  Timer? _silenceTimer;
  Timer? _transcriptionDebounce;
  DateTime? _voiceSessionStartTime;

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
  set replyTo(ChatMessage? val) { _replyTo = val; notify(); }
  Uint8List? get pendingFileBytes => _pendingFileBytes;
  String? get pendingPreviewData => _pendingPreviewData;
  String? get pendingFileType => _pendingFileType;
  String? get pendingFileName => _pendingFileName;
  double get aiAmplitude => 0.0; 
  Stream<wf.Amplitude> get aiAmplitudeStream => _aiAmplitudeController.stream;
  EnhancedWebSocketService? get wsServiceOrNull => _wsService;

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

  int get totalXp => _totalXp;
  int get currentStreak => _currentStreak;
  List<String> get gamificationAlerts => _gamificationAlerts;
  bool get showGamificationConfetti => _showGamificationConfetti;
  ConfettiController get confettiController => _confettiController;

  bool get dismissedPersistenceBanner => _dismissedPersistenceBanner;
  void dismissPersistenceBanner() {
    _dismissedPersistenceBanner = true;
    notify();
  }

  void clearGamificationAlerts() {
    _gamificationAlerts.clear();
    _showGamificationConfetti = false;
    notify();
  }

  void notify() => notifyListeners();

  String stripMarkdown(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
        .replaceAll(RegExp(r'[*_`#]'), '')
        .trim();
  }

  // --- INITIALIZATION ---
  void init() async {
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    _wsService = EnhancedWebSocketService(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest',
    );
    _wsService.messageStream.listen(handleIncomingMessage);
    
    // Reset typing state if connection is lost
    _wsService.isConnectedStream.listen((connected) {
      if (!connected && _isTyping) {
        finalizeTurn(null);
        addSystemMessage('Connection lost. Retrying...');
      }
    });

    if (chatThread != null) {
      loadThread(chatThread!['thread_id']);
    } else {
      startNewChat(closeDrawer: false);
    }

    if (initialImage != null) {
      _handleInitialImage();
    }
    initTts();
    fetchThreadList(silent: true);
  }


  // --- SHARED UI METHODS ---
  Future<void> preWarmAudio() async {
    developer.log('🎙️ Pre-warming audio for Web (gesture context)', name: 'ChatController');
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
        duration: const Duration(milliseconds: 300),
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

  void _handleInitialImage() async {
    final xFile = initialImage;
    if (xFile == null) return;
    
    final bytes = await xFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    _pendingFileBytes = bytes;
    _pendingPreviewData = 'data:image/png;base64,$base64Image';
    _pendingFileName = initialFileName ?? 'initial_image.png';
    _pendingFileType = initialFileType ?? 'image';
    _isUploading = true;
    notify();

    final url = await uploadToFirebase(bytes, _pendingFileName!, 'image/png');
    _pendingFileUrl = url;
    _isUploading = false;
    notify();
  }

  void cancelReply() {
    _replyTo = null;
    notify();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _wsService.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _historySearchController.dispose();
    _aiAmplitudeController.close();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _chunkUpdateTimer?.cancel();
    _aiSpeakingTimer?.cancel();
    _liveAudioSubscription?.cancel();
    _liveVideoSubscription?.cancel();
    _liveGeminiAudioSubscription?.cancel();
    _liveGeminiEventSubscription?.cancel();
    _typingTimer?.cancel();
    _transcriptionDebounce?.cancel();
    super.dispose();
  }
}

class CustomPasteEvent {
  final Uint8List? bytes;
  final String? text;
  CustomPasteEvent({this.bytes, this.text});
}
