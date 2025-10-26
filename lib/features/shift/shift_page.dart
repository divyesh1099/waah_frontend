import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:waah_frontend/app/providers.dart';
import 'package:waah_frontend/data/models.dart';

// --- branches list used by picker ---
final branchesProvider =
FutureProvider.autoDispose<List<BranchInfo>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authControllerProvider);

  final tenantId = auth.me?.tenantId ?? '';
  if (tenantId.isEmpty) return <BranchInfo>[];

  return api.fetchBranches(tenantId: tenantId);
});

// --- current shift for the active branch ---
final shiftStatusProvider =
FutureProvider.autoDispose<ShiftStatus?>((ref) async {
  final api = ref.watch(apiClientProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  if (branchId.isEmpty) return null;
  return api.fetchCurrentShift(branchId: branchId);
});

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncShift = ref.watch(shiftStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift & Cash'),
      ),
      body: asyncShift.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Failed to load shift: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (shift) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShiftHeaderCard(
                  shift: shift,
                  onRefresh: () {
                    ref.invalidate(shiftStatusProvider);
                  },
                ),
                const SizedBox(height: 24),
                _MovementsSection(
                  shift: shift,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Top card with actions: select branch, open, cash in/out, close
class _ShiftHeaderCard extends ConsumerWidget {
  final ShiftStatus? shift;
  final VoidCallback onRefresh;
  const _ShiftHeaderCard({
    required this.shift,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBranchId = ref.watch(activeBranchIdProvider);
    final hasBranch = activeBranchId.isNotEmpty;

    final isOpen = shift?.isOpenAndUnlocked == true;
    final openingFloat = shift?.openingFloat ?? 0.0;
    final expectedNow = shift?.expectedNow ?? 0.0;

    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
          Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isOpen ? 'Shift OPEN' : 'No active shift',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),

            // Subtext: branch + numbers
            if (isOpen) ...[
              Text(
                'Branch: $activeBranchId',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Opening cash: ₹${openingFloat.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Expected now: ₹${expectedNow.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              if (shift?.openedAt != null)
                Text(
                  'Opened at: ${shift!.openedAt}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
            ] else ...[
              Text(
                hasBranch
                    ? 'Branch: $activeBranchId'
                    : 'No branch selected',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasBranch
                    ? 'Tap "Open Day" to start a shift.'
                    : 'Select a branch first.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // row of buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // pick / change branch
                OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => const _BranchPickerDialog(),
                    );
                    if (changed == true) {
                      onRefresh();
                    }
                  },
                  icon: const Icon(Icons.store_mall_directory),
                  label: Text(
                    hasBranch ? 'Change Branch' : 'Select Branch',
                  ),
                ),

                FilledButton.icon(
                  onPressed: (!isOpen && hasBranch)
                      ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => _OpenShiftDialog(
                        branchId: activeBranchId,
                      ),
                    );
                    if (ok == true) {
                      onRefresh();
                    }
                  }
                      : null,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Open Day'),
                ),

                OutlinedButton.icon(
                  onPressed: isOpen
                      ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => _CashMoveDialog(
                        shiftId: shift!.id,
                        isPayin: true,
                      ),
                    );
                    if (ok == true) onRefresh();
                  }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Cash In'),
                ),

                OutlinedButton.icon(
                  onPressed: isOpen
                      ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => _CashMoveDialog(
                        shiftId: shift!.id,
                        isPayin: false,
                      ),
                    );
                    if (ok == true) onRefresh();
                  }
                      : null,
                  icon: const Icon(Icons.remove),
                  label: const Text('Cash Out'),
                ),

                FilledButton.icon(
                  onPressed: isOpen
                      ? () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => _CloseShiftDialog(
                        shiftId: shift!.id,
                        expectedNow: expectedNow,
                      ),
                    );
                    if (ok == true) onRefresh();
                  }
                      : null,
                  icon: const Icon(Icons.lock),
                  label: const Text('Close Day'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// List of payins/payouts
class _MovementsSection extends StatelessWidget {
  final ShiftStatus? shift;
  const _MovementsSection({required this.shift});

  @override
  Widget build(BuildContext context) {
    if (shift == null || !shift!.isOpenAndUnlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cash Movements',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'No active shift.\nNothing to show.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final moves = shift!.movements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cash Movements',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (moves.isEmpty)
          Text(
            'No cash in/out yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          Column(
            children: moves.map((m) {
              final isOut = m.kind == 'PAYOUT';
              final color = isOut
                  ? Colors.red.shade700
                  : Colors.green.shade700;
              final sign = isOut ? '−' : '+';
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Text(
                    sign,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '₹${m.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((m.reason ?? '').isNotEmpty)
                      Text(
                        m.reason!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (m.ts != null)
                      Text(
                        m.ts.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Dialog: Open Day / Opening Float
class _OpenShiftDialog extends ConsumerStatefulWidget {
  final String branchId;
  const _OpenShiftDialog({required this.branchId});

  @override
  ConsumerState<_OpenShiftDialog> createState() =>
      _OpenShiftDialogState();
}

class _OpenShiftDialogState
    extends ConsumerState<_OpenShiftDialog> {
  final _openingCtl = TextEditingController(text: '0.00');
  bool _busy = false;

  @override
  void dispose() {
    _openingCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final openingFloat =
        double.tryParse(_openingCtl.text.trim()) ?? 0.0;
    setState(() => _busy = true);

    try {
      await ref.read(apiClientProvider).openShift(
        branchId: widget.branchId,
        openingFloat: openingFloat,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open shift: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open Day'),
      content: TextField(
        controller: _openingCtl,
        keyboardType:
        const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Opening cash (₹)',
          helperText: 'Cash in drawer at start of day',
        ),
      ),
      actions: [
        TextButton(
          onPressed:
          _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Start'),
        ),
      ],
    );
  }
}

/// Dialog: Cash In / Cash Out
class _CashMoveDialog extends ConsumerStatefulWidget {
  final String shiftId;
  final bool isPayin;
  const _CashMoveDialog({
    required this.shiftId,
    required this.isPayin,
  });

  @override
  ConsumerState<_CashMoveDialog> createState() =>
      _CashMoveDialogState();
}

class _CashMoveDialogState
    extends ConsumerState<_CashMoveDialog> {
  final _amountCtl = TextEditingController();
  final _reasonCtl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _reasonCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amountCtl.text.trim()) ?? 0.0;
    final reason = _reasonCtl.text.trim().isEmpty
        ? null
        : _reasonCtl.text.trim();

    setState(() => _busy = true);
    try {
      if (widget.isPayin) {
        await ref.read(apiClientProvider).cashIn(
          shiftId: widget.shiftId,
          amount: amt,
          reason: reason,
        );
      } else {
        await ref.read(apiClientProvider).cashOut(
          shiftId: widget.shiftId,
          amount: amt,
          reason: reason,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isPayin ? 'Cash In' : 'Cash Out';
    final label = widget.isPayin ? 'PAYIN' : 'PAYOUT';
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountCtl,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              helperText: label,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtl,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              helperText: 'eg. petty cash / float top-up',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
          _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Dialog: Close Day
class _CloseShiftDialog extends ConsumerStatefulWidget {
  final String shiftId;
  final double expectedNow;
  const _CloseShiftDialog({
    required this.shiftId,
    required this.expectedNow,
  });

  @override
  ConsumerState<_CloseShiftDialog> createState() =>
      _CloseShiftDialogState();
}

class _CloseShiftDialogState
    extends ConsumerState<_CloseShiftDialog> {
  late TextEditingController _expectedCtl;
  final _actualCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expectedCtl = TextEditingController(
      text: widget.expectedNow.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _expectedCtl.dispose();
    _actualCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final expectedCash =
        double.tryParse(_expectedCtl.text.trim()) ?? 0.0;
    final actualCash =
        double.tryParse(_actualCtl.text.trim()) ?? 0.0;
    final note = _noteCtl.text.trim().isEmpty
        ? null
        : _noteCtl.text.trim();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(apiClientProvider).closeShift(
        shiftId: widget.shiftId,
        expectedCash: expectedCash,
        actualCash: actualCash,
        note: note,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Close Day'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _expectedCtl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Expected cash (₹)',
                helperText:
                'System calc (opening + in - out). Manager override allowed.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actualCtl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Actual cash counted (₹)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                helperText:
                'Explain difference if mismatch. Required for audit.',
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
          _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Close Day'),
        ),
      ],
    );
  }
}

// BranchPickerDialog defined earlier
class _BranchPickerDialog extends ConsumerWidget {
  const _BranchPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBranches = ref.watch(branchesProvider);

    return AlertDialog(
      title: const Text('Select Branch'),
      content: asyncBranches.when(
        loading: () => const SizedBox(
          height: 64,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, st) => Text(
          'Failed to load branches: $e',
          style: const TextStyle(color: Colors.red),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const Text(
              'No branches found.\nCreate a branch in onboarding/settings.',
            );
          }

          final activeId = ref.watch(activeBranchIdProvider);

          return SizedBox(
            width: 300,
            height: 200,
            child: ListView.separated(
              itemCount: branches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final b = branches[i];
                final selected = b.id == activeId;
                return ListTile(
                  title: Text(b.name),
                  subtitle: Text(
                    [
                      if ((b.phone ?? '').isNotEmpty) b.phone!,
                      if ((b.address ?? '').isNotEmpty) b.address!,
                    ].join(" · "),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    ref.read(activeBranchIdProvider.notifier).state =
                        b.id;
                    Navigator.pop(context, true);
                  },
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
