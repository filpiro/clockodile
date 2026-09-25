import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../shared/utils/format.dart';
import '../../shared/widgets/identicon.dart';
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
    final cs = Theme.of(context).colorScheme;

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
                  color: cs.border,
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
                ).small().muted(),
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

class _BoardTile extends StatelessWidget {
  final ReportRow r;
  const _BoardTile(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = r.entry.note;
    final degenerate = isHairlineRow(r.normDuration);
    final span =
        '${hhmm(r.normStart)}–${hhmm(r.normEnd)} (${formatHm(r.normDuration)})';

    return Tooltip(
      // Everything a short tile clips — a zero-length row's only text at all.
      tooltip: (_) => TooltipContainer(
        child: Text(
          [
            r.client.name,
            span,
            'reale ${hhmm(r.session.start)}–${hhmm(r.session.end!)}',
            if (note.isNotEmpty) note,
          ].join('\n'),
        ),
      ),
      child: Clickable(
        // Same deal as the list rows: tap copies the note, no note no tap.
        onPressed: note.isEmpty ? null : () => copyNote(note),
        mouseCursor: WidgetStatePropertyAll(
          note.isEmpty ? MouseCursor.defer : SystemMouseCursors.click,
        ),
        decoration: WidgetStateProperty.resolveWith(
          (states) => BoxDecoration(
            // A zero- or negative-length row has no room for borders: it is
            // the hairline. Never hidden.
            color: degenerate ? cs.destructive : cs.muted,
            // Borders inset the content without changing the box height, so
            // contiguous tiles still sum to their combined duration. The
            // left edge is always there so hover never shifts the content;
            // it only turns primary under the pointer.
            border: degenerate
                ? null
                : Border(
                    left: BorderSide(
                      color: states.contains(WidgetState.hovered)
                          ? cs.primary
                          : cs.muted,
                      width: 3,
                    ),
                    top: BorderSide(color: cs.background),
                    bottom: BorderSide(color: cs.background),
                  ),
          ),
        ),
        // Height alone decides how much content survives: a short tile ends
        // up showing only the client name. OverflowBox keeps that a clip
        // rather than an overflow error.
        child: degenerate
            ? const SizedBox.expand()
            : ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  // Laid out like an entity list row, tighter vertically:
                  // a half-hour tile is only 48px tall.
                  child: Basic(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Identicon(r.client.id, size: Identicon.small),
                    title: Text(
                      r.client.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      span,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
