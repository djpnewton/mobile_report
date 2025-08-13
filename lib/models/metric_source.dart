enum MetricSource {
  bitcoin,
  gold,
  oil,
}

extension MetricSourceX on MetricSource {
  String get label => switch (this) {
        MetricSource.bitcoin => 'Bitcoin Price',
        MetricSource.gold => 'Gold Price',
        MetricSource.oil => 'Oil Price',
      };
}
