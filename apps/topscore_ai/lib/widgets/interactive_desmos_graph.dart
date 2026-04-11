import 'package:flutter/material.dart';
import 'desmos_calculator_widget.dart';

class InteractiveDesmosGraph extends StatelessWidget {
  final Map<String, dynamic> config;

  const InteractiveDesmosGraph({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    // The config can be:
    // {
    //   "type": "desmos_config", 
    //   "expression": "y=x^2, y=x^2+2", 
    //   "viewport": {"xmin": -10, "xmax": 10, "ymin": -10, "ymax": 10}, 
    //   "settings": {"showGrid": true, "showXAxis": true, "showYAxis": true}
    // }
    
    final rawExpression = config['expression'] ?? '';
    final List<String> expressions = rawExpression.toString().split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    final viewport = config['viewport'] as Map<String, dynamic>?;
    final displaySettings = config['settings'] as Map<String, dynamic>?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DesmosCalculatorWidget(
        calculatorType: 'graphing',
        expressions: expressions,
        viewport: viewport,
        displaySettings: displaySettings,
      ),
    );
  }
}
