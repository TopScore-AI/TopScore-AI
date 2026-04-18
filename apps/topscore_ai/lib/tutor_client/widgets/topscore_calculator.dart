import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart';

class TopScoreCalculator extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onClose;

  const TopScoreCalculator({
    super.key,
    this.isCompact = false,
    this.onClose,
  });

  @override
  State<TopScoreCalculator> createState() => _TopScoreCalculatorState();
}

class _TopScoreCalculatorState extends State<TopScoreCalculator> {
  String _expression = '';
  String _result = '0';
  bool _isDegree = true;
  bool _justEvaluated = false;

  // ---------------------------------------------------------------------------
  // Degree → Radian conversion for trig functions
  // ---------------------------------------------------------------------------
  String _prepareExpression(String input) {
    String expr = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', '3.14159265358979')
        .replaceAll('e', '2.71828182845905');

    if (!_isDegree) return expr;

    for (final fn in ['sin', 'cos', 'tan']) {
      expr = expr.replaceAllMapped(RegExp('$fn\\(([^)]+)\\)'), (m) {
        return '$fn((${m[1]}) * 3.14159265358979 / 180)';
      });
    }
    return expr;
  }

  void _onPressed(String text) {
    HapticFeedback.lightImpact();
    setState(() {
      switch (text) {
        case 'C':
          _expression = '';
          _result = '0';
          _justEvaluated = false;
          break;

        case '⌫':
          if (_expression.isNotEmpty) {
            final fns = ['sin(', 'cos(', 'tan(', 'log(', 'ln(', 'sqrt(', 'asin(', 'acos(', 'atan('];
            bool removed = false;
            for (final fn in fns) {
              if (_expression.endsWith(fn)) {
                _expression = _expression.substring(0, _expression.length - fn.length);
                removed = true;
                break;
              }
            }
            if (!removed) _expression = _expression.substring(0, _expression.length - 1);
          }
          _justEvaluated = false;
          break;

        case '=':
          _evaluate();
          break;

        case '%':
          if (_expression.isNotEmpty) {
            _expression += '/100';
          }
          break;

        case '+/-':
          if (_expression.isNotEmpty) {
            if (_expression.startsWith('-')) {
              _expression = _expression.substring(1);
            } else {
              _expression = '-$_expression';
            }
          }
          break;

        case 'π':
        case 'e':
          if (_justEvaluated) { _expression = text; _justEvaluated = false; }
          else { _expression += text; }
          break;

        case 'sin':
        case 'cos':
        case 'tan':
        case 'asin':
        case 'acos':
        case 'atan':
        case 'log':
        case 'ln':
        case 'sqrt':
          if (_justEvaluated) { _expression = '$text('; _justEvaluated = false; }
          else { _expression += '$text('; }
          break;

        case 'x²':
          _expression += '^2';
          break;

        case 'x³':
          _expression += '^3';
          break;

        case '^':
          _expression += '^';
          break;

        default:
          if (_justEvaluated && RegExp(r'[0-9]').hasMatch(text)) {
            _expression = text;
            _justEvaluated = false;
          } else if (_justEvaluated && RegExp(r'[+\-×÷^]').hasMatch(text)) {
            _expression = _result + text;
            _justEvaluated = false;
          } else {
            _expression += text;
            _justEvaluated = false;
          }
      }

      if (!_justEvaluated && _expression.isNotEmpty) {
        _liveEval();
      }
    });
  }

  void _evaluate() {
    if (_expression.isEmpty) return;
    try {
      final prepared = _prepareExpression(_expression);
      final p = GrammarParser();
      final eval = RealEvaluator(ContextModel()).evaluate(p.parse(prepared));
      _result = _formatNumber(eval.toDouble());
      _justEvaluated = true;
    } catch (_) {
      _result = 'Error';
    }
  }

  void _liveEval() {
    try {
      final prepared = _prepareExpression(_expression);
      final p = GrammarParser();
      final eval = RealEvaluator(ContextModel()).evaluate(p.parse(prepared));
      _result = _formatNumber(eval.toDouble());
    } catch (_) {}
  }

  String _formatNumber(double val) {
    if (val.isNaN || val.isInfinite) return 'Error';
    if (val == val.truncateToDouble() && val.abs() < 1e15) {
      return val.toInt().toString();
    }
    final s = val.toStringAsPrecision(10);
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Column(
      children: [
        // Header Row with Close Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SCIENTIFIC",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
                  color: theme.hintColor,
                  tooltip: 'Minimize',
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        // Display Area
        _buildDisplay(isDark, theme),
        
        // Mode Selector (DEG/RAD)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDegree = !_isDegree),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isDegree ? 'DEG' : 'RAD',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Keypad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildKeypad(theme, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildDisplay(bool isDark, ThemeData theme) {
    final displayBg = isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.05);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: displayBg,
        border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _expression.isEmpty ? ' ' : _expression,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _result,
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, bool isDark) {
    final numBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final opBg = theme.colorScheme.primary;
    final fnBg = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1);

    return Column(
      children: [
        // Scientific Row
        _row([
          _btn('sin', fnBg, theme.colorScheme.onSurface),
          _btn('cos', fnBg, theme.colorScheme.onSurface),
          _btn('tan', fnBg, theme.colorScheme.onSurface),
          _btn('π', fnBg, theme.colorScheme.onSurface),
          _btn('e', fnBg, theme.colorScheme.onSurface),
        ]),
        _row([
          _btn('sqrt', fnBg, theme.colorScheme.onSurface, label: '√'),
          _btn('x²', fnBg, theme.colorScheme.onSurface),
          _btn('^', fnBg, theme.colorScheme.onSurface, label: 'xʸ'),
          _btn('(', fnBg, theme.colorScheme.onSurface),
          _btn(')', fnBg, theme.colorScheme.onSurface),
        ]),
        // Standard Grid
        _row([
          _btn('C', fnBg, Colors.redAccent),
          _btn('%', fnBg, theme.colorScheme.onSurface),
          _btn('⌫', fnBg, theme.colorScheme.primary),
          _btn('÷', opBg, Colors.white),
        ]),
        _row([
          _btn('7', numBg, theme.colorScheme.onSurface),
          _btn('8', numBg, theme.colorScheme.onSurface),
          _btn('9', numBg, theme.colorScheme.onSurface),
          _btn('×', opBg, Colors.white),
        ]),
        _row([
          _btn('4', numBg, theme.colorScheme.onSurface),
          _btn('5', numBg, theme.colorScheme.onSurface),
          _btn('6', numBg, theme.colorScheme.onSurface),
          _btn('-', opBg, Colors.white),
        ]),
        _row([
          _btn('1', numBg, theme.colorScheme.onSurface),
          _btn('2', numBg, theme.colorScheme.onSurface),
          _btn('3', numBg, theme.colorScheme.onSurface),
          _btn('+', opBg, Colors.white),
        ]),
        _row([
          _btn('+/-', numBg, theme.colorScheme.onSurface),
          _btn('0', numBg, theme.colorScheme.onSurface),
          _btn('.', numBg, theme.colorScheme.onSurface),
          _btn('=', opBg, Colors.white),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Expanded(
    child: Row(children: children),
  );

  Widget _btn(String value, Color bg, Color fg, {String? label}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _onPressed(value),
            child: Center(
              child: Text(
                label ?? value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
