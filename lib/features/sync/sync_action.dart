import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_controller.dart';

class SyncOnlineAction extends ConsumerWidget {
  const SyncOnlineAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncing = ref.watch(
      syncControllerProvider.select((s) => s.syncing),
    );

    return IconButton(
      tooltip: 'Sync Online',
      onPressed: syncing
          ? null
          : () async {
        await ref.read(syncControllerProvider.notifier).syncNow();
        final st = ref.read(syncControllerProvider);
        if (st.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${st.error}')),
          );
        } else if (st.lastMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(st.lastMessage!)),
          );
        }
      },
      icon: syncing
          ? const SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.sync),
    );
  }
}
