import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Clocky, the mascot: walks in from the right edge when [visible] turns on,
/// then walks in place in the bottom-right corner. Fades out when [visible]
/// turns off. Fills its parent; clicks pass through.
class Clocky extends StatefulWidget {
  final bool visible;
  const Clocky({super.key, required this.visible});

  static const double size = 64;
  static const double rightGap = 12;
  static const int _frames = 12; // assets/images/clocky_walk.png, one row

  @override
  State<Clocky> createState() => _ClockyState();
}

class _ClockyState extends State<Clocky> with TickerProviderStateMixin {
  // 12 frames at ~15 fps: slower than make_walk.py (~18 fps), calmer.
  late final _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  // Starts just past the right edge, so Clocky shows at once; eases out
  // into the corner.
  late final _enter = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late final _enterCurve = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _show();
  }

  @override
  void didUpdateWidget(Clocky old) {
    super.didUpdateWidget(old);
    if (widget.visible && !old.visible) _show();
  }

  void _show() {
    _walk.repeat();
    _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _enterCurve.dispose();
    _walk.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        // Stop the walk ticker once fully hidden.
        onEnd: () {
          if (!widget.visible) _walk.stop();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_walk, _enter]),
          builder: (context, _) {
            final frame =
                (_walk.value * Clocky._frames).floor() % Clocky._frames;
            return Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: Clocky.rightGap),
                child: Transform.translate(
                  offset: Offset(
                    (1 - _enterCurve.value) * (Clocky.size + Clocky.rightGap),
                    0,
                  ),
                  child: SizedBox.square(
                    dimension: Clocky.size,
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: Clocky.size * Clocky._frames,
                        alignment: Alignment(
                          -1 + 2 * frame / (Clocky._frames - 1),
                          0,
                        ),
                        child: Image.asset(
                          'assets/images/clocky_walk.png',
                          width: Clocky.size * Clocky._frames,
                          height: Clocky.size,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
