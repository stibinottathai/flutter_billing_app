import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/core/widgets/app_back_button.dart';
import 'package:billing_app/features/billing/data/models/transaction_model.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProductAnalysisPage extends StatefulWidget {
  const ProductAnalysisPage({super.key});

  @override
  State<ProductAnalysisPage> createState() => _ProductAnalysisPageState();
}

enum _RangeFilter { today, week, month, year, custom }

class _ProductAnalysisPageState extends State<ProductAnalysisPage> {
  _RangeFilter _selectedFilter = _RangeFilter.month;
  DateTimeRange? _customRange;

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isWithinInclusive(DateTime date, DateTime start, DateTime end) {
    final target = _dateOnly(date);
    final from = _dateOnly(start);
    final to = _dateOnly(end);
    return !target.isBefore(from) && !target.isAfter(to);
  }

  Future<void> _onFilterSelected(_RangeFilter filter) async {
    if (filter != _RangeFilter.custom) {
      setState(() {
        _selectedFilter = filter;
      });
      return;
    }

    final now = DateTime.now();
    final defaultRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _customRange ?? defaultRange,
      helpText: 'Select Custom Date Range',
      saveText: 'Apply',
    );

    if (!mounted || picked == null) return;

    setState(() {
      _customRange = picked;
      _selectedFilter = _RangeFilter.custom;
    });
  }

  String _customRangeLabel() {
    if (_customRange == null) return 'Custom Date';
    final from = _customRange!.start;
    final to = _customRange!.end;
    return '${from.day.toString().padLeft(2, '0')}/${from.month.toString().padLeft(2, '0')}/${from.year} - ${to.day.toString().padLeft(2, '0')}/${to.month.toString().padLeft(2, '0')}/${to.year}';
  }

  bool _matchesFilter(DateTime date) {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case _RangeFilter.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _RangeFilter.week:
        final startOfDay = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
        return _isWithinInclusive(date, startOfWeek, startOfDay);
      case _RangeFilter.month:
        return date.year == now.year && date.month == now.month;
      case _RangeFilter.year:
        return date.year == now.year;
      case _RangeFilter.custom:
        final range = _customRange;
        if (range == null) return false;
        return _isWithinInclusive(date, range.start, range.end);
    }
  }

  String _filterLabel(_RangeFilter filter) {
    switch (filter) {
      case _RangeFilter.today:
        return 'Today';
      case _RangeFilter.week:
        return 'This Week';
      case _RangeFilter.month:
        return 'This Month';
      case _RangeFilter.year:
        return 'This Year';
      case _RangeFilter.custom:
        return 'Custom Date';
    }
  }

  String _selectedFilterTitle() {
    if (_selectedFilter == _RangeFilter.custom) {
      return _customRange == null ? 'Custom Date' : 'Custom Range';
    }
    return _filterLabel(_selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(
          'Product Analysis',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: AppBackButton(onPressed: () => context.pop(), leftPadding: 16),
      ),
      body: ValueListenableBuilder<Box<ProductModel>>(
        valueListenable: HiveDatabase.productBox.listenable(),
        builder: (context, productBox, _) {
          return ValueListenableBuilder<Box<TransactionModel>>(
            valueListenable: HiveDatabase.transactionBox.listenable(),
            builder: (context, txBox, __) {
              final allProducts = productBox.values.toList();
              final filteredTx = txBox.values
                  .where((t) => t.items.isNotEmpty && _matchesFilter(t.date))
                  .toList();

              final summary = _buildSummary(allProducts, filteredTx);
              if (summary.totalTransactions == 0) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insights_rounded,
                            size: 44, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        const Text(
                          'No product sales in selected period',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try another filter to view analysis.',
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(
                    isCompact ? 14 : 20, 8, isCompact ? 14 : 20, 24),
                children: [
                  _buildFilterRow(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInsightCard(
                          title: _selectedFilterTitle(),
                          value: 'Rs ${summary.totalRevenue.toStringAsFixed(0)}',
                          subtitle: 'Product sales',
                          color: const Color(0xFF2563EB),
                          icon: Icons.payments_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Products Sold',
                          value: '${summary.productsSoldCount}',
                          subtitle: '${summary.unsoldProductsCount} unsold',
                          color: const Color(0xFF10B981),
                          icon: Icons.inventory_2_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Quantity Sold',
                          value: _qty(summary.totalQuantitySold),
                          subtitle: 'Across sold products',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.bar_chart_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInsightCard(
                          title: 'Bills Count',
                          value: '${summary.totalTransactions}',
                          subtitle: 'Transactions with items',
                          color: const Color(0xFF8B5CF6),
                          icon: Icons.receipt_long_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTopBottomSection(summary),
                  const SizedBox(height: 16),
                  _buildSoldProductSection(
                    title: 'Top Sold Products',
                    products: summary.topSold,
                    accent: const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 14),
                  _buildSoldProductSection(
                    title: 'Low Sold Products',
                    products: summary.lowSold,
                    accent: const Color(0xFFF59E0B),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _qty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  Widget _buildFilterRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _RangeFilter.values.map((filter) {
            final isSelected = filter == _selectedFilter;
            return ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: isSelected,
              onSelected: (_) => _onFilterSelected(filter),
              selectedColor: const Color(0xFFE0E7FF),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFE2E8F0),
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF334155),
              ),
            );
          }).toList(),
        ),
        if (_selectedFilter == _RangeFilter.custom && _customRange != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _onFilterSelected(_RangeFilter.custom),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.date_range_rounded,
                      size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 6),
                  Text(
                    _customRangeLabel(),
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                fontSize: 12,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF0F172A),
              )),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  Widget _buildSoldProductSection({
    required String title,
    required List<_ProductStat> products,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Text(
              'No sold products found.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final product = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$index',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Qty ${_qty(product.quantity)}  •  ${product.transactions} tx',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs ${product.revenue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopBottomSection(_ProductSummary summary) {
    final top = summary.mostSold;
    final bottom = summary.leastSold;

    return Row(
      children: [
        Expanded(
            child:
                _rankCard('Most Sold Product', top, const Color(0xFF10B981))),
        const SizedBox(width: 10),
        Expanded(
            child:
                _rankCard('Least Sold Product', bottom, const Color(0xFFF59E0B))),
      ],
    );
  }

  Widget _rankCard(String title, _ProductStat? stat, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
                fontSize: 12,
              )),
          const SizedBox(height: 8),
          Text(
            stat?.name ?? 'No sales',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stat == null
                ? 'Qty: 0'
                : 'Qty: ${_qty(stat.quantity)} | Rs ${stat.revenue.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  _ProductSummary _buildSummary(
    List<ProductModel> products,
    List<TransactionModel> transactions,
  ) {
    final nameById = <String, String>{
      for (final p in products) p.id: p.name,
    };

    final map = <String, _ProductStat>{};

    for (final tx in transactions) {
      for (final item in tx.items) {
        final id = item.productId;
        final resolvedName = nameById[id] ?? item.productName;
        final existing = map[id];
        if (existing == null) {
          map[id] = _ProductStat(
            id: id,
            name: resolvedName,
            quantity: item.quantity,
            revenue: item.total,
            transactions: 1,
          );
        } else {
          map[id] = existing.copyWith(
            quantity: existing.quantity + item.quantity,
            revenue: existing.revenue + item.total,
            transactions: existing.transactions + 1,
          );
        }
      }
    }

    final stats = map.values.toList();
    stats.sort((a, b) => b.quantity.compareTo(a.quantity));

    final totalRevenue = stats.fold<double>(0, (sum, s) => sum + s.revenue);
    final totalQty = stats.fold<double>(0, (sum, s) => sum + s.quantity);

    final mostSold = stats.isEmpty ? null : stats.first;
    final leastSold = stats.isEmpty
        ? null
        : stats.reduce((a, b) => a.quantity <= b.quantity ? a : b);

    final topSold = List<_ProductStat>.from(stats)
      ..sort((a, b) {
        final qtyCompare = b.quantity.compareTo(a.quantity);
        if (qtyCompare != 0) return qtyCompare;
        return b.revenue.compareTo(a.revenue);
      });

    final lowSold = List<_ProductStat>.from(stats)
      ..sort((a, b) {
        final qtyCompare = a.quantity.compareTo(b.quantity);
        if (qtyCompare != 0) return qtyCompare;
        return a.revenue.compareTo(b.revenue);
      });

    return _ProductSummary(
      totalRevenue: totalRevenue,
      totalQuantitySold: totalQty,
      totalTransactions: transactions.length,
      productsSoldCount: stats.length,
      unsoldProductsCount:
          (products.length - stats.length).clamp(0, products.length),
      mostSold: mostSold,
      leastSold: leastSold,
      topSold: topSold.take(5).toList(),
      lowSold: lowSold.take(5).toList(),
    );
  }
}

class _ProductSummary {
  final double totalRevenue;
  final double totalQuantitySold;
  final int totalTransactions;
  final int productsSoldCount;
  final int unsoldProductsCount;
  final _ProductStat? mostSold;
  final _ProductStat? leastSold;
  final List<_ProductStat> topSold;
  final List<_ProductStat> lowSold;

  const _ProductSummary({
    required this.totalRevenue,
    required this.totalQuantitySold,
    required this.totalTransactions,
    required this.productsSoldCount,
    required this.unsoldProductsCount,
    required this.mostSold,
    required this.leastSold,
    required this.topSold,
    required this.lowSold,
  });
}

class _ProductStat {
  final String id;
  final String name;
  final double quantity;
  final double revenue;
  final int transactions;

  const _ProductStat({
    required this.id,
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.transactions,
  });

  _ProductStat copyWith({
    String? id,
    String? name,
    double? quantity,
    double? revenue,
    int? transactions,
  }) {
    return _ProductStat(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      revenue: revenue ?? this.revenue,
      transactions: transactions ?? this.transactions,
    );
  }
}
