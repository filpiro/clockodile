import 'package:catui/catui.dart';
import 'package:flutter/material.dart';

import '../../shared/utils/colors.dart';
import '../../shared/utils/format.dart';
import 'board_geometry.dart';
import 'normalize.dart';
import 'report_view.dart';

/// Width of the hour-label gutter on the left of the board.
const _gutter = 56.0;

/// Height of the hairline standing in for a zero- or negative-length row.
const _hairline = 2.0;

/// The day as a vertical time board: one full-width column on a wall-clock
/// axis, each Session a tile whose height *is* its normalized duration.
/// Presentation only — same rows, same total, same CSV as the grouped list.
class ReportBoard extends StatelessWidget {
  final List<ReportRow> rows;
  const ReportBoard(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final axis = boardAxis(rows);
    if (axis == null) return const SizedBox.shrink();
    final (axisStart, axisEnd) = axis;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      // Vertical room for the first and last hour labels, which straddle the
      // axis bounds and so overhang the board box at both ends.
      padding: const EdgeInsets.fromLTRB(0, 8, 12, 20),
      child: SizedBox(
        height: boardOffset(axisStart, axisEnd),
        child: Stack(
          // The closing hour's gridline sits exactly on the bottom edge, and
          // both end labels overhang — none of it may be clipped away.
          clipBehavior: Clip.none,
          children: [
            for (final h in hourMarks(axisStart, axisEnd)) ...[
              Positioned(
                top: boardOffset(axisStart, h),
                left: _gutter,
                right: 0,
                child: Container(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              Positioned(
                // Label centred on its gridline.
                top: boardOffset(axisStart, h) - 7,
                left: 0,
                width: _gutter - 8,
                child: Text(
                  hhmm(h),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            for (final r in rows)
              Positioned(
                top: boardOffset(axisStart, r.normStart),
                left: _gutter,
                right: 0,
                height: isHairlineRow(r.normDuration)
                    ? _hairline
                    : tileHeight(r.normDuration),
                child: _BoardTile(r, key: ValueKey(r.session.id)),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardTile extends StatefulWidget {
  final ReportRow r;
  const _BoardTile(this.r, {super.key});

  @override
  State<_BoardTile> createState() => _BoardTileState();
}

class _BoardTileState extends State<_BoardTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final note = r.entry.note;
    final degenerate = isHairlineRow(r.normDuration);

    // Everything a short tile clips — a zero-length row's only text at all.
    final tooltip = [
      r.client.name,
      '${hhmm(r.normStart)}–${hhmm(r.normEnd)} (${formatHm(r.normDuration)})',
      'reale ${hhmm(r.session.start)}–${hhmm(r.session.end!)}',
      if (note.isNotEmpty) note,
    ].join('\n');

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          // Same deal as the list rows: tap copies the note, no note no tap.
          onTap: note.isEmpty ? null : () => copyNote(context, note),
          // Same fade as HoverTile, so board hover reads like every other
          // hoverable surface in the app.
          child: TweenAnimationBuilder<double>(
            duration: AppTokens.hoverFade,
            tween: Tween(end: _hover ? 1.0 : 0.0),
            // Height alone decides how much content survives: a short tile
            // ends up showing only the client name. OverflowBox keeps that a
            // clip rather than an overflow error. Built once — hover only
            // repaints the fill.
            child: degenerate
                ? null
                : ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.client.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              '${hhmm(r.normStart)}–${hhmm(r.normEnd)}'
                              ' (${formatHm(r.normDuration)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (note.isNotEmpty)
                              Text(
                                note,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            builder: (context, t, child) => Container(
              decoration: BoxDecoration(
                // A zero- or negative-length row has no room for borders: it
                // is the hairline. Never hidden.
                color: degenerate
                    ? cs.error
                    : Color.lerp(
                        cs.surfaceContainer,
                        cs.surfaceContainerHighest,
                        t,
                      ),
                // Borders inset the content without changing the box height,
                // so contiguous tiles still sum to their combined duration.
                border: degenerate
                    ? null
                    : Border(
                        left: BorderSide(
                          color: hexToColor(r.client.colorHex),
                          width: 4,
                        ),
                        top: BorderSide(color: cs.surface),
                        bottom: BorderSide(color: cs.surface),
                      ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
