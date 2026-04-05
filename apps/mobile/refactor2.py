
import re

with open('lib/tutor_client/chat_screen.dart', 'r', encoding='utf-8') as f:
    screen_code = f.read()

# 1. CREATE CONTROLLER
controller_code = screen_code.replace(
    'class _ChatScreenState extends State<ChatScreen> {',
    '''class ChatController extends ChangeNotifier {
  final BuildContext context;
  ChatController({
    required this.context,
    Map<String, dynamic>? chatThread,
    File? initialImageFile,
    XFile? initialImage,
    String? initialMessage,
    String? subject,
    String? initialFileUrl,
    String? initialFileName,
    String? initialFileType,
    String? initialInputText,
    Uint8List? initialFileBytes,
  }) {
    // Basic setup from widget props
    if (initialInputText != null) _textController.text = initialInputText;
    
    // We simulate initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connProvider = context.read<TutorConnectionProvider>();
      if (!connProvider.isConnected) connProvider.reconnect();
      _setupWsSubscription(
        chatThread: chatThread,
        initialImageFile: initialImageFile,
        initialImage: initialImage,
        initialMessage: initialMessage,
        initialFileUrl: initialFileUrl,
        initialFileName: initialFileName,
        initialFileType: initialFileType,
        initialFileBytes: initialFileBytes
      );
    });
    
    _scrollController.addListener(_scrollListener);
    
    // Paste handler logic
    registerPasteHandler(
      onImagePasted: (dataUri) async {
        final base64Str = dataUri.split(',')[1];
        final bytes = base64Decode(base64Str);
        _pendingPreviewData = dataUri;
        _pendingFileName = 'Pasted Image.png';
        _isUploading = true;
        notifyListeners();
        
        // Assuming _uploadToFirebase is in a part
        final url = await _uploadToFirebase(bytes, 'pasted_web_image.png', 'image/png');
        if (url != null) {
          _pendingFileUrl = url;
          notifyListeners();
        }
      },
    );
  }

  bool get mounted => true;

  void setState(void Function() fn) {
    fn();
    notifyListeners();
  }

  EnhancedWebSocketService? get _wsServiceOrNull =>
      context.read<TutorConnectionProvider>().wsService;

'''
)

# Remove the UI build methods from controller
controller_code = re.sub(r'@override\s+Widget build\(BuildContext context\).*?(?=// ======)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'PreferredSizeWidget _buildAppBar.*?(?=Widget _buildMobileDrawer)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'Widget _buildMobileDrawer.*?(?=void _showAttachmentMenu)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'Widget _buildMainChatArea.*?(?=Widget _buildInputArea)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'Widget _buildInputArea.*?(?=Widget _buildVoiceOverlay)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'Widget _buildVoiceOverlay.*?(?=Widget _buildCircleButton)', '', controller_code, flags=re.DOTALL)
controller_code = re.sub(r'Widget _buildCircleButton.*?(?=void _scrollDown)', '', controller_code, flags=re.DOTALL)

# Let's write the controller
with open('lib/tutor_client/chat_controller.dart', 'w', encoding='utf-8') as f:
    f.write(controller_code)

print('Done')
