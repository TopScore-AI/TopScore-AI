import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../constants/colors.dart';

// ---------------------------------------------------------------------------
// Scientific Calculator — production-grade with history, constants, all modes
// ---------------------------------------------------------------------------
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  String _expression = '';
  String _result = '0';
  bool _isDegree = true;
  bool _justEvaluated = false;

  // History
  final List<_HistoryEntry> _history = [];
  bool _showHistory = false;

  late TabController _modeTab;

  @override
  void initState() {
    super.initState();
    _modeTab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _modeTab.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Degree → Radian conversion for trig functions
  // ---------------------------------------------------------------------------
  String _prepareExpression(String input) {
    // Replace display symbols with parseable ones
    String expr = input
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('π', '3.14159265358979')
        .replaceAll('e', '2.71828182845905');

    if (!_isDegree) return expr;

    // Wrap trig args with degree→radian conversion
    for (final fn in ['sin', 'cos', 'tan']) {
      expr = expr.replaceAllMapped(RegExp('$fn\\(([^)]+)\\)'), (m) {
        return '$fn((${m[1]}) * 3.14159265358979 / 180)';
      });
    }
    return expr;
  }

  // ---------------------------------------------------------------------------
  // Button press handler
  // ---------------------------------------------------------------------------
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
            // Remove last function token if present
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

        case '10ˣ':
          _expression += '10^';
          break;

        case 'eˣ':
          _expression = 'e^($_expression)';
          break;

        case '1/x':
          if (_expression.isNotEmpty) _expression = '1/($_expression)';
          break;

        default:
          // If just evaluated and user types a digit, start fresh
          if (_justEvaluated && RegExp(r'[0-9]').hasMatch(text)) {
            _expression = text;
            _justEvaluated = false;
          } else if (_justEvaluated && RegExp(r'[+\-×÷^]').hasMatch(text)) {
            // Continue from result
            _expression = _result + text;
            _justEvaluated = false;
          } else {
            _expression += text;
            _justEvaluated = false;
          }
      }

      // Live preview
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
      // ignore: deprecated_member_use
      final eval = p.parse(prepared).evaluate(EvaluationType.REAL, ContextModel()) as double;
      final resultStr = _formatNumber(eval);
      _history.insert(0, _HistoryEntry(expression: _expression, result: resultStr));
      if (_history.length > 50) _history.removeLast();
      _result = resultStr;
      _justEvaluated = true;
    } catch (_) {
      _result = 'Error';
    }
  }

  void _liveEval() {
    try {
      final prepared = _prepareExpression(_expression);
      final p = GrammarParser();
      // ignore: deprecated_member_use
      final eval = p.parse(prepared).evaluate(EvaluationType.REAL, ContextModel()) as double;
      _result = _formatNumber(eval);
    } catch (_) {
      // Don't show error during live eval — expression may be incomplete
    }
  }

  String _formatNumber(double val) {
    if (val.isNaN || val.isInfinite) return 'Error';
    if (val == val.truncateToDouble() && val.abs() < 1e15) {
      return val.toInt().toString();
    }
    // Up to 10 significant digits
    final s = val.toStringAsPrecision(10);
    // Remove trailing zeros after decimal
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final displayBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Calculator', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          // DEG/RAD toggle
          GestureDetector(
            onTap: () => setState(() => _isDegree = !_isDegree),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _isDegree ? 'DEG' : 'RAD',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          // History toggle
          IconButton(
            icon: Icon(
              Icons.history_rounded,
              color: _showHistory ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            onPressed: () => setState(() => _showHistory = !_showHistory),
            tooltip: 'History',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Display
            _buildDisplay(displayBg, isDark, theme),
            // History panel
            if (_showHistory) _buildHistoryPanel(theme, isDark),
            // Buttons
            Expanded(child: _buildButtons(theme, isDark, bg)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay(Color displayBg, bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: displayBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expression
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _expression.isEmpty ? ' ' : _expression,
              style: GoogleFonts.inter(
                fontSize: 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Result
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: _result));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _result,
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel(ThemeData theme, bool isDark) {
    if (_history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No history yet', style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
      );
    }
    return Container(
      height: 160,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _history.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
        itemBuilder: (ctx, i) {
          final entry = _history[i];
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(entry.expression, style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            trailing: Text(
              '= ${entry.result}',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
            ),
            onTap: () => setState(() {
              _expression = entry.result;
              _result = entry.result;
              _showHistory = false;
            }),
          );
        },
      ),
    );
  }

  Widget _buildButtons(ThemeData theme, bool isDark, Color bg) {
    // Button colors
    final numBg = isDark ? const Color(0xFF3A3A3C) : Colors.white;
    final opBg = theme.colorScheme.primary;
    final fnBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final clearBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFFF3B30).withValues(alpha: 0.12);
    final clearFg = const Color(0xFFFF3B30);

    // Layout: scientific row + standard grid
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          // Scientific row 1
          _row([
            _btn('sin', fnBg, theme.colorScheme.onSurface),
            _btn('cos', fnBg, theme.colorScheme.onSurface),
            _btn('tan', fnBg, theme.colorScheme.onSurface),
            _btn('log', fnBg, theme.colorScheme.onSurface),
            _btn('ln', fnBg, theme.colorScheme.onSurface),
          ]),
          // Scientific row 2
          _row([
            _btn('sqrt', fnBg, theme.colorScheme.onSurface, label: '√'),
            _btn('x²', fnBg, theme.colorScheme.onSurface),
            _btn('^', fnBg, theme.colorScheme.onSurface, label: 'xʸ'),
            _btn('π', fnBg, theme.colorScheme.onSurface),
            _btn('e', fnBg, theme.colorScheme.onSurface),
          ]),
          // Row: C, +/-, %, ÷
          _row([
            _btn('C', clearBg, clearFg),
            _btn('+/-', fnBg, theme.colorScheme.onSurface),
            _btn('%', fnBg, theme.colorScheme.onSurface),
            _btn('÷', opBg, Colors.white),
          ]),
          // Row: 7 8 9 ×
          _row([
            _btn('7', numBg, theme.colorScheme.onSurface),
            _btn('8', numBg, theme.colorScheme.onSurface),
            _btn('9', numBg, theme.colorScheme.onSurface),
            _btn('×', opBg, Colors.white),
          ]),
          // Row: 4 5 6 -
          _row([
            _btn('4', numBg, theme.colorScheme.onSurface),
            _btn('5', numBg, theme.colorScheme.onSurface),
            _btn('6', numBg, theme.colorScheme.onSurface),
            _btn('-', opBg, Colors.white),
          ]),
          // Row: 1 2 3 +
          _row([
            _btn('1', numBg, theme.colorScheme.onSurface),
            _btn('2', numBg, theme.colorScheme.onSurface),
            _btn('3', numBg, theme.colorScheme.onSurface),
            _btn('+', opBg, Colors.white),
          ]),
          // Row: ( 0 . ⌫ =
          _row([
            _btn('(', fnBg, theme.colorScheme.onSurface),
            _btn('0', numBg, theme.colorScheme.onSurface),
            _btn('.', numBg, theme.colorScheme.onSurface),
            _btn('⌫', fnBg, AppColors.googleYellow),
            _btn('=', opBg, Colors.white),
          ]),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => Expanded(
    child: Row(children: children),
  );

  Widget _btn(String value, Color bg, Color fg, {String? label}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _onPressed(value),
            child: Center(
              child: Text(
                label ?? value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
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

class _HistoryEntry {
  final String expression;
  final String result;
  _HistoryEntry({required this.expression, required this.result});
}
