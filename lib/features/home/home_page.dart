import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waah_frontend/app/providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rs = ref.watch(restaurantSettingsProvider).valueOrNull;
    final brand = (rs != null && rs.name.isNotEmpty) ? rs.name : 'Restaurant';
    return Center(
      child: Text('Welcome to $brand — Windows & Android ready.'),
    );
  }
}
