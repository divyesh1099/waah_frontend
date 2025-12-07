// For exporting
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:waah_frontend/app/providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _startDt;
  late DateTime _endDt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDt = _startOfDay(now.subtract(const Duration(days: 6)));
    _endDt = _endOfDay(now);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  DateTime _endOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDt, end: _endDt),
    );
    if (picked != null) {
      setState(() {
        _startDt = _startOfDay(picked.start);
        _endDt = _endOfDay(picked.end);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon...')),
              );
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
      future: api.getSalesReport(
        startDt: start,
        endDt: end,
        tenantId: tenantId,
        branchId: branchId,
      ),
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

        double totalGross = 0;
        double totalTax = 0;
        double totalNet = 0;
        int totalOrders = 0;
        for (var r in data) {
          totalGross += double.tryParse(r['gross'].toString()) ?? 0;
          totalTax += double.tryParse(r['tax'].toString()) ?? 0;
          totalNet += double.tryParse(r['net'].toString()) ?? 0;
          totalOrders += int.tryParse(r['orders_count'].toString()) ?? 0;
        }

        final sorted = [...data]
          ..sort((a, b) => a['label'].toString().compareTo(b['label'].toString()));
        final chartData =
            sorted.length > 12 ? sorted.sublist(sorted.length - 12) : sorted;

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _StatCol(label: 'Total Net', value: totalNet, isBold: true),
                    _StatCol(label: 'Gross', value: totalGross),
                    _StatCol(label: 'Tax', value: totalTax),
                    _StatCol(label: 'Orders', value: totalOrders.toDouble()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _SalesBarChart(rows: chartData),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = data[index];
                  final net = double.tryParse(row['net'].toString()) ?? 0;
                  return ListTile(
                    title: Text(row['label'] ?? ''),
                    subtitle: Text('${row['orders_count']} Orders'),
                    trailing: Text(
                      'Rs ${net.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
  const _StatCol({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          'Rs ${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _SalesBarChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final nets = rows
        .map((r) => double.tryParse(r['net'].toString()) ?? 0)
        .toList();
    final maxY = nets.fold<double>(0, (max, v) => v > max ? v : max);

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < rows.length; i++) {
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: nets[i],
              width: 16,
              gradient: const LinearGradient(colors: [Colors.indigo, Colors.blue]),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          showingTooltipIndicators: const [0],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15 + 1,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final label = rows[group.x.toInt()]['label'] ?? '';
                return BarTooltipItem(
                  '$label\nRs ${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          gridData: FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text('Rs ${value.toInt()}'),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= rows.length) {
                    return const SizedBox.shrink();
                  }
                  final label = rows[idx]['label']?.toString() ?? '';
                  final trimmed = label.length > 6 ? label.substring(label.length - 6) : label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(trimmed, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: bars,
        ),
      ),
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
      future: api.getItemSalesReport(
        startDt: start,
        endDt: end,
        tenantId: tenantId,
        branchId: branchId,
        limit: 50,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(child: Text('No item sales found.'));
        }

        final top = data.isNotEmpty ? data.first : null;

        return Column(
          children: [
            if (top != null)
              Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(top['name'] ?? 'Top item'),
                  subtitle: Text(
                    'Qty ${top['qty']} | Variant: ${top['variant'] ?? '-'}',
                  ),
                  trailing: Text(
                    'Rs ${(double.tryParse(top['revenue'].toString()) ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
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
                        DataCell(Text('Rs ${row['revenue']}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
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
      future: api.getCategorySalesReport(
        startDt: start,
        endDt: end,
        tenantId: tenantId,
        branchId: branchId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(child: Text('No data found.'));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _CategoryPie(data: data),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final row = data[index];
                  final rev = double.tryParse(row['revenue'].toString()) ?? 0;
                  return ListTile(
                    leading: CircleAvatar(child: Text(row['category'].toString().substring(0, 1))),
                    title: Text(row['category']),
                    trailing: Text(
                      'Rs ${rev.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Qty: ${row['qty']}'),
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

class _CategoryPie extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _CategoryPie({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = data.fold<double>(0, (sum, row) => sum + (double.tryParse(row['revenue'].toString()) ?? 0));
    final slices = data.length > 6 ? data.sublist(0, 6) : data;
    final colors = [
      Colors.indigo,
      Colors.blue,
      Colors.teal,
      Colors.green,
      Colors.amber,
      Colors.pinkAccent,
      Colors.deepPurple,
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category share', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        color: colors[i % colors.length],
                        value: double.tryParse(slices[i]['revenue'].toString()) ?? 0,
                        title: total > 0
                            ? '${(((double.tryParse(slices[i]['revenue'].toString()) ?? 0) / total) * 100).toStringAsFixed(0)}%'
                            : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        radius: 60,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < slices.length; i++)
                  _LegendDot(
                    color: colors[i % colors.length],
                    label: slices[i]['category'] ?? '',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
