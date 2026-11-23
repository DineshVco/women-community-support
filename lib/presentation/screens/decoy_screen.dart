import 'package:flutter/material.dart';

import '../../core/security/app_lock.dart';
import '../../data/weather.dart';
import '../providers/app_settings.dart';
import '../widgets/app_lock_gate.dart';
import '../widgets/disguise_shell.dart';
import '../widgets/quick_exit_button.dart';

// The two Quick exit disguises. Colours and fonts are deliberately NOT
// Looma's, and nothing on them mentions Looma.

/// Weather disguise. Ways back: press and hold anywhere for 1 second, or
/// triple-tap the temperature. Back button: does nothing. Away for more
/// than 10 minutes: Looma opens again by itself.
class DecoyScreen extends StatefulWidget {
  const DecoyScreen({
    super.key,
    this.practice = false,
    this.now,
    this.service,
    this.city,
    this.clock,
  });

  /// Practice mode: a small hint, and coming back returns to the same page.
  final bool practice;

  /// For tests.
  final DateTime? now;
  final WeatherService? service;

  /// Defaults to the city in Settings (Kuala Lumpur).
  final String? city;

  /// For tests (the 10-minute auto return).
  final DateTime Function()? clock;

  @override
  State<DecoyScreen> createState() => _DecoyScreenState();
}

class _DecoyScreenState extends State<DecoyScreen> {
  static const Color _ink = Color(0xFF14324A);
  static const Color _soft = Color(0xFF3E5D77);

  late final WeatherService _service = widget.service ?? WeatherService();
  WeatherReport? _report;
  bool _started = false;
  bool _leaving = false;

