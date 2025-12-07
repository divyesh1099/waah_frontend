
import 'package:file_picker/file_picker.dart'; // For exporting
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:waah_frontend/app/providers.dart';
// import 'package:share_plus/share_plus.dart'; // Optional for mobile share

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDt = DateTime.now();  // Today's start
  DateTime _endDt = DateTime.now();    // Today's end

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDt, end: _endDt),
    );
    if (picked != null) {
      setState(() {
        _startDt = picked.start;
        _endDt = picked.end;
      });
    }
  }
  
  String _dateLabel() {
    final f = DateFormat('MMM dd');
    return '${f.format(_startDt)} - ${f.format(_endDt)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_dateLabel()),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () {
              // TODO: Export current tab data
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export coming soon...')));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Items'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SalesTab(start: _startDt, end: _endDt),
          _ItemsTab(start: _startDt, end: _endDt),
          _CategoriesTab(start: _startDt, end: _endDt),
        ],
      ),
    );
  }
}

// --- TABS ---

class _SalesTab extends ConsumerWidget {
  final DateTime start;
  final DateTime end;
  const _SalesTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.getSalesReport(startDt: start, endDt: end, tenantId: tenantId, branchId: branchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(child: Text('No sales data for this period.'));
        }
        
        // Calculate Totals
        double totalGross = 0;
        double totalTax = 0;
        double totalNet = 0;
        for (var r in data) {
           totalGross += double.tryParse(r['gross'].toString()) ?? 0;
           totalTax += double.tryParse(r['tax'].toString()) ?? 0;
           totalNet += double.tryParse(r['net'].toString()) ?? 0;
        }

        return Column(
          children: [
            // Summary Card
            Card(
              margin: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatCol(label: 'Total Net', value: totalNet, isBold: true),
                    _StatCol(label: 'Gross', value: totalGross),
                    _StatCol(label: 'Tax', value: totalTax),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = data[index];
                  return ListTile(
                    title: Text(row['label'] ?? ''),
                    subtitle: Text('${row['orders_count']} Orders'),
                    trailing: Text('₹ ${row['net']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  const _StatCol({required this.label, required this.value, this.isBold=false});

  @override
  Widget build(BuildContext context) {
    return Column(
       children: [
         Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
         const SizedBox(height: 4),
         Text('₹ ${value.toStringAsFixed(2)}', style: TextStyle(
             fontSize: 18, 
             fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
             color: Colors.black87
         )),
       ]
    );
  }
}

class _ItemsTab extends ConsumerWidget {
  final DateTime start;
  final DateTime end;
  const _ItemsTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.getItemSalesReport(startDt: start, endDt: end, tenantId: tenantId, branchId: branchId, limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final data = snapshot.data ?? [];
        if (data.isEmpty) return const Center(child: Text('No item sales found.'));

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Variant')),
                DataColumn(label: Text('Qty', textAlign: TextAlign.right), numeric: true),
                DataColumn(label: Text('Revenue', textAlign: TextAlign.right), numeric: true),
              ],
              rows: data.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['name'] ?? '')),
                  DataCell(Text(row['variant'] ?? '-')),
                  DataCell(Text(row['qty'].toString())),
                  DataCell(Text('₹ ${row['revenue']}')),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  final DateTime start;
  final DateTime end;
  const _CategoriesTab({required this.start, required this.end});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final tenantId = ref.read(activeTenantIdProvider);
    final branchId = ref.read(activeBranchIdProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: api.getCategorySalesReport(startDt: start, endDt: end, tenantId: tenantId, branchId: branchId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final data = snapshot.data ?? [];
        if (data.isEmpty) return const Center(child: Text('No data found.'));

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) {
            final row = data[index];
            final rev = double.tryParse(row['revenue'].toString()) ?? 0;
            return ListTile(
              leading: CircleAvatar(child: Text(row['category'].toString().substring(0, 1))),
              title: Text(row['category']),
              trailing: Text('₹ ${rev.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Qty: ${row['qty']}'),
            );
          },
        );
      },
    );
  }
}
