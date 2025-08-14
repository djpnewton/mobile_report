import 'package:flutter/material.dart';

/// Shows a single metric color-coded like a traffic light:
/// - Green when the value increased
/// - Orange when the value stayed the same (within [epsilon])
/// - Red when the value decreased
class TrafficLightMetric extends StatelessWidget {
  const TrafficLightMetric({
    super.key,
    required this.current,
    required this.previous,
    this.label,
    this.format,
    this.epsilon = 0.0,
    this.showArrow = true,
    this.compact = false,
    this.upColor = Colors.green,
    this.sameColor = Colors.orange,
    this.downColor = Colors.red,
    this.valueStyle,
    this.labelStyle,
    this.previousStyle,
    this.previousTimestamp,
    this.showPrevious = true,
    this.iconSize = 20,
    this.spacing = 8,
  });

  final num current;
  final num previous;
  final String? label;
  final String Function(num value)? format;
  final double epsilon;
  final bool showArrow;
  final bool compact;
  final Color upColor;
  final Color sameColor;
  final Color downColor;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;
  final TextStyle? previousStyle;
  final DateTime? previousTimestamp;
  final bool showPrevious;
  final double iconSize;
  final double spacing;

  static Trend computeTrend({
    required num current,
    required num previous,
    double epsilon = 0.0,
  }) {
    final diff = current - previous;
    if (diff > epsilon) return Trend.up;
    if (diff < -epsilon) return Trend.down;
    return Trend.same;
  }

  @override
  Widget build(BuildContext context) {
    final trend = computeTrend(
      current: current,
      previous: previous,
      epsilon: epsilon,
    );
    final color = switch (trend) {
      Trend.up => upColor,
      Trend.same => sameColor,
      Trend.down => downColor,
    };
    final icon = switch (trend) {
      Trend.up => Icons.arrow_upward,
      Trend.same => Icons.remove,
      Trend.down => Icons.arrow_downward,
    };
    final valueText = format?.call(current) ?? current.toString();
    final prevText = format?.call(previous) ?? previous.toString();

    final valueTextStyle =
        (valueStyle ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
          color: color,
        );
    final labelTextStyle =
        labelStyle ?? Theme.of(context).textTheme.labelMedium;
    final prevTextStyle =
        previousStyle ?? Theme.of(context).textTheme.bodySmall;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showArrow) Icon(icon, color: color, size: iconSize),
            if (showArrow) SizedBox(width: spacing),
            Text(valueText, style: valueTextStyle),
          ],
        ),
        if (showPrevious) SizedBox(height: spacing / 2),
        if (showPrevious)
          Text(
            previousTimestamp != null
                ? 'Prev: $prevText • ${_timeAgo(previousTimestamp!)}'
                : 'Prev: $prevText',
            style: (prevTextStyle ?? const TextStyle()).copyWith(
              color: Colors.grey,
            ),
          ),
      ],
    );

    if (compact) return content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) Text(label!, style: labelTextStyle),
        if (label != null) SizedBox(height: spacing / 2),
        content,
      ],
    );
  }
}

enum Trend { up, same, down }

String _pluralize(int count, String unit) =>
    count == 1 ? '$count $unit ago' : '$count ${unit}s ago';

String _timeAgo(DateTime ts) {
  final now = DateTime.now();
  Duration diff = now.difference(ts);
  if (diff.inSeconds < 30) return 'just now';
  if (diff.inMinutes < 1) return _pluralize(diff.inSeconds, 'second');
  if (diff.inHours < 1) return _pluralize(diff.inMinutes, 'minute');
  if (diff.inDays < 1) return _pluralize(diff.inHours, 'hour');
  if (diff.inDays < 30) return _pluralize(diff.inDays, 'day');
  final months = (diff.inDays / 30).floor();
  if (months < 12) return _pluralize(months, 'month');
  final years = (months / 12).floor();
  return _pluralize(years, 'year');
}
