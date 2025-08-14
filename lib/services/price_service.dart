import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mobile_report/models/metric_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PriceService {
  final http.Client _client;
  PriceService({http.Client? client}) : _client = client ?? http.Client();
  static const int _maxHistoryLength = 500; // prevent unbounded growth

  Future<double> fetchPrice(MetricSource source) async {
    double value;
    switch (source) {
      case MetricSource.bitcoin:
        value = await _fetchBtcUsd();
        break;
      case MetricSource.gold:
        value = await _fetchGoldUsd();
        break;
      case MetricSource.oil:
        value = await _fetchOilUsd();
        break;
    }
    await _saveToCache(source, value);
    return value;
  }

  Future<double> _fetchBtcUsd() async {
    final uri = Uri.parse('https://api.coinbase.com/v2/prices/BTC-USD/spot');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('BTC fetch failed ${res.statusCode}');
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    final rate = (data['data']?['amount']) as String?;
    if (rate == null) throw Exception('BTC price missing');
    return double.parse(rate);
  }

  Future<double> _fetchGoldUsd() async {
    // Yahoo Finance Gold Futures (COMEX): GC=F, USD per troy ounce
    return _fetchMacrodashServerQuote('GC=F');
  }

  Future<double> _fetchOilUsd() async {
    // Yahoo Finance Crude Oil WTI Futures (NYMEX): CL=F, USD per barrel
    // Alternative (Brent): BZ=F
    return _fetchMacrodashServerQuote('CL=F');
  }

  Future<double> _fetchMacrodashServerQuote(String symbol) async {
    final uri = Uri.parse(
      'https://macrodash-server.fly.dev/market/custom?ticker1=$symbol&interval=oneMinute&range=oneDay',
    );
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Macrodash fetch failed ${res.statusCode} for $symbol');
    }
    final Map<String, dynamic> data =
        json.decode(res.body) as Map<String, dynamic>;
    final result = data['priceData'].last['amount'];
    if (result is num) return result.toDouble();
    throw Exception('Macrodash price missing for $symbol');
  }

  Future<void> _saveToCache(MetricSource source, double value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = source.name;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final newSample = {'value': value, 'ts': nowMs};

    final s = prefs.getString(key);
    List<dynamic> list;
    if (s == null) {
      list = [newSample];
    } else {
      try {
        final decoded = json.decode(s);
        if (decoded is List) {
          list = List<dynamic>.from(decoded);
          list.add(newSample);
        } else if (decoded is Map<String, dynamic>) {
          // Legacy single-object cache: migrate to list
          list = [decoded, newSample];
        } else {
          list = [newSample];
        }
      } catch (_) {
        list = [newSample];
      }
    }

    // Enforce max length (keep the most recent entries at the end)
    if (list.length > _maxHistoryLength) {
      list = list.sublist(list.length - _maxHistoryLength);
    }
    await prefs.setString(key, json.encode(list));
  }

  Future<PriceCache?> getCachedPrice(MetricSource source) async {
    final history = await getHistory(source);
    if (history.isEmpty) return null;
    return history.last;
  }

  Future<List<PriceCache>> getHistory(MetricSource source) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(source.name);
    if (s == null) return [];
    try {
      final decoded = json.decode(s);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) {
              final num? v = m['value'] as num?;
              final int? ts = m['ts'] is int
                  ? m['ts'] as int
                  : int.tryParse('${m['ts']}');
              if (v == null || ts == null) return null;
              return PriceCache(
                v.toDouble(),
                DateTime.fromMillisecondsSinceEpoch(ts),
              );
            })
            .whereType<PriceCache>()
            .toList(growable: false);
      } else if (decoded is Map<String, dynamic>) {
        // Legacy single-object cache -> wrap as one-sample list
        final num? v = decoded['value'] as num?;
        final int? ts = decoded['ts'] is int
            ? decoded['ts'] as int
            : int.tryParse('${decoded['ts']}');
        if (v == null || ts == null) return [];
        return [
          PriceCache(v.toDouble(), DateTime.fromMillisecondsSinceEpoch(ts)),
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

class PriceCache {
  final double value;
  final DateTime timestamp;
  const PriceCache(this.value, this.timestamp);
}
