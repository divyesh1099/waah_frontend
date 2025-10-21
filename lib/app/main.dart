import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';
import '../app/providers.dart';
import '../data/local/db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openDb();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const WaahApp(),
    ),
  );
}

class WaahApp extends ConsumerWidget {
  const WaahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'WAAH POS',
      theme: buildTheme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