  /// Back to Looma (once, even if two gestures fire together).
  void _return() {
    if (_leaving || !mounted) return;
    _leaving = true;
    QuickExit.comeBack(context, practice: widget.practice);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final city =
        widget.city ??
        AppSettings.maybeOf(context)?.weatherCity ??
        AppSettings.defaultCity;

    // Something believable at once (no waiting), then live if online.
    _report = WeatherReport.offline(city, widget.now ?? DateTime.now());
    _service.instant(city).then((r) {
      if (mounted && !(_report?.live ?? false)) setState(() => _report = r);
    });
    _service.fetch(city).then((r) {
      if (r != null && mounted) setState(() => _report = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = _report!;
    final today = report.days.first;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(report.updatedAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return DisguiseShell(
      onReturn: _return,
      clock: widget.clock,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBFDDF3), Color(0xFFE6F1F9)],
            ),
          ),
          child: SafeArea(
            child: DefaultTextStyle(
              // The phone's own font, like a built-in weather app.
              style: const TextStyle(color: _ink, height: 1.2),
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: _ink,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          report.city,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Updated $time',
                    style: const TextStyle(fontSize: 13, color: _soft),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      // Backup way back: tap the temperature 3 times.
                      // Shrinks a little on a narrow phone or with large
                      // text instead of running off the edge.
                      Flexible(
                        child: TripleTap(
                          onTriple: _return,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${report.temperature}°',
                              key: const ValueKey('weather-temperature'),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 96,
                                fontWeight: FontWeight.w200,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(report.icon, size: 72, color: _ink),
                    ],
                  ),
                  Text(report.condition, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    'H:${today.high}°  L:${today.low}°',
                    style: const TextStyle(fontSize: 16, color: _soft),
                  ),
                  const SizedBox(height: 28),
                  _Panel(
                    // Three equal columns: never wider than the panel, on a
                    // narrow phone or with large text.
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Detail('Feels like', '${report.feelsLike}°'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Detail('Humidity', '${report.humidity}%'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _Detail('Wind', '${report.wind} km/h')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5-DAY FORECAST',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1,
                            color: _soft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < report.days.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 64,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      i == 0
                                          ? 'Today'
                                          : weekdays[report
                                                  .days[i]
                                                  .date
                                                  .weekday -
                                              1],
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                Icon(
                                  i == 0 ? report.icon : report.days[i].icon,
                                  size: 22,
                                  color: _ink,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    i == 0
                                        ? report.condition
                                        : report.days[i].condition,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _soft,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 110,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${report.days[i].low}°  '
                                      '${report.days[i].high}°',
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.practice) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Practice: press and hold anywhere for 1 second to go '
                      'back.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _soft),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The label may wrap onto two lines with large text.
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF3E5D77)),
        ),
        const SizedBox(height: 4),
        // The value stays on one line and shrinks a little if it must.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

// ───────────────────────── Calculator disguise ─────────────────────────

/// The arithmetic behind the calculator: + − × ÷ with the usual order
/// (× and ÷ before + and −), decimals, ±, % and clear.
class CalculatorEngine {
  final List<String> _tokens = [];
  String _entry = '';
  bool _justEvaluated = false;

  static const Set<String> operators = {'+', '−', '×', '÷'};

  /// What the display shows.
  String get display {
    final shown = [..._tokens, if (_entry.isNotEmpty) _entry].join(' ');
    return shown.isEmpty ? '0' : shown;
  }

  /// The digits typed with no operator before them. Used to check the PIN
  /// when "=" is pressed.
  String? get plainEntry =>
      _tokens.isEmpty && RegExp(r'^[0-9]+$').hasMatch(_entry) ? _entry : null;

  void digit(String d) {
    if (_justEvaluated) {
      _entry = '';
      _justEvaluated = false;
    }
    if (_entry.replaceAll(RegExp('[^0-9]'), '').length >= 12) return;
    _entry = _entry == '0' ? d : _entry + d;
  }

  void decimal() {
    if (_justEvaluated) {
      _entry = '';
      _justEvaluated = false;
    }
    if (_entry.contains('.')) return;
    _entry = _entry.isEmpty ? '0.' : '$_entry.';
  }

  void operator(String op) {
    _justEvaluated = false;
    if (_entry.isNotEmpty) {
      _tokens
        ..add(_entry)
        ..add(op);
      _entry = '';
    } else if (_tokens.isNotEmpty && operators.contains(_tokens.last)) {
      _tokens[_tokens.length - 1] = op; // changed her mind
    } else if (_tokens.isEmpty) {
      _tokens
        ..add('0')
        ..add(op);
    }
  }

  void toggleSign() {
    if (_entry.isEmpty || _entry == '0') return;
    _entry = _entry.startsWith('-') ? _entry.substring(1) : '-$_entry';
  }

  void percent() {
    final value = double.tryParse(_entry);
    if (value == null) return;
    _entry = format(value / 100);
  }

  void clear() {
    _tokens.clear();
    _entry = '';
    _justEvaluated = false;
  }

  /// Works out the result and shows it.
  void equals() {
    final parts = [..._tokens, if (_entry.isNotEmpty) _entry];
    if (parts.isNotEmpty && operators.contains(parts.last)) parts.removeLast();
    if (parts.isEmpty) return;
    _tokens.clear();
    final result = evaluate(parts);
    _entry = result == 'Error' ? '' : result;
    if (result == 'Error') _tokens.add('Error');
    _justEvaluated = true;
  }

  /// [parts] alternate number, operator, number, ...
  static String evaluate(List<String> parts) {
    final first = double.tryParse(parts.first);
    if (first == null) return 'Error';
    final numbers = <double>[first];
    final ops = <String>[];
    for (var i = 1; i + 1 < parts.length; i += 2) {
      final op = parts[i];
      final n = double.tryParse(parts[i + 1]);
      if (n == null) return 'Error';
      if (op == '×') {
        numbers.add(numbers.removeLast() * n);
      } else if (op == '÷') {
        if (n == 0) return 'Error';
        numbers.add(numbers.removeLast() / n);
      } else {
        ops.add(op);
        numbers.add(n);
      }
    }
    var result = numbers.first;
    for (var i = 0; i < ops.length; i++) {
      result =
          ops[i] == '+' ? result + numbers[i + 1] : result - numbers[i + 1];
    }
    return format(result);
  }

  static String format(double value) {
    if (value.isNaN || value.isInfinite) return 'Error';
    if (value == value.roundToDouble() && value.abs() < 1e12) {
      return value.toInt().toString();
    }
    var text = value.toStringAsPrecision(10);
    if (text.contains('.') && !text.contains('e')) {
      text = text
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }
}

/// Calculator disguise. To go back: type her PIN and press "=" (with App
/// lock on), or press and hold the display (no PIN set).
class CalculatorDisguise extends StatefulWidget {
  const CalculatorDisguise({super.key, this.practice = false});

  final bool practice;

  @override
  State<CalculatorDisguise> createState() => _CalculatorDisguiseState();
}

class _CalculatorDisguiseState extends State<CalculatorDisguise> {
  CalculatorEngine _engine = CalculatorEngine();
  bool _checking = false;
  bool _leaving = false;

  void _return({bool unlockedByPin = false}) {
    if (_leaving || !mounted) return;
    _leaving = true;
    _engine.clear();
    QuickExit.comeBack(
      context,
      practice: widget.practice,
      unlockedByPin: unlockedByPin,
    );
  }

  static const Color _background = Color(0xFF000000);
  static const Color _digitKey = Color(0xFF333333);
  static const Color _topKey = Color(0xFFA5A5A5);
  static const Color _opKey = Color(0xFFFF9F0A);

  @override
  void dispose() {
    // Nothing typed here stays in memory after she leaves.
    _engine.clear();
    _engine = CalculatorEngine();
    super.dispose();
  }

  void _tap(void Function(CalculatorEngine e) action) {
    setState(() => action(_engine));
  }

  Future<void> _equals() async {
    if (_checking) return;
    final lock = AppLockScope.maybeOf(context);
    final typed = _engine.plainEntry;
    if (lock != null &&
        lock.enabled &&
        typed != null &&
        typed.length == 6 &&
        lock.waitLeft == Duration.zero) {
      // Counts towards the same wrong-PIN wait as the lock screen, so the
      // calculator cannot be used to guess without limit.
      _checking = true;
      final result = await lock.verify(typed);
      _checking = false;
      if (!mounted) return;
      if (result == PinResult.ok) {
        _return(unlockedByPin: true);
        return;
      }
    }
    _tap((e) => e.equals());
  }

  void _longPressDisplay() {
    final lock = AppLockScope.maybeOf(context);
    // With a PIN, the only way back is PIN + "=".
    if (lock != null && lock.enabled) return;
    _return();
  }

  @override
  Widget build(BuildContext context) {
    final lock = AppLockScope.maybeOf(context);
    final pinWay = lock != null && lock.enabled;

    // Keys are as big as the screen allows: a quarter of the width, but
    // short enough for five rows on a short or wide screen.
    final size = MediaQuery.sizeOf(context);
    final keyHeight = [
      (size.width - 24) / 4,
      (size.height - MediaQuery.paddingOf(context).vertical) * 0.6 / 5,
      96.0,
    ].reduce((a, b) => a < b ? a : b);

    Widget key(
      String label, {
      Color color = _digitKey,
      Color text = Colors.white,
      bool wide = false,
      required VoidCallback onTap,
    }) {
      return Expanded(
        flex: wide ? 2 : 1,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: keyHeight - 12,
            child: Material(
              color: color,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Align(
                  alignment: wide ? const Alignment(-0.6, 0) : Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 30, color: text),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget top(String label, VoidCallback onTap) =>
        key(label, color: _topKey, text: Colors.black, onTap: onTap);
    Widget op(String symbol) => key(
      symbol,
      color: _opKey,
      onTap: () => _tap((e) => e.operator(symbol)),
    );
    Widget digit(String d) => key(d, onTap: () => _tap((e) => e.digit(d)));

    return DisguiseShell(
      // Keys need taps, so no "hold anywhere" here: the way back is the PIN
      // and "=" (or holding the numbers when no PIN is set).
      holdToReturn: false,
      onReturn: _return,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: _longPressDisplay,
                    child: Container(
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _engine.display,
                          key: const ValueKey('calculator-display'),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.practice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      pinWay
                          ? 'Practice: type your PIN, then = to go back.'
                          : 'Practice: press and hold the numbers to go back.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    top('AC', () => _tap((e) => e.clear())),
                    top('±', () => _tap((e) => e.toggleSign())),
                    top('%', () => _tap((e) => e.percent())),
                    op('÷'),
                  ],
                ),
                Row(children: [digit('7'), digit('8'), digit('9'), op('×')]),
                Row(children: [digit('4'), digit('5'), digit('6'), op('−')]),
                Row(children: [digit('1'), digit('2'), digit('3'), op('+')]),
                Row(
                  children: [
                    key(
                      '0',
                      wide: true,
                      onTap: () => _tap((e) => e.digit('0')),
                    ),
                    key('.', onTap: () => _tap((e) => e.decimal())),
                    key('=', color: _opKey, onTap: _equals),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
