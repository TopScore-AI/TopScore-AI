import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports for platform-specific rendering
import 'desmos_platform_view_stub.dart'
    if (dart.library.js_interop) 'desmos_platform_view_web.dart'
    if (dart.library.io) 'desmos_platform_view_mobile.dart';

class DesmosCalculatorWidget extends StatefulWidget {
  final String calculatorType; // graphing, graphing3d, geometry, scientific
  final List<String> expressions;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? viewport;
  final Map<String, dynamic>? displaySettings;

  const DesmosCalculatorWidget({
    super.key,
    required this.calculatorType,
    required this.expressions,
    this.settings,
    this.viewport,
    this.displaySettings,
  });

  @override
  State<DesmosCalculatorWidget> createState() => _DesmosCalculatorWidgetState();
}

class _DesmosCalculatorWidgetState extends State<DesmosCalculatorWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    developer.log('DesmosCalculatorWidget: Initializing widget for type ${widget.calculatorType} (Web: $kIsWeb)', name: 'DesmosWidget');
    
    // Simulate loading for better UX
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  String _generateHtml() {
    const apiKey = 'dd5e8c23a2ea4690a197c472e628f860';
    
    // Map internal types to Desmos JS constructor names
    String desmosConstructor;
    switch (widget.calculatorType) {
      case 'graphing3d':
        desmosConstructor = 'Calculator3D';
        break;
      case 'geometry':
        desmosConstructor = 'GeometryCalculator';
        break;
      case 'scientific':
        desmosConstructor = 'ScientificCalculator';
        break;
      default:
        desmosConstructor = 'GraphingCalculator';
    }

    final expressionsJson = jsonEncode(widget.expressions);
    final viewportJson = jsonEncode(widget.viewport);
    final displayJson = jsonEncode(widget.displaySettings);

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
    <script src="https://www.desmos.com/api/v1.11/calculator.js?apiKey=$apiKey"></script>
    <style>
        body, html { 
          margin: 0; 
          padding: 0; 
          height: 100vh; 
          width: 100vw;
          overflow: hidden; 
          background: transparent;
        }
        #calculator { width: 100%; height: 100%; }
        /* Hide Desmos logo/branding info if needed via CSS, though usually restricted by TOS */
    </style>
</head>
<body>
    <div id="calculator"></div>
    <script>
        window.onload = function() {
          try {
            var elt = document.getElementById('calculator');
            var calculator = Desmos.$desmosConstructor(elt, {
              autosize: true,
              keypad: true,
              expressions: true,
              expressionsCollapsed: true,
              settingsMenu: true,
              zoomButtons: true
            });

            var expressions = $expressionsJson;
            var viewport = $viewportJson;
            var display = $displayJson;

            expressions.forEach(function(exp, index) {
                calculator.setExpression({ id: 'exp' + index, latex: exp });
            });

            if (viewport) {
              calculator.setViewport([
                viewport.xmin || -10, 
                viewport.xmax || 10, 
                viewport.ymin || -10, 
                viewport.ymax || 10
              ]);
            }

            if (display) {
              calculator.updateSettings({
                showGrid: display.showGrid !== false,
                showXAxis: display.showXAxis !== false,
                showYAxis: display.showYAxis !== false
              });
            }
            
            // Handle scientific calculator specific state if needed
            if ('$desmosConstructor' === 'ScientificCalculator') {
               // Scientific API is more limited, but setExpression still works for results
            }
          } catch (e) {
            console.error("Desmos Init Error:", e);
          }
        };
    </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
              createPlatformView(
                key: ValueKey('desmos-${widget.calculatorType}'),
                html: _generateHtml(),
              ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.calculatorType.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: Colors.black54),
                onPressed: () => _showFullScreen(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: Text('Desmos ${widget.calculatorType}'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: createPlatformView(
                key: ValueKey('desmos-fs-${widget.calculatorType}'),
                html: _generateHtml(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
