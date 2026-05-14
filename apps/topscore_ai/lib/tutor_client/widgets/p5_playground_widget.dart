import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback, rootBundle;
import 'package:flutter/gestures.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/ai_service.dart';
import '../../constants/colors.dart';

class P5PlaygroundWidget extends StatefulWidget {
  final String title;
  final String description;
  final String code;
  final Map<String, dynamic>? config;

  const P5PlaygroundWidget({
    super.key,
    required this.title,
    required this.description,
    required this.code,
    this.config,
  });

  @override
  State<P5PlaygroundWidget> createState() => _P5PlaygroundWidgetState();
}

class _P5PlaygroundWidgetState extends State<P5PlaygroundWidget> {
  late TextEditingController _codeController;
  bool _isActivated = false;
  bool _isWebviewLoading = false;
  String? _cachedLibrary;
  String? _loadedHtml;
  InAppWebViewController? _webViewController;
  
  // Socratic Coding Copilot State
  int _strikeCount = 0;
  bool _isSocraticLoading = false;
  String? _currentSocraticHint;
  String? _revealCode;
  bool _showHintPanel = false;
  final AIService _aiService = AIService();
  StreamSubscription? _webMessageSubscription;
  
  // Syllabus & Level States
  int _currentSyllabusLevel = 1;
  bool _levelMastered = false;
  
  // Custom tweakable variables parsed from the code
  final List<Map<String, dynamic>> _tweakableVariables = [];
  final FocusNode _editorFocusNode = FocusNode();
  
  int _activeTab = 0; // 0 for Visual Blocks, 1 for Text Code
  List<Map<String, dynamic>> _visualBlocks = [];

  @override
  void initState() {
    super.initState();
    
    // Default to Level 1 code if widget code is empty or generic
    final String initialCode = widget.code.trim().isEmpty 
        ? SyllabusData.levels[0].code 
        : _cleanInitialCode(widget.code);
        
    _codeController = TextEditingController(text: initialCode);
    _codeController.addListener(_onCodeChanged);
    _initVisualBlocks();
    _parseTweakableVariables();
    _initWebListener();
  }

