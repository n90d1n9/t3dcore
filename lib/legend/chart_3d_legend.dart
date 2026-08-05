import 'package:flutter/material.dart';

/// Stand-in for in-scene selection, shared by every chart in this
/// package. `flutter_3d_controller` wraps Google's `<model-viewer>`,
/// which "handles touch events internally" for camera control and does
/// not expose raycasting or per-mesh hit-testing — so there is no real
/// tap-a-bar/tap-a-slice-in-the-scene picking available. This renders a
/// row of tappable labels below the viewport instead: an honest,
/// working substitute that still gives chart consumers a
/// `ChartSelectionEvent`-style callback.
class Chart3DLegend extends StatelessWidget {
  const Chart3DLegend({
    super.key,
    required this.entries,
    required this.onTap,
    this.colors,
  });

  /// Label per entry (categories for a bar chart, slice names for a pie).
  final List<String> entries;
  final ValueChanged<String>? onTap;

  /// Optional per-entry swatch color (RGBA 0..1), shown as a small dot
  /// before the label — most useful for pie/donut charts where color is
  /// the primary way a slice maps to its legend entry.
  final List<List<double>>? colors;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var i = 0; i < entries.length; i++)
            ActionChip(
              avatar: colors == null
                  ? null
                  : CircleAvatar(
                      backgroundColor: Color.fromRGBO(
                        (colors![i % colors!.length][0] * 255).round(),
                        (colors![i % colors!.length][1] * 255).round(),
                        (colors![i % colors!.length][2] * 255).round(),
                        colors![i % colors!.length].length > 3 ? colors![i % colors!.length][3] : 1.0,
                      ),
                    ),
              label: Text(entries[i]),
              onPressed: onTap == null ? null : () => onTap!(entries[i]),
            ),
        ],
      ),
    );
  }
}
