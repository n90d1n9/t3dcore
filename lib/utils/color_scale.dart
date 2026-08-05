/// A linear multi-stop color gradient over `t` in `[0, 1]`, used wherever
/// a chart needs to turn a data magnitude into a color instead of (or in
/// addition to) a height — heatmap cells and geo markers both go through
/// this rather than each hand-rolling their own lerp.
class ColorScale {
  const ColorScale(this.stops);

  /// RGBA stops (each `List<double>` length 3 or 4, values 0..1), evenly
  /// spaced across `t = 0..1`.
  final List<List<double>> stops;

  /// Classic "cold to hot" heatmap scale: blue -> yellow -> red.
  static const ColorScale heat = ColorScale([
    [0.16, 0.32, 0.75, 1.0], // cool blue
    [0.96, 0.80, 0.20, 1.0], // yellow
    [0.86, 0.20, 0.15, 1.0], // hot red
  ]);

  List<double> colorAt(double t) {
    final clamped = t.clamp(0.0, 1.0).toDouble();
    if (stops.length == 1) return _rgba(stops.first);
    final scaled = clamped * (stops.length - 1);
    final index = scaled.floor().clamp(0, stops.length - 2).toInt();
    final localT = scaled - index;
    final a = _rgba(stops[index]);
    final b = _rgba(stops[index + 1]);
    return [
      for (var c = 0; c < 4; c++) a[c] + (b[c] - a[c]) * localT,
    ];
  }

  static List<double> _rgba(List<double> c) => [c[0], c[1], c[2], c.length > 3 ? c[3] : 1.0];
}
