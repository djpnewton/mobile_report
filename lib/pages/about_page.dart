import 'package:flutter/material.dart';

import '../config.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GIT SHA: $gitSha', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Build Date: $buildDate', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
