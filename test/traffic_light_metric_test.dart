import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_report/widgets/traffic_light_metric.dart';

void main() {
  group('TrafficLightMetric.computeTrend', () {
    test('returns up when current > previous beyond epsilon', () {
      expect(TrafficLightMetric.computeTrend(current: 10, previous: 9), Trend.up);
      expect(TrafficLightMetric.computeTrend(current: 10, previous: 9.9, epsilon: 0.05), Trend.up);
    });

    test('returns down when current < previous beyond epsilon', () {
      expect(TrafficLightMetric.computeTrend(current: 8, previous: 9), Trend.down);
      expect(TrafficLightMetric.computeTrend(current: 9.8, previous: 10, epsilon: 0.05), Trend.down);
    });

    test('returns same when within epsilon', () {
      expect(TrafficLightMetric.computeTrend(current: 10, previous: 10), Trend.same);
      expect(TrafficLightMetric.computeTrend(current: 10.02, previous: 10, epsilon: 0.05), Trend.same);
      expect(TrafficLightMetric.computeTrend(current: 9.98, previous: 10, epsilon: 0.05), Trend.same);
    });
  });
}
