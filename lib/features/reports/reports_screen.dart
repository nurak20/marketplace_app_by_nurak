import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/load_error_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/management_data_grid.dart';
import '../../core/components/management_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';

const _chartColors = <Color>[
  StyleColor.teal,
  StyleColor.accent,
  StyleColor.success,
  Color(0xFF7A5AF8),
  Color(0xFF2E90FA),
];

String _number(num value) {
  final text = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  final dot = text.indexOf('.');
  final whole = dot < 0 ? text : text.substring(0, dot);
  final buffer = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) buffer.write(',');
    buffer.write(whole[index]);
  }
  return dot < 0 ? '$buffer' : '$buffer${text.substring(dot)}';
}

String _money(num value) => 'USD ${_number(value)}';

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  bool _loaded = false;
  Object? _error;

  ReportOverview? _overview;
  List<ProductStatusReport> _statuses = [];
  List<CategoryReport> _categories = [];
  List<MonthlyActivityReport> _activity = [];
  List<EngagementReport> _engagement = [];
  List<TopSellerReport> _sellers = [];
  List<PayrollDepartmentReport> _departments = [];
  List<PayrollRunReport> _runs = [];
  List<HeadcountReport> _headcount = [];

  Account? get _account => Singleton.instance.account;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await api.reportOverview();
      final statuses = await api.reportProductStatus();
      final categories = await api.reportCategories();
      final activity = await api.reportMonthlyActivity();
      final engagement = await api.reportEngagement();
      final sellers = await api.reportTopSellers();
      final departments = await api.reportPayrollDepartments();
      final runs = await api.reportPayrollRuns();
      final headcount = await api.reportHeadcount();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _statuses = statuses;
        _categories = categories;
        _activity = activity;
        _engagement = engagement;
        _sellers = sellers;
        _departments = departments;
        _runs = runs;
        _headcount = headcount;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'report.title'.tr(),
        showNotifications: false,
        showManagement: false,
        showProfileAvatar: false,
        actions: [
          IconButton(
            tooltip: 'common.refresh'.tr(),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ).build(context),
      body: _account?.canViewReports != true
          ? EmptyState(
              title: 'report.accessRequired'.tr(),
              message: 'report.accessMessage'.tr(),
              icon: Icons.lock_outline_rounded,
            )
          : Material(color: StyleColor.canvas, child: _body()),
    ),
  );

  Widget _body() {
    if (!_loaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_loaded && _error != null) {
      return LoadErrorPanel(error: _error!, onRetry: _load);
    }
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: StyleColor.teal,
              unselectedLabelColor: StyleColor.muted,
              indicatorColor: StyleColor.teal,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'report.tab.overview'.tr()),
                Tab(text: 'report.tab.marketplace'.tr()),
                Tab(text: 'report.tab.community'.tr()),
                Tab(text: 'report.tab.payroll'.tr()),
              ],
            ),
          ),
          const Divider(height: 1, color: StyleColor.line),
          Expanded(
            child: TabBarView(
              children: [
                _overviewTab(),
                _marketplaceTab(),
                _communityTab(),
                _payrollTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabScroll(List<Widget> children) => RefreshIndicator(
    onRefresh: _load,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );

  Widget _kpiPanel() {
    final overview = _overview;
    if (overview == null) return const SizedBox.shrink();
    return ManagementPanel(
      title: 'report.overviewTitle'.tr(),
      icon: Icons.dashboard_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _KpiTile(
            label: 'report.kpi.totalUsers'.tr(),
            value: _number(overview.totalUsers),
            icon: Icons.people_alt_outlined,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.activeUsers'.tr(),
            value: _number(overview.activeUsers),
            icon: Icons.how_to_reg_outlined,
            color: StyleColor.success,
          ),
          _KpiTile(
            label: 'report.kpi.sellers'.tr(),
            value: _number(overview.sellers),
            icon: Icons.storefront_outlined,
            color: StyleColor.accent,
          ),
          _KpiTile(
            label: 'report.kpi.listings'.tr(),
            value: _number(overview.products),
            icon: Icons.inventory_2_outlined,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.available'.tr(),
            value: _number(overview.availableProducts),
            icon: Icons.check_circle_outline_rounded,
            color: StyleColor.success,
          ),
          _KpiTile(
            label: 'report.kpi.sold'.tr(),
            value: _number(overview.soldProducts),
            icon: Icons.sell_outlined,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.posts'.tr(),
            value: _number(overview.posts),
            icon: Icons.article_outlined,
            color: StyleColor.accent,
          ),
          _KpiTile(
            label: 'report.kpi.comments'.tr(),
            value: _number(overview.comments),
            icon: Icons.chat_bubble_outline_rounded,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.reactions'.tr(),
            value: _number(overview.reactions),
            icon: Icons.favorite_border_rounded,
            color: const Color(0xFFE84393),
          ),
          _KpiTile(
            label: 'report.kpi.wishlists'.tr(),
            value: _number(overview.wishlists),
            icon: Icons.bookmark_border_rounded,
            color: const Color(0xFF7A5AF8),
          ),
          _KpiTile(
            label: 'report.kpi.employees'.tr(),
            value: _number(overview.employees),
            icon: Icons.badge_outlined,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.activeStaff'.tr(),
            value: _number(overview.activeEmployees),
            icon: Icons.work_outline_rounded,
            color: StyleColor.success,
          ),
          _KpiTile(
            label: 'report.kpi.paidGross'.tr(),
            value: _money(overview.paidGross),
            icon: Icons.account_balance_wallet_outlined,
            color: StyleColor.accent,
          ),
          _KpiTile(
            label: 'report.kpi.paidNet'.tr(),
            value: _money(overview.paidNet),
            icon: Icons.payments_outlined,
            color: StyleColor.teal,
          ),
          _KpiTile(
            label: 'report.kpi.availableValue'.tr(),
            value: _money(overview.availableValue),
            icon: Icons.price_check_rounded,
            color: StyleColor.success,
          ),
        ],
      ),
    );
  }

  Widget _overviewTab() => _tabScroll([
    _kpiPanel(),
    _chartPanel(
      'report.monthlyActivity'.tr(),
      Icons.show_chart_rounded,
      _activityChart(),
    ),
    _tablePanel(
      'report.activityDetails'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'month',
            label: 'report.column.month'.tr(),
            width: 96,
          ),
          ManagementGridColumn(
            name: 'users',
            label: 'report.column.users'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'products',
            label: 'report.column.listings'.tr(),
            width: 96,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'posts',
            label: 'report.column.posts'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'comments',
            label: 'report.column.comments'.tr(),
            width: 110,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reactions',
            label: 'report.column.reactions'.tr(),
            width: 110,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _activity)
            [
              item.month,
              _number(item.users),
              _number(item.products),
              _number(item.posts),
              _number(item.comments),
              _number(item.reactions),
            ],
        ],
      ),
    ),
  ]);

  Widget _marketplaceTab() => _tabScroll([
    _chartPanel(
      'report.listingsByStatus'.tr(),
      Icons.donut_large_outlined,
      _statusChart(),
    ),
    _tablePanel(
      'report.statusBreakdown'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'status',
            label: 'report.column.status'.tr(),
            width: 130,
          ),
          ManagementGridColumn(
            name: 'products',
            label: 'report.column.listings'.tr(),
            width: 100,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'value',
            label: 'report.column.catalogValue'.tr(),
            width: 150,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _statuses)
            [
              _titleCase(item.status),
              _number(item.products),
              _money(item.value),
            ],
        ],
      ),
    ),
    _chartPanel(
      'report.listingsByCategory'.tr(),
      Icons.category_outlined,
      _categoryChart(),
    ),
    _tablePanel(
      'report.categoryPerformance'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'category',
            label: 'report.column.category'.tr(),
            width: 150,
          ),
          ManagementGridColumn(
            name: 'products',
            label: 'report.column.listings'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'available',
            label: 'report.column.available'.tr(),
            width: 100,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'sold',
            label: 'report.column.sold'.tr(),
            width: 80,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reserved',
            label: 'report.column.reserved'.tr(),
            width: 96,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'value',
            label: 'report.column.value'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _categories)
            [
              item.category,
              _number(item.products),
              _number(item.available),
              _number(item.sold),
              _number(item.reserved),
              _money(item.value),
            ],
        ],
      ),
    ),
    _chartPanel(
      'report.topSellers'.tr(),
      Icons.emoji_events_outlined,
      _sellerChart(),
    ),
    _tablePanel(
      'report.sellerLeaderboard'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'seller',
            label: 'report.column.seller'.tr(),
            width: 160,
          ),
          ManagementGridColumn(
            name: 'listings',
            label: 'report.column.listings'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'sold',
            label: 'report.column.sold'.tr(),
            width: 80,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'revenue',
            label: 'report.column.revenue'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reactions',
            label: 'report.column.reactions'.tr(),
            width: 100,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'comments',
            label: 'report.column.comments'.tr(),
            width: 100,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _sellers)
            [
              item.name,
              _number(item.listings),
              _number(item.sold),
              _money(item.revenue),
              _number(item.reactions),
              _number(item.comments),
            ],
        ],
      ),
    ),
  ]);

  Widget _communityTab() => _tabScroll([
    _chartPanel(
      'report.contentPerMonth'.tr(),
      Icons.show_chart_rounded,
      _activityChart(),
    ),
    _tablePanel(
      'report.contentActivity'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'month',
            label: 'report.column.month'.tr(),
            width: 96,
          ),
          ManagementGridColumn(
            name: 'users',
            label: 'report.column.users'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'products',
            label: 'report.column.listings'.tr(),
            width: 96,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'posts',
            label: 'report.column.posts'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'comments',
            label: 'report.column.comments'.tr(),
            width: 110,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reactions',
            label: 'report.column.reactions'.tr(),
            width: 110,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _activity)
            [
              item.month,
              _number(item.users),
              _number(item.products),
              _number(item.posts),
              _number(item.comments),
              _number(item.reactions),
            ],
        ],
      ),
    ),
    _chartPanel(
      'report.engagementSignals'.tr(),
      Icons.insights_rounded,
      _engagementChart(),
    ),
    _tablePanel(
      'report.engagementDetails'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'month',
            label: 'report.column.month'.tr(),
            width: 96,
          ),
          ManagementGridColumn(
            name: 'messages',
            label: 'report.column.messages'.tr(),
            width: 104,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'comments',
            label: 'report.column.comments'.tr(),
            width: 104,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reactions',
            label: 'report.column.reactions'.tr(),
            width: 104,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'wishlists',
            label: 'report.column.wishlists'.tr(),
            width: 104,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'reviews',
            label: 'report.column.reviews'.tr(),
            width: 96,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _engagement)
            [
              item.month,
              _number(item.messages),
              _number(item.comments),
              _number(item.reactions),
              _number(item.wishlists),
              _number(item.reviews),
            ],
        ],
      ),
    ),
  ]);

  Widget _payrollTab() => _tabScroll([
    _chartPanel(
      'report.payrollByDepartment'.tr(),
      Icons.account_balance_wallet_outlined,
      _departmentChart(),
    ),
    _tablePanel(
      'report.departmentPayroll'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'period',
            label: 'report.column.period'.tr(),
            width: 120,
          ),
          ManagementGridColumn(
            name: 'department',
            label: 'report.column.department'.tr(),
            width: 150,
          ),
          ManagementGridColumn(
            name: 'employees',
            label: 'report.column.staff'.tr(),
            width: 80,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'gross',
            label: 'report.column.gross'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'deductions',
            label: 'report.column.deductions'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'net',
            label: 'report.column.net'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _departments)
            [
              item.periodLabel,
              item.department,
              _number(item.employees),
              _money(item.gross),
              _money(item.deductions),
              _money(item.net),
            ],
        ],
      ),
    ),
    _chartPanel(
      'report.payrollRunTotals'.tr(),
      Icons.bar_chart_rounded,
      _runChart(),
    ),
    _tablePanel(
      'report.payrollRuns'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'period',
            label: 'report.column.period'.tr(),
            width: 120,
          ),
          ManagementGridColumn(
            name: 'status',
            label: 'report.column.status'.tr(),
            width: 100,
          ),
          ManagementGridColumn(
            name: 'employees',
            label: 'report.column.staff'.tr(),
            width: 80,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'gross',
            label: 'report.column.gross'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'deductions',
            label: 'report.column.deductions'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'net',
            label: 'report.column.net'.tr(),
            width: 130,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _runs)
            [
              item.periodLabel,
              _titleCase(item.status),
              _number(item.employees),
              _money(item.gross),
              _money(item.deductions),
              _money(item.net),
            ],
        ],
      ),
    ),
    _chartPanel(
      'report.headcountByDepartment'.tr(),
      Icons.groups_outlined,
      _headcountChart(),
    ),
    _tablePanel(
      'report.headcountDetails'.tr(),
      Icons.table_chart_outlined,
      ManagementDataGrid(
        columns: [
          ManagementGridColumn(
            name: 'department',
            label: 'report.column.department'.tr(),
            width: 160,
          ),
          ManagementGridColumn(
            name: 'active',
            label: 'report.column.active'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'onLeave',
            label: 'report.column.onLeave'.tr(),
            width: 96,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'terminated',
            label: 'report.column.terminated'.tr(),
            width: 110,
            alignment: Alignment.centerRight,
          ),
          ManagementGridColumn(
            name: 'total',
            label: 'report.column.total'.tr(),
            width: 90,
            alignment: Alignment.centerRight,
          ),
        ],
        rows: [
          for (final item in _headcount)
            [
              item.department,
              _number(item.active),
              _number(item.onLeave),
              _number(item.terminated),
              _number(item.total),
            ],
        ],
      ),
    ),
  ]);

  Widget _chartPanel(String title, IconData icon, Widget chart) =>
      ManagementPanel(
        title: title,
        icon: icon,
        child: SizedBox(height: 300, child: chart),
      );

  Widget _tablePanel(String title, IconData icon, Widget table) =>
      ManagementPanel(title: title, icon: icon, child: table);

  Widget _emptyChart(String message) => EmptyState(
    title: 'report.empty.title'.tr(),
    message: message,
    icon: Icons.query_stats_outlined,
  );

  CategoryAxis _categoryAxis({int rotation = -30}) => CategoryAxis(
    majorGridLines: const MajorGridLines(width: 0),
    labelRotation: rotation,
    labelStyle: const TextStyle(fontSize: 10, color: StyleColor.muted),
  );

  NumericAxis _numericAxis() => NumericAxis(
    minimum: 0,
    majorGridLines: const MajorGridLines(width: .5, color: StyleColor.line),
    labelStyle: const TextStyle(fontSize: 10, color: StyleColor.muted),
  );

  Legend _legend() => const Legend(
    isVisible: true,
    position: LegendPosition.bottom,
    textStyle: TextStyle(fontSize: 11, color: StyleColor.muted),
  );

  Widget _activityChart() {
    if (_activity.isEmpty) {
      return _emptyChart('report.empty.activity'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      legend: _legend(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<MonthlyActivityReport, String>>[
        LineSeries<MonthlyActivityReport, String>(
          name: 'report.series.users'.tr(),
          dataSource: _activity,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.users,
          color: _chartColors[0],
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 5,
            width: 5,
          ),
        ),
        LineSeries<MonthlyActivityReport, String>(
          name: 'report.series.listings'.tr(),
          dataSource: _activity,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.products,
          color: _chartColors[1],
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 5,
            width: 5,
          ),
        ),
        LineSeries<MonthlyActivityReport, String>(
          name: 'report.series.posts'.tr(),
          dataSource: _activity,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.posts,
          color: _chartColors[2],
          width: 2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 5,
            width: 5,
          ),
        ),
        LineSeries<MonthlyActivityReport, String>(
          name: 'report.series.comments'.tr(),
          dataSource: _activity,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.comments,
          color: _chartColors[3],
          width: 2,
          dashArray: const [6, 3],
        ),
        LineSeries<MonthlyActivityReport, String>(
          name: 'report.series.reactions'.tr(),
          dataSource: _activity,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.reactions,
          color: _chartColors[4],
          width: 2,
          dashArray: const [6, 3],
        ),
      ],
    );
  }

  Widget _engagementChart() {
    if (_engagement.isEmpty) {
      return _emptyChart('report.empty.engagement'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      legend: _legend(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<EngagementReport, String>>[
        LineSeries<EngagementReport, String>(
          name: 'report.series.messages'.tr(),
          dataSource: _engagement,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.messages,
          color: _chartColors[0],
          width: 2,
        ),
        LineSeries<EngagementReport, String>(
          name: 'report.series.comments'.tr(),
          dataSource: _engagement,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.comments,
          color: _chartColors[1],
          width: 2,
        ),
        LineSeries<EngagementReport, String>(
          name: 'report.series.reactions'.tr(),
          dataSource: _engagement,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.reactions,
          color: _chartColors[2],
          width: 2,
        ),
        LineSeries<EngagementReport, String>(
          name: 'report.series.wishlists'.tr(),
          dataSource: _engagement,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.wishlists,
          color: _chartColors[3],
          width: 2,
          dashArray: const [6, 3],
        ),
        LineSeries<EngagementReport, String>(
          name: 'report.series.reviews'.tr(),
          dataSource: _engagement,
          xValueMapper: (item, _) => item.month,
          yValueMapper: (item, _) => item.reviews,
          color: _chartColors[4],
          width: 2,
          dashArray: const [6, 3],
        ),
      ],
    );
  }

  Widget _statusChart() {
    if (_statuses.isEmpty) {
      return _emptyChart('report.empty.status'.tr());
    }
    return SfCircularChart(
      legend: _legend(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CircularSeries<ProductStatusReport, String>>[
        DoughnutSeries<ProductStatusReport, String>(
          dataSource: _statuses,
          xValueMapper: (item, _) => _titleCase(item.status),
          yValueMapper: (item, _) => item.products,
          pointColorMapper: (item, _) => switch (item.status) {
            'AVAILABLE' => StyleColor.success,
            'SOLD' => StyleColor.teal,
            'RESERVED' => StyleColor.accent,
            _ => StyleColor.muted,
          },
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
          ),
          innerRadius: '55%',
        ),
      ],
    );
  }

  Widget _categoryChart() {
    if (_categories.isEmpty) {
      return _emptyChart('report.empty.category'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<CategoryReport, String>>[
        ColumnSeries<CategoryReport, String>(
          name: 'report.series.listings'.tr(),
          dataSource: _categories,
          xValueMapper: (item, _) => item.category,
          yValueMapper: (item, _) => item.products,
          pointColorMapper: (item, _) => StyleColor.teal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _sellerChart() {
    if (_sellers.isEmpty) {
      return _emptyChart('report.empty.seller'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<TopSellerReport, String>>[
        ColumnSeries<TopSellerReport, String>(
          name: 'report.series.revenue'.tr(),
          dataSource: _sellers,
          xValueMapper: (item, _) => item.name,
          yValueMapper: (item, _) => item.revenue,
          pointColorMapper: (item, _) => StyleColor.accent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _departmentChart() {
    if (_departments.isEmpty) {
      return _emptyChart('report.empty.department'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<PayrollDepartmentReport, String>>[
        ColumnSeries<PayrollDepartmentReport, String>(
          name: 'report.series.netPay'.tr(),
          dataSource: _departments,
          xValueMapper: (item, _) => item.department,
          yValueMapper: (item, _) => item.net,
          pointColorMapper: (item, _) => StyleColor.teal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _runChart() {
    if (_runs.isEmpty) {
      return _emptyChart('report.empty.runs'.tr());
    }
    final runs = _runs.reversed.toList(growable: false);
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      legend: _legend(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<PayrollRunReport, String>>[
        ColumnSeries<PayrollRunReport, String>(
          name: 'report.series.gross'.tr(),
          dataSource: runs,
          xValueMapper: (item, _) => item.periodLabel,
          yValueMapper: (item, _) => item.gross,
          color: StyleColor.softMint,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        ColumnSeries<PayrollRunReport, String>(
          name: 'report.series.net'.tr(),
          dataSource: runs,
          xValueMapper: (item, _) => item.periodLabel,
          yValueMapper: (item, _) => item.net,
          color: StyleColor.teal,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _headcountChart() {
    if (_headcount.isEmpty) {
      return _emptyChart('report.empty.headcount'.tr());
    }
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: _categoryAxis(),
      primaryYAxis: _numericAxis(),
      legend: _legend(),
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<HeadcountReport, String>>[
        StackedColumnSeries<HeadcountReport, String>(
          name: 'report.series.active'.tr(),
          dataSource: _headcount,
          xValueMapper: (item, _) => item.department,
          yValueMapper: (item, _) => item.active,
          color: StyleColor.success,
        ),
        StackedColumnSeries<HeadcountReport, String>(
          name: 'report.series.onLeave'.tr(),
          dataSource: _headcount,
          xValueMapper: (item, _) => item.department,
          yValueMapper: (item, _) => item.onLeave,
          color: StyleColor.accent,
        ),
        StackedColumnSeries<HeadcountReport, String>(
          name: 'report.series.terminated'.tr(),
          dataSource: _headcount,
          xValueMapper: (item, _) => item.department,
          yValueMapper: (item, _) => item.terminated,
          color: StyleColor.muted,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 168,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: StyleColor.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StyleColor.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StyleColor.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
