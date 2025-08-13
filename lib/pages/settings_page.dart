import 'package:flutter/material.dart';
import 'package:mobile_report/models/metric_source.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialSource, this.initialEpsilon});

  final MetricSource? initialSource;
  final double? initialEpsilon;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late MetricSource _source;
  late double _epsilon;
  late final TextEditingController _epsController;

  @override
  void initState() {
    super.initState();
    _source = widget.initialSource ?? MetricSource.bitcoin;
    _epsilon = widget.initialEpsilon ?? 0.0;
    _epsController = TextEditingController(text: _epsilon.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _epsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(SettingsResult(source: _source, epsilon: _epsilon));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ListTile(
              leading: Icon(Icons.tune),
              title: Text('Preferences'),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Metric Source', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            RadioListTile<MetricSource>(
              title: Text(MetricSource.bitcoin.label),
              value: MetricSource.bitcoin,
              groupValue: _source,
              onChanged: (v) => setState(() => _source = v!),
            ),
            RadioListTile<MetricSource>(
              title: Text(MetricSource.gold.label),
              value: MetricSource.gold,
              groupValue: _source,
              onChanged: (v) => setState(() => _source = v!),
            ),
            RadioListTile<MetricSource>(
              title: Text(MetricSource.oil.label),
              value: MetricSource.oil,
              groupValue: _source,
              onChanged: (v) => setState(() => _source = v!),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Epsilon (treat small changes as "same")', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _epsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                    decoration: const InputDecoration(
                      labelText: 'Epsilon',
                      helperText: 'Enter a non-negative number',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final v = double.tryParse(text.replaceAll(',', '.'));
                      setState(() => _epsilon = (v == null || v.isNaN || v < 0) ? 0.0 : v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(_epsilon.toStringAsFixed(2)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsResult {
  final MetricSource source;
  final double epsilon;
  const SettingsResult({required this.source, required this.epsilon});
}
