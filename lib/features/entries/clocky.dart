import 'dart:async';

import 'package:lottie/lottie.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Clocky, the mascot, in the bottom-right corner. The first time [walking]
/// turns on, Clocky walks in from the right, then walks in a loop. When
/// [walking] turns off, Clocky stops and breathes in place; when it turns on
/// again, Clocky restarts. Fills its parent; clicks pass through.
///
/// Timeline of assets/lottie/clockodile.lottie (30 fps, 828 frames):
/// enter 0-144, walk 144-288, then 3 variants k of 180 frames at 288+180k:
/// stop +0..48, idle +48..132 (loop), restart +132..180.
/// The variant matches the walk phase where Clocky stops, so the ground
/// never jumps. Each restart resumes the walk at [_ClockyState._resume].
class Clocky extends StatefulWidget {
  final bool walking;
  const Clocky({super.key, required this.walking});

  static const double width = 130;

  @override
  State<Clocky> createState() => _ClockyState();
}

class _ClockyState extends State<Clocky> with SingleTickerProviderStateMixin {
  // ponytail: frame numbers mirror the markers in the Lottie file; keep in sync.
  static const _total = 828.0;
  static const _fps = 30;
  static const _speed = 1.25; // playback rate, 1 = as authored
  static const _walkStart = 144.0, _walkEnd = 288.0;
  static const _variantOf = {288: 0, 192: 1, 240: 2};
  static const _resume = [192.0, 240.0, 144.0];

  late final _c = AnimationController(vsync: this);
  late bool _walk = widget.walking;
  Completer<void>? _wake;

  @override
  void didUpdateWidget(Clocky old) {
    super.didUpdateWidget(old);
    if (widget.walking == _walk) return;
    _walk = widget.walking;
    _wake?.complete();
    _wake = null;
  }

  Future<void> _until(bool Function() ok) async {
    while (!ok()) {
      _wake = Completer();
      await _wake!.future;
    }
  }

  double get _frame => _c.value * _total;
  Duration _dur(double frames) =>
      Duration(microseconds: (frames / (_fps * _speed) * 1e6).round());

  Future<void> _to(double frame) =>
      _c.animateTo(frame / _total, duration: _dur(frame - _frame));

  void _loop(double from, double to) => _c.repeat(
    min: from / _total,
    max: to / _total,
    period: _dur(to - from),
  );

  Future<void> _run() async {
    await _until(() => _walk);
    await _to(_walkStart); // enter
    while (mounted) {
      _loop(_walkStart, _walkEnd);
      await _until(() => !_walk);
      // Walk on to the next cycle boundary. Right after enter (or a
      // resume at 144) Clocky is already at a boundary.
      final f = _frame;
      final b = f <= _walkStart
          ? 288
          : _variantOf.keys.where((b) => b >= f).reduce((a, b) => a < b ? a : b);
      if (f > _walkStart) await _to(b.toDouble());
      final k = _variantOf[b]!;
      final base = _walkEnd + 180 * k;

      _c.value = base / _total;
      await _to(base + 48); // stop
      _loop(base + 48, base + 132); // idle
      await _until(() => _walk);
      await _to(base + 132); // finish the idle breath, so restart starts clean
      await _to(base + 180); // restart
      _c.value = _resume[k] / _total;
    }
  }

  // dotLottie exports don't agree on an animation folder name (seen:
  // `animations/`, `a/`), so take any top-level json that isn't the manifest.
  static Future<LottieComposition?> _decoder(List<int> bytes) =>
      LottieComposition.decodeZip(
        bytes,
        filePicker: (files) => files
            .where((f) => f.name.endsWith('.json') && f.name != 'manifest.json')
            .firstOrNull,
      );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(
          width: Clocky.width,
          child: Lottie.asset(
            'assets/lottie/clockodile.lottie',
            decoder: _decoder,
            controller: _c,
            frameRate: FrameRate.max,
            onLoaded: (_) => _run(),
          ),
        ),
      ),
    );
  }
}
