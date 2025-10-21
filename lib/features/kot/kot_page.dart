import 'package:flutter/material.dart';

class KotPage extends StatelessWidget {
  const KotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: const [
          Expanded(child: _KotColumn(title: 'New')),
          VerticalDivider(width: 1),
          Expanded(child: _KotColumn(title: 'In Progress')),
          VerticalDivider(width: 1),
          Expanded(child: _KotColumn(title: 'Ready')),
        ],
      ),
    );
  }
}

class _KotColumn extends StatelessWidget {
  final String title;
  const _KotColumn({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Expanded(child: Center(child: Text('No tickets yet'))),
      ],
    );
  }
}
