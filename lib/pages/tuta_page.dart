import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/metric_source.dart';
import '../services/price_service.dart';

class TutaPage extends StatefulWidget {
  const TutaPage({super.key, required this.source});

  final MetricSource source;

  @override
  State<TutaPage> createState() => _TutaPageState();
}

class _TutaPageState extends State<TutaPage> {
  final PriceService _service = PriceService();
  List<PriceCache> _history = const [];
  List<PriceCache> _tuta = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _service.getHistory(widget.source);
      final tuta = _computeTuta(history);
      if (!mounted) return;
      setState(() {
        _history = history;
        _tuta = tuta;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PriceCache> _computeTuta(List<PriceCache> series) {
    if (series.length < 3) return const [];
    final List<PriceCache> out = [];
    for (int i = 2; i < series.length; i++) {
      final a = series[i - 2].value;
      final b = series[i - 1].value;
      final c = series[i].value;
      final avg = (a + b + c) / 3.0;
      // Timestamp aligned to current sample in the window
      out.add(PriceCache(avg, series[i].timestamp));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    Color colorRaw = Colors.grey.shade300;
    Color colorTuta = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text('TUTA • ${widget.source.label}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _tuta.isEmpty
          ? const Center(
              child: Text(
                'Not enough data to compute TUTA (need at least 3 samples).',
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _LineChart(
                        colorRaw: colorRaw,
                        colorTuta: colorTuta,
                        raw: _history,
                        tuta: _tuta,
                        showAxes: true,
                        xLabel: 'Time',
                        yLabel: 'Price',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.show_chart, size: 24, color: colorRaw),
                      const SizedBox(width: 4),
                      const Text('Raw'),
                      const SizedBox(width: 16),
                      Icon(Icons.show_chart, size: 24, color: colorTuta),
                      const SizedBox(width: 4),
                      const Text('TUTA (3-sample avg)'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Samples: ${_history.length}  •  TUTA points: ${_tuta.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.colorRaw,
    required this.colorTuta,
    required this.raw,
    required this.tuta,
    this.showAxes = true,
    this.xLabel,
    this.yLabel,
  });

  final Color colorRaw;
  final Color colorTuta;
  final List<PriceCache> raw;
  final List<PriceCache> tuta;
  final bool showAxes;
  final String? xLabel;
  final String? yLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _LineChartPainter(
            raw: raw,
            tuta: tuta,
            showAxes: showAxes,
            colorTuta: colorTuta,
            colorRaw: colorRaw,
            xLabel: xLabel,
            yLabel: yLabel,
            textStyle:
                Theme.of(context).textTheme.labelSmall ??
                const TextStyle(fontSize: 10),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.raw,
    required this.tuta,
    required this.showAxes,
    required this.colorTuta,
    required this.colorRaw,
    this.xLabel,
    this.yLabel,
    required this.textStyle,
  });

  final List<PriceCache> raw;
  final List<PriceCache> tuta;
  final bool showAxes;
  final Color colorTuta;
  final Color colorRaw;
  final String? xLabel;
  final String? yLabel;
  final TextStyle textStyle;

  static const double padLeft = 40.0;
  static const double padRight = 16.0;
  static const double padTop = 16.0;
  static const double padBottom = 40.0; // extra room for x labels

  @override
  void paint(Canvas canvas, Size size) {
    if (tuta.isEmpty && raw.isEmpty) return;

    final chartRect = Rect.fromLTWH(
      padLeft,
      padTop,
      size.width - padLeft - padRight,
      size.height - padTop - padBottom,
    );

    final allValues = <double>[];
    final allTimes = <int>[];
    allValues.addAll(raw.map((e) => e.value));
    allValues.addAll(tuta.map((e) => e.value));
    allTimes.addAll(raw.map((e) => e.timestamp.millisecondsSinceEpoch));
    allTimes.addAll(tuta.map((e) => e.timestamp.millisecondsSinceEpoch));
    if (allValues.isEmpty || allTimes.isEmpty) return;
    final minV = allValues.reduce((a, b) => a < b ? a : b);
    final maxV = allValues.reduce((a, b) => a > b ? a : b);
    final minT = allTimes.reduce((a, b) => a < b ? a : b);
    final maxT = allTimes.reduce((a, b) => a > b ? a : b);

    double mapX(int t) {
      if (maxT == minT) return chartRect.left + chartRect.width / 2;
      final norm = (t - minT) / (maxT - minT);
      return chartRect.left + norm * chartRect.width;
    }

    double mapY(double v) {
      if (maxV == minV) return chartRect.top + chartRect.height / 2;
      final norm = (v - minV) / (maxV - minV);
      // Y increases downward, so invert
      return chartRect.bottom - norm * chartRect.height;
    }

    // Axes
    if (showAxes) {
      final axisPaint = Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1;
      // X axis
      canvas.drawLine(
        Offset(chartRect.left, chartRect.bottom),
        Offset(chartRect.right, chartRect.bottom),
        axisPaint,
      );
      // Y axis
      canvas.drawLine(
        Offset(chartRect.left, chartRect.top),
        Offset(chartRect.left, chartRect.bottom),
        axisPaint,
      );

      // Axis labels
      final tpX = TextPainter(
        text: TextSpan(
          text: xLabel ?? 'Time',
          style: textStyle.copyWith(color: Colors.grey.shade700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpX.paint(
        canvas,
        Offset(chartRect.center.dx - tpX.width / 2, chartRect.bottom + 16),
      );

      final tpY = TextPainter(
        text: TextSpan(
          text: yLabel ?? 'Price',
          style: textStyle.copyWith(color: Colors.grey.shade700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(8, chartRect.center.dy + tpY.width / 2);
      canvas.rotate(-math.pi / 2);
      tpY.paint(canvas, Offset.zero);
      canvas.restore();

      // Grid paint (faint)
      final gridPaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 0.5;

      // X-axis ticks with date labels and vertical grid lines
      const int xTicks = 5;
      for (int i = 0; i <= xTicks; i++) {
        final t = minT + ((maxT - minT) * i / xTicks).round();
        final x = mapX(t);
        // Vertical grid line
        canvas.drawLine(
          Offset(x, chartRect.top),
          Offset(x, chartRect.bottom),
          gridPaint,
        );
        // Tick mark
        canvas.drawLine(
          Offset(x, chartRect.bottom),
          Offset(x, chartRect.bottom + 4),
          axisPaint,
        );
        // Label
        final label = _formatTickLabel(t, maxT - minT);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: textStyle.copyWith(color: Colors.grey.shade700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        double lx = x - tp.width / 2;
        // Clamp within chart bounds
        lx = lx.clamp(chartRect.left, chartRect.right - tp.width);
        tp.paint(canvas, Offset(lx, chartRect.bottom + 6));
      }

      // Y-axis ticks with labels and horizontal grid lines
      const int yTicks = 5;
      for (int i = 0; i <= yTicks; i++) {
        final v = minV + (maxV - minV) * i / yTicks;
        final y = mapY(v);
        // Horizontal grid line
        canvas.drawLine(
          Offset(chartRect.left, y),
          Offset(chartRect.right, y),
          gridPaint,
        );
        // Tick mark
        canvas.drawLine(
          Offset(chartRect.left - 4, y),
          Offset(chartRect.left, y),
          axisPaint,
        );
        // Label
        final label = _formatYLabel(v, maxV - minV);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: textStyle.copyWith(color: Colors.grey.shade700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lx = chartRect.left - 6 - tp.width;
        tp.paint(canvas, Offset(lx, y - tp.height / 2));
      }
    }

    // Helper to draw a series
    void drawSeries(List<PriceCache> series, Color color) {
      if (series.isEmpty) return;
      final path = Path();
      for (int i = 0; i < series.length; i++) {
        final p = Offset(
          mapX(series[i].timestamp.millisecondsSinceEpoch),
          mapY(series[i].value),
        );
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, linePaint);
      final pointPaint = Paint()
        ..color = color.withAlpha(180)
        ..style = PaintingStyle.fill;
      for (final e in series) {
        final p = Offset(
          mapX(e.timestamp.millisecondsSinceEpoch),
          mapY(e.value),
        );
        canvas.drawCircle(p, 2.2, pointPaint);
      }
    }

    // Draw raw first, then TUTA on top
    drawSeries(raw, colorRaw);
    drawSeries(tuta, colorTuta);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    return old.raw != raw ||
        old.tuta != tuta ||
        old.colorTuta != colorTuta ||
        old.colorRaw != colorRaw ||
        old.showAxes != showAxes ||
        old.xLabel != xLabel ||
        old.yLabel != yLabel ||
        old.textStyle != textStyle;
  }

  String _two(int n) => n < 10 ? '0$n' : '$n';
  String _formatTickLabel(int ms, int rangeMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (rangeMs <= 12 * 60 * 60 * 1000) {
      return '${_two(dt.hour)}:${_two(dt.minute)}';
    } else if (rangeMs <= 7 * 24 * 60 * 60 * 1000) {
      return '${dt.month}/${dt.day} ${_two(dt.hour)}:${_two(dt.minute)}';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }

  String _formatYLabel(double v, double range) {
    int decimals;
    if (range < 1) {
      decimals = 3;
    } else if (range < 10) {
      decimals = 2;
    } else if (range < 100) {
      decimals = 1;
    } else {
      decimals = 0;
    }
    return v.toStringAsFixed(decimals);
  }
}
