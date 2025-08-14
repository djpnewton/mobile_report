import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/metric_source.dart';
import 'services/price_service.dart';
import 'widgets/traffic_light_metric.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Report',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Mobile Report'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MetricSource _source = MetricSource.bitcoin;
  double? _currentPrice;
  double? _previousPrice;
  DateTime? _previousTimestamp;
  double _epsilon = 0.0;
  bool _loading = false;
  String? _error;
  final PriceService _service = PriceService();

  static const _prefsKeySource = 'selected_source';
  static const _prefsKeyEpsilon = 'epsilon_value';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPrefs();
    await _loadCached();
    await _refreshPrice(initial: true);
  }

  Future<void> _loadCached() async {
    final cache = await _service.getCachedPrice(_source);
    if (!mounted) return;
    if (cache != null) {
      setState(() {
        _previousPrice = cache.value;
        _currentPrice = cache.value;
        _previousTimestamp = cache.timestamp;
      });
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefsKeySource);
    if (name != null) {
      final match = MetricSource.values.where((e) => e.name == name);
      if (match.isNotEmpty) {
        _source = match.first;
      }
    }
    _epsilon = prefs.getDouble(_prefsKeyEpsilon) ?? 0.0;
    if (mounted) setState(() {});
  }

  Future<void> _saveSource() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeySource, _source.name);
  }

  Future<void> _saveEpsilon() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKeyEpsilon, _epsilon);
  }

  Future<void> _refreshPrice({bool initial = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      // previous values will be updated from history after fetch
    });
    try {
      final price = await _service.fetchPrice(_source);
      // After saving to cache inside service, read history to set previous/current precisely
      final history = await _service.getHistory(_source);
      if (!mounted) return;
      setState(() {
        if (history.isEmpty) {
          _previousPrice = price;
          _currentPrice = price;
          _previousTimestamp = DateTime.now();
        } else if (history.length == 1) {
          _previousPrice = history.last.value;
          _currentPrice = history.last.value;
          _previousTimestamp = history.last.timestamp;
        } else {
          final prev = history[history.length - 2];
          final curr = history[history.length - 1];
          _previousPrice = prev.value;
          _currentPrice = curr.value;
          _previousTimestamp = prev.timestamp;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch ${_source.label.toLowerCase()}: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatPrice(num v) {
    // Basic USD formatting without intl
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Mobile Report',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Menu', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final selected = await Navigator.of(context)
                      .push<SettingsResult>(
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(
                            initialSource: _source,
                            initialEpsilon: _epsilon,
                          ),
                        ),
                      );
                  if (selected != null && mounted) {
                    setState(() {
                      _source = selected.source;
                      _epsilon = selected.epsilon;
                    });
                    await _saveSource();
                    await _saveEpsilon();
                    await _loadCached();
                    await _refreshPrice(initial: true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error: $_error'),
              )
            : (_currentPrice == null && _loading)
            ? const CircularProgressIndicator()
            : FittedBox(
                fit: BoxFit.contain,
                child: TrafficLightMetric(
                  label: _source.label,
                  previous: (_previousPrice ?? _currentPrice ?? 0),
                  current: (_currentPrice ?? _previousPrice ?? 0),
                  previousTimestamp: _previousTimestamp,
                  epsilon: _epsilon,
                  spacing: 16,
                  iconSize: 96,
                  valueStyle: Theme.of(context).textTheme.displayLarge,
                  labelStyle: Theme.of(context).textTheme.titleLarge,
                  format: (v) => _formatPrice(v),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : () => _refreshPrice(),
        tooltip: 'Refresh',
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.refresh),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