  @override
  void dispose() {
    _webMessageSubscription?.cancel();
    _unloadWebView();
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  String _cleanInitialCode(String rawCode) {
    if (rawCode.contains('<script>')) {
      // Try to extract content inside the script tag
      final reg = RegExp(r'<script>([\s\S]*?)<\/script>');
      final match = reg.firstMatch(rawCode);
      if (match != null) {
        return match.group(1)?.trim() ?? rawCode;
      }
    }
    return rawCode.trim();
  }

  void _parseTweakableVariables() {
    // Looks for patterns like: let speed = 5; // [tweak: speed, min: 1, max: 20]
    _tweakableVariables.clear();
    final codeText = _codeController.text;
    final lines = codeText.split('\n');
    final regex = RegExp(r'let\s+(\w+)\s*=\s*([^;]+);?\s*\/\/\s*\[tweak:\s*(\w+),\s*min:\s*([\d.]+),\s*max:\s*([\d.]+)\]');
    
    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        final valStr = match.group(2)!.trim();
        final double? currentVal = double.tryParse(valStr);
        final double? minVal = double.tryParse(match.group(4)!);
        final double? maxVal = double.tryParse(match.group(5)!);
        
        if (currentVal != null && minVal != null && maxVal != null) {
          _tweakableVariables.add({
            'name': name,
            'current': currentVal,
            'min': minVal,
            'max': maxVal,
          });
        }
      }
    }
  }

  void _unloadWebView() {
    if (_webViewController != null) {
      _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      _webViewController = null;
    }
  }

  Future<void> _activateAndLoad() async {
    setState(() {
      _isActivated = true;
      _isWebviewLoading = _webViewController == null;
    });

    try {
      // 1. Load the local minified p5.js library offline
      _cachedLibrary ??= await rootBundle.loadString('assets/js/p5.min.js');

      // 2. Generate optimized, auto-scaling HTML
      if (_activeTab == 0) {
        _codeController.text = _compileBlocksToCode();
      }
      final userCode = _codeController.text;
      final successCriteria = SyllabusData.levels[_currentSyllabusLevel - 1].successCriteria;
      _loadedHtml = _buildHtmlSandbox(userCode, _cachedLibrary!, successCriteria);

      // 3. If webview is already running, load the data directly for an instantaneous hot-reload!
      if (_webViewController != null) {
        await _webViewController?.loadData(
          data: _loadedHtml!,
          mimeType: 'text/html',
          encoding: 'utf-8',
        );
      }
    } catch (e) {
      debugPrint("Error initializing p5 playground: $e");
    } finally {
      setState(() {
        _isWebviewLoading = false;
      });
    }
  }

  String _buildHtmlSandbox(String code, String libraryContent, String successCriteria) {
    final String validationScript = """
        // Validation Hook Proxy
        if (typeof draw === 'function') {
            let originalDraw = draw;
            draw = function() {
                originalDraw();
                try {
                    if ($successCriteria) {
                        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                            window.flutter_inappwebview.callHandler('onJsSuccess');
                        }
                        if (window.parent && window.parent.postMessage) {
                            window.parent.postMessage({ type: 'onJsSuccess' }, '*');
                        }
                    }
                } catch(e) {}
            };
        }
    """;

    return """
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        html, body {
            margin: 0;
            padding: 0;
            width: 100vw;
            height: 100vh;
            background: transparent;
            overflow: hidden;
            font-family: system-ui, -apple-system, sans-serif;
        }
        body { display: block; }
        canvas {
            display: block;
            width: 100% !important;
            height: 100% !important;
        }
    </style>
    <script>
        // Error bridge interceptor
        window.onerror = function(message, source, lineno, colno, error) {
            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                window.flutter_inappwebview.callHandler('onJsError', message, lineno);
            }
            if (window.parent && window.parent.postMessage) {
                window.parent.postMessage({
                    type: 'onJsError',
                    message: message,
                    line: lineno
                }, '*');
            }
            return true; // prevent frame default console dump
        };
    </script>
    <script>
        $libraryContent
    </script>
</head>
<body>
    <script>
        // Ensure p5 canvas auto-fits the container
        function setup() {
            let canvas = createCanvas(window.innerWidth, window.innerHeight);
            canvas.parent(document.body);
            if (typeof customSetup === 'function') customSetup();
        }

        // Window resize support
        function windowResized() {
            resizeCanvas(window.innerWidth, window.innerHeight);
        }

        $code
        $validationScript
    </script>
</body>
</html>
""";
  }

  void _deactivate() {
    _unloadWebView();
    setState(() {
      _isActivated = false;
    });
  }

  void _runModifiedCode() {
    HapticFeedback.mediumImpact();
    _parseTweakableVariables();
    _activateAndLoad();
  }

  void _showFullscreenPreview() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => _P5FullscreenPreview(
          title: widget.title,
          html: _loadedHtml ?? '',
          tweakableVariables: _tweakableVariables,
          onUpdateVariable: _updateVariable,
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }

  void _onCodeChanged() {
    _parseTweakableVariables();
    if (_isActivated) _runModifiedCode();
  }

  void _resetCode() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_activeTab == 0) {
        _initVisualBlocks();
        _codeController.text = _compileBlocksToCode();
      } else {
        _codeController.text = _cleanInitialCode(widget.code);
      }
      _parseTweakableVariables();
    });
    if (_isActivated) {
      _runModifiedCode();
    }
  }

  void _updateVariable(String name, double value) {
    // Dynamically replace the variable assignment in the code
    final oldCode = _codeController.text;
    final regex = RegExp('let\\s+$name\\s*=\\s*([^;]+);');
    final match = regex.firstMatch(oldCode);
    if (match != null) {
      final updatedCode = oldCode.replaceFirst(match.group(0)!, 'let $name = ${value.toStringAsFixed(2)};');
      setState(() {
        _codeController.text = updatedCode;
      });
      // Direct JS Injection to avoid full reload
      _webViewController?.evaluateJavascript(source: '$name = ${value.toStringAsFixed(2)};');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget currentBody;
    if (!_isActivated) {
      currentBody = _buildLazyCard(isDark, theme);
    } else {
      currentBody = _buildActivatedPlayground(isDark, theme);
    }

    return VisibilityDetector(
      key: Key('p5_${widget.title}_${widget.code.hashCode}'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction == 0.0 && _isActivated) {
          _deactivate();
        }
      },
      child: currentBody,
    );
  }

  Widget _buildLazyCard(bool isDark, ThemeData theme) {
    final cardColor = isDark ? AppColors.surfaceElevatedDark : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.topscoreBlue, AppColors.topscoreTeal],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.topscoreBlue.withValues(alpha: 0.12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.code_rounded,
                        color: AppColors.topscoreBlue,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.description,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              'Offline Play • Code Sandbox Ready',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: CupertinoButton(
                color: AppColors.topscoreBlue,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: _activateAndLoad,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.play_circle_fill, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Launch Code Lab',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivatedPlayground(bool isDark, ThemeData theme) {
    final barBg = isDark ? AppColors.surfaceDark : AppColors.background;
    final barBorder = isDark ? AppColors.borderDark : AppColors.border;
    const double totalHeight = 650.0;

    return DefaultTabController(
      length: 2,
      child: Container(
        height: totalHeight,
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: barBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Top Controls Bar
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: barBg,
                  border: Border(bottom: BorderSide(color: barBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code_rounded, size: 18, color: AppColors.topscoreBlue),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _deactivate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.power, size: 14, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              'Close',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Custom TabBar (Left and Right Tabs)
              Container(
                decoration: BoxDecoration(
                  color: barBg,
                  border: Border(bottom: BorderSide(color: barBorder)),
                ),
                child: TabBar(
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.play_circle, size: 16),
                          const SizedBox(width: 8),
                          Text('Playground', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.doc_text, size: 16),
                          const SizedBox(width: 8),
                          Text('Code Editor', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  labelColor: AppColors.topscoreBlue,
                  unselectedLabelColor: isDark ? Colors.white38 : Colors.grey,
                  indicatorColor: AppColors.topscoreBlue,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(), // Allow internal interaction
                  children: [
                    _buildTopPanel(isDark, theme),
                    _buildBottomPanel(isDark, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPanel(bool isDark, ThemeData theme) {
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.background,
      child: Column(
        children: [
          // The Canvas Container
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: -5,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (_isWebviewLoading)
                    const Center(child: CupertinoActivityIndicator(radius: 16))
                  else
                    InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: _loadedHtml ?? '',
                        mimeType: 'text/html',
                        encoding: 'utf-8',
                      ),
                      initialSettings: InAppWebViewSettings(
                        transparentBackground: true,
                        supportZoom: false,
                        useWideViewPort: true,
                        loadWithOverviewMode: true,
                        disableVerticalScroll: true,
                        disableHorizontalScroll: true,
                      ),
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer()),
                        Factory<HorizontalDragGestureRecognizer>(() => HorizontalDragGestureRecognizer()),
                      },
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                        if (!kIsWeb) {
                          controller.addJavaScriptHandler(
                            handlerName: 'onJsError',
                            callback: (args) {
                              final String message = args[0].toString();
                              final int line = int.tryParse(args[1].toString()) ?? 0;
                              _handleJavaScriptError(message, line);
                            },
                          );
                          controller.addJavaScriptHandler(
                            handlerName: 'onJsSuccess',
                            callback: (args) {
                              if (mounted) {
                                setState(() {
                                  _strikeCount = 0;
                                  _showHintPanel = false;
                                  _currentSocraticHint = null;
                                  _revealCode = null;
                                  _levelMastered = true; // Unlock progress!
                                });
                              }
                            },
                          );
                        }
                      },
                    ),
                  // Overlay controls
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _buildCanvasAction(
                          icon: Icons.refresh_rounded,
                          onTap: _runModifiedCode,
                          tooltip: 'Restart Sketch',
                        ),
                        const SizedBox(width: 8),
                        _buildCanvasAction(
                          icon: Icons.fullscreen_rounded,
                          onTap: _showFullscreenPreview,
                          tooltip: 'Fullscreen',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Celebration Card or Socratic Mascot Hint Panel
          _levelMastered 
              ? _buildCelebrationCard(isDark, theme) 
              : _buildMascotHintPanel(isDark, theme),

          // Variable Tweak Control Panel (If variables exist in p5 file)
          if (_tweakableVariables.isNotEmpty)
            _buildModernTweakPanel(isDark),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCanvasAction({required IconData icon, required VoidCallback onTap, required String tooltip}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildModernTweakPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.topscoreBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 16, color: AppColors.topscoreBlue),
              ),
              const SizedBox(width: 10),
              Text(
                'Live Parameters',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${_tweakableVariables.length} active',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.topscoreBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._tweakableVariables.map((v) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        v['name'],
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        v['current'].toStringAsFixed(2),
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.topscoreBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: v['current'],
                      min: v['min'],
                      max: v['max'],
                      activeColor: AppColors.topscoreBlue,
                      inactiveColor: AppColors.topscoreBlue.withValues(alpha: 0.1),
                      onChanged: (val) {
                        setState(() {
                          v['current'] = val;
                        });
                        _updateVariable(v['name'], val);
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(bool isDark, ThemeData theme) {
    final editorBg = isDark ? AppColors.surfaceDark : AppColors.surfaceVariant;
    final editorBorder = isDark ? AppColors.borderDark : AppColors.border;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          _buildTabSelector(isDark),
          const SizedBox(height: 12),
          Expanded(
            child: _activeTab == 0
                ? _buildVisualBlocksList(isDark, theme)
                : Container(
                    decoration: BoxDecoration(
                      color: editorBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: editorBorder, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          // Line numbers
                          Container(
                            width: 32,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                              border: Border(right: BorderSide(color: editorBorder)),
                            ),
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _codeController,
                              builder: (context, value, _) {
                                final lineCount = value.text.split('\n').length;
                                return SingleChildScrollView(
                                  child: Column(
                                    children: List.generate(
                                      lineCount,
                                      (i) => Text(
                                        '${i + 1}',
                                        style: GoogleFonts.firaCode(
                                          fontSize: 10,
                                          color: isDark ? Colors.white24 : Colors.black26,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              focusNode: _editorFocusNode,
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: GoogleFonts.firaCode(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF1E1B4B),
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(16),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_activeTab == 1) ...[
            const SizedBox(height: 8),
            // THE CODER'S ACCESSORY BAR
            _buildCoderAccessoryBar(isDark),
          ],
          const SizedBox(height: 12),
          _buildBottomActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildCoderAccessoryBar(bool isDark) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          '{', '}', '(', ')', '[', ']', ';', '=', '+', '-', '*', '/', 'ellipse', 'rect', 'fill', 'stroke', 'setup', 'draw'
        ].map((symbol) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _insertText(symbol),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    symbol,
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.topscoreTeal : AppColors.topscoreBlue,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: _resetCode,
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.warning),
            label: Text(
              'Reset',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.warning,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: CupertinoButton(
            color: AppColors.topscoreBlue,
            borderRadius: BorderRadius.circular(12),
            padding: EdgeInsets.zero,
            onPressed: _runModifiedCode,
            child: Text(
              'Run Code',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _insertText(String insert) {
    final text = _codeController.text;
    final selection = _codeController.selection;
    final int insertPosition = selection.isValid ? selection.start : text.length;

    final newText = text.replaceRange(
      selection.isValid ? selection.start : text.length,
      selection.isValid ? selection.end : text.length,
      insert,
    );

    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: insertPosition + insert.length,
      ),
    );

    _editorFocusNode.requestFocus();
  }

  Future<void> _handleJavaScriptError(String message, int line) async {
    if (!mounted) return;

    setState(() {
      _strikeCount++;
      _isSocraticLoading = true;
      _showHintPanel = true;
    });

    HapticFeedback.heavyImpact();

    try {
      final hintData = await _aiService.getSocraticHint(
        code: _codeController.text,
        errorMessage: message,
        lineNumber: line,
        strikeLevel: _strikeCount,
        title: widget.title,
      );

      if (mounted) {
        setState(() {
          _currentSocraticHint = hintData['hint'] as String?;
          _revealCode = hintData['reveal_code'] as String?;
          _isSocraticLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Socratic hint error: $e");
      if (mounted) {
        setState(() {
          _currentSocraticHint = "Hmm, looks like a little syntax snag around line $line! Take a close look and see if any brackets, characters, or variables are out of place. You've got this!";
          _isSocraticLoading = false;
        });
      }
    }
  }

  void _applyEscapeHatchCode() {
    if (_revealCode == null) return;
    
    HapticFeedback.vibrate();
    
    setState(() {
      _codeController.text = _revealCode!;
      _strikeCount = 0;
      _showHintPanel = false;
      _currentSocraticHint = null;
      _revealCode = null;
    });

    _runModifiedCode();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.wand_stars, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "I've applied the fix for you! Let's keep exploring.",
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.topscoreBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _initWebListener() {
    // Listen for JS messages from the WebView
  }

  void _initVisualBlocks() {
    // Basic block extraction
    _visualBlocks = [
      {
        'type': 'canvas',
        'title': 'Setup Canvas',
        'fields': {'width': 400, 'height': 400},
      },
      {
        'type': 'background',
        'title': 'Background Color',
        'fields': {'color': '#f0f0f0'},
      },
      {
        'type': 'shape',
        'title': 'Draw Circle',
        'fields': {'x': 200, 'y': 200, 'radius': 50, 'color': '#3b82f6'},
      }
    ];
  }

  String _compileBlocksToCode() {
    StringBuffer setupCode = StringBuffer();
    StringBuffer drawCode = StringBuffer();

    setupCode.writeln("function setup() {");
    setupCode.writeln("  createCanvas(windowWidth, windowHeight);");

    drawCode.writeln("function draw() {");

    for (var block in _visualBlocks) {
      final type = block['type'];
      final fields = block['fields'] as Map<String, dynamic>;

      if (type == 'canvas') {
        // Already handled in setup
      } else if (type == 'background') {
        drawCode.writeln("  background('${fields['color']}');");
      } else if (type == 'shape') {
        drawCode.writeln("  fill('${fields['color']}');");
        drawCode.writeln(
            "  ellipse(${fields['x']}, ${fields['y']}, ${fields['radius']} * 2, ${fields['radius']} * 2);");
      }
    }

    setupCode.writeln("}");
    drawCode.writeln("}");

    return "${setupCode.toString()}\n${drawCode.toString()}";
  }

  Widget _buildTabSelector(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTab(0, 'Visual Blocks', isDark),
          ),
          Expanded(
            child: _buildSubTab(1, 'Text Code', isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label, bool isDark) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
          if (_activeTab == 0) {
            _initVisualBlocks();
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? AppColors.topscoreBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : (isDark ? Colors.white38 : Colors.black38),
          ),
        ),
      ),
    );
  }

  void _editBlock(int index) {
    final block = _visualBlocks[index];
    final fields = Map<String, dynamic>.from(block['fields']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${block['title']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.keys.map((key) {
              final value = fields[key];
              if (value is num) {
                return TextField(
                  decoration: InputDecoration(labelText: key),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => fields[key] = double.tryParse(v) ?? value,
                  controller: TextEditingController(text: value.toString()),
                );
              } else if (value is String && value.startsWith('#')) {
                return TextField(
                  decoration: InputDecoration(labelText: key),
                  onChanged: (v) => fields[key] = v,
                  controller: TextEditingController(text: value),
                );
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _visualBlocks[index]['fields'] = fields;
                _codeController.text = _compileBlocksToCode();
              });
              Navigator.pop(context);
              if (_isActivated) _runModifiedCode();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addNewBlock() {
    setState(() {
      _visualBlocks.add({
        'type': 'shape',
        'title': 'New Circle',
        'fields': {'x': 100, 'y': 100, 'radius': 30, 'color': '#ff0000'},
      });
      _codeController.text = _compileBlocksToCode();
    });
    if (_isActivated) _runModifiedCode();
  }

  Widget _buildVisualBlocksList(bool isDark, ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _visualBlocks.length,
      itemBuilder: (context, index) {
        final block = _visualBlocks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
          ),
          child: InkWell(
            onTap: () => _editBlock(index),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block['title'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        block['type'],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.redAccent),
                  onPressed: () {
                    setState(() {
                      _visualBlocks.removeAt(index);
                      _codeController.text = _compileBlocksToCode();
                    });
                    if (_isActivated) _runModifiedCode();
                  },
                ),
                const Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.topscoreBlue),
              ],
            ),
          ),
        );
      },
    ),
  ),
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextButton.icon(
      onPressed: _addNewBlock,
      icon: const Icon(Icons.add_circle_outline, size: 20),
      label: const Text('Add Shape'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.topscoreBlue,
      ),
    ),
  ),
],
);
}

  Widget _buildCelebrationCard(bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Level $_currentSyllabusLevel Mastered!",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  "You successfully completed the challenge. Ready for the next one?",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (_currentSyllabusLevel < SyllabusData.levels.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      color: AppColors.success,
                      onPressed: () {
                        setState(() {
                          _currentSyllabusLevel++;
                          _levelMastered = false;
                          _codeController.text = _cleanInitialCode(
                              SyllabusData.levels[_currentSyllabusLevel - 1]
                                  .code);
                          _activeTab = 1; // Switch to text code for levels
                        });
                        _runModifiedCode();
                      },
                      child: Text(
                        "Next Level",
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotHintPanel(bool isDark, ThemeData theme) {
    if (!_showHintPanel) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.topscoreBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.topscoreBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.lightbulb_fill, color: AppColors.topscoreBlue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: _isSocraticLoading 
                  ? const Center(child: CupertinoActivityIndicator(radius: 10))
                  : Text(
                      _currentSocraticHint ?? "Thinking...",
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
              ),
            ],
          ),
          if (!_isSocraticLoading && _revealCode != null) ...[
            const SizedBox(height: 12),
            CupertinoButton(
              color: AppColors.topscoreBlue.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: _applyEscapeHatchCode,
              child: Text(
                "Apply Solution",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.topscoreBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SyllabusData {
  static final List<SyllabusLevel> levels = [
    SyllabusLevel(
      topic: "Introduction to p5.js",
      code: "function setup() {\n  createCanvas(windowWidth, windowHeight);\n}\n\nfunction draw() {\n  background(220);\n  ellipse(width/2, height/2, 50, 50);\n}",
      successCriteria: "true",
    ),
    SyllabusLevel(
      topic: "Shapes and Colors",
      code: "function setup() {\n  createCanvas(windowWidth, windowHeight);\n}\n\nfunction draw() {\n  background(220);\n  fill(255, 0, 0);\n  rect(width/2 - 25, height/2 - 25, 50, 50);\n}",
      successCriteria: "true",
    ),
    SyllabusLevel(
      topic: "Variables and Animation",
      code: "let x = 0;\nfunction setup() {\n  createCanvas(windowWidth, windowHeight);\n}\n\nfunction draw() {\n  background(220);\n  ellipse(x, height/2, 50, 50);\n  x = (x + 2) % width;\n}",
      successCriteria: "true",
    ),
    SyllabusLevel(
      topic: "Interactivity",
      code: "function setup() {\n  createCanvas(windowWidth, windowHeight);\n}\n\nfunction draw() {\n  background(220);\n  ellipse(mouseX, mouseY, 50, 50);\n}",
      successCriteria: "true",
    ),
    SyllabusLevel(
      topic: "Loops",
      code: "function setup() {\n  createCanvas(windowWidth, windowHeight);\n}\n\nfunction draw() {\n  background(220);\n  for (let i = 0; i < 10; i++) {\n    ellipse(i * 40 + 20, height/2, 30, 30);\n  }\n}",
      successCriteria: "true",
    ),
    SyllabusLevel(
      topic: "Advanced Creativity",
      code: "function setup() {\n  createCanvas(windowWidth, windowHeight);\n  background(220);\n}\n\nfunction draw() {\n  if (mouseIsPressed) {\n    fill(random(255), random(255), random(255));\n    ellipse(mouseX, mouseY, 20, 20);\n  }\n}",
      successCriteria: "true",
    ),
  ];
}

class SyllabusLevel {
  final String topic;
  final String code;
  final String successCriteria;

  SyllabusLevel({required this.topic, required this.code, required this.successCriteria});
}

class _P5FullscreenPreview extends StatelessWidget {
  final String title;
  final String html;
  final List<Map<String, dynamic>> tweakableVariables;
  final Function(String, double) onUpdateVariable;
  final bool isDark;

  const _P5FullscreenPreview({
    required this.title,
    required this.html,
    required this.tweakableVariables,
    required this.onUpdateVariable,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: html,
                  mimeType: 'text/html',
                  encoding: 'utf-8',
                ),
                initialSettings: InAppWebViewSettings(
                  transparentBackground: true,
                ),
              ),
            ),
            if (tweakableVariables.isNotEmpty)
              Container(
                height: 150,
                color: isDark ? AppColors.surfaceDark : Colors.white,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tweakableVariables.length,
                  itemBuilder: (context, index) {
                    final v = tweakableVariables[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['name']),
                        Slider(
                          value: v['current'],
                          min: v['min'],
                          max: v['max'],
                          onChanged: (val) => onUpdateVariable(v['name'], val),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}