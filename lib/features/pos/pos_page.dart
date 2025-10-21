import 'package:flutter/material.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _side('Tables / Channels'),
        const VerticalDivider(width: 1),
        Expanded(child: _centerMenu()),
        const VerticalDivider(width: 1),
        _side('Cart / KOT / Pay'),
      ],
    );
  }

  Widget _side(String title) => SizedBox(
    width: 260,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      const Expanded(child: Center(child: Text('TODO'))),
    ]),
  );

  Widget _centerMenu() => Column(children: const [
    SizedBox(height: 8),
    Expanded(child: Center(child: Text('Menu grid goes here'))),
  ]);
}
