import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/detail_row.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/load_error_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/management_data_grid.dart';
import '../../core/components/management_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/show_error.dart';
import '../../core/components/status_chip.dart';
import '../../core/models.dart';
import 'payroll_utils.dart';
import 'payroll_widgets.dart';

class MyPayslipsScreen extends StatefulWidget {
  const MyPayslipsScreen({super.key});

  @override
  State<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends State<MyPayslipsScreen> {
  EmployeeProfile? _profile;
  bool _loadingProfile = true;
  bool _notEnrolled = false;
  Object? _profileError;

  List<Payslip> _payslips = [];
  bool _loadingPayslips = true;
  Object? _payslipsError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPayslips();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await api.myPayrollProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _notEnrolled = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _notEnrolled = error.response?.statusCode == 404;
        _profileError = _notEnrolled ? null : error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = error);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadPayslips() async {
    setState(() {
      _loadingPayslips = true;
      _payslipsError = null;
    });
    try {
      final page = await api.myPayslips();
      if (!mounted) return;
      setState(() => _payslips = page.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _payslipsError = error);
    } finally {
      if (mounted) setState(() => _loadingPayslips = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), _loadPayslips()]);
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'profile.myPayslips'.tr(),
        showNotifications: false,
        showManagement: false,
        showProfileAvatar: false,
      ).build(context),
      body: Material(
        color: StyleColor.canvas,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final panels = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 380, child: _profilePanel()),
                      Expanded(child: _payslipsPanel(wide: true)),
                    ],
                  )
                : Column(
                    children: [_profilePanel(), _payslipsPanel(wide: false)],
                  );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: panels,
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _profilePanel() => ManagementPanel(
    title: 'payslips.employment'.tr(),
    icon: Icons.badge_outlined,
    child: _profileContent(),
  );

  Widget _profileContent() {
    if (_loadingProfile && _profile == null && !_notEnrolled) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_profileError != null) {
      return LoadErrorPanel(error: _profileError!, onRetry: _loadProfile);
    }
    if (_notEnrolled) {
      return EmptyState(
        title: 'payslips.notEnrolled'.tr(),
        message: 'payslips.notEnrolledMessage'.tr(),
        icon: Icons.person_off_outlined,
      );
    }

    final profile = _profile;
    if (profile == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: StyleFont.largeSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: employmentStatusLabel(profile.status),
              color: employmentStatusColor(profile.status),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 20,
              runSpacing: 14,
              children: [
                PayrollMetricTile(
                  label: 'payroll.column.baseSalary'.tr(),
                  value: payrollMoney(profile.baseSalary, profile.currency),
                ),
                PayrollMetricTile(
                  label: 'payroll.column.allowance'.tr(),
                  value: payrollMoney(profile.allowance, profile.currency),
                ),
                PayrollMetricTile(
                  label: 'payroll.column.monthlyPackage'.tr(),
                  value: payrollMoney(profile.monthlyPackage, profile.currency),
                  color: StyleColor.teal,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        DetailRow(
          label: 'payroll.field.employeeCode'.tr(),
          value: profile.employeeLabel,
        ),
        DetailRow(
          label: 'payroll.field.jobTitle'.tr(),
          value: _textOrDash(profile.jobTitle),
        ),
        DetailRow(
          label: 'payroll.field.department'.tr(),
          value: _textOrDash(profile.department),
        ),
        DetailRow(
          label: 'payroll.field.hireDate'.tr(),
          value: payrollDateLabel(profile.hireDate),
        ),
        DetailRow(
          label: 'payslips.bank'.tr(),
          value: _textOrDash(profile.bankName),
        ),
        DetailRow(
          label: 'payslips.account'.tr(),
          value: _textOrDash(profile.bankAccount),
        ),
      ],
    );
  }

  Widget _payslipsPanel({required bool wide}) => ManagementPanel(
    title: 'payslips.title'.tr(namedArgs: {'count': '${_payslips.length}'}),
    icon: Icons.description_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'common.refresh'.tr(),
            onPressed: _loadingPayslips ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        if (_loadingPayslips && _payslips.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_payslipsError != null && _payslips.isEmpty)
          LoadErrorPanel(error: _payslipsError!, onRetry: _loadPayslips)
        else if (_payslips.isEmpty)
          EmptyState(
            title: 'payslips.noPayslips'.tr(),
            message: 'payslips.noPayslipsMessage'.tr(),
            icon: Icons.receipt_long_outlined,
          )
        else if (wide)
          _payslipGrid()
        else
          Column(
            children: [
              for (final payslip in _payslips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PayslipCard(
                    payslip: payslip,
                    onTap: () => _openPayslip(payslip),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _payslipGrid() => ManagementDataGrid(
    columns: [
      ManagementGridColumn(
        name: 'period',
        label: 'payslips.column.period'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'status',
        label: 'payslips.column.status'.tr(),
        width: 130,
      ),
      ManagementGridColumn(
        name: 'gross',
        label: 'payslips.column.gross'.tr(),
        width: 140,
      ),
      ManagementGridColumn(
        name: 'deductions',
        label: 'payslips.column.deductions'.tr(),
        width: 140,
      ),
      ManagementGridColumn(
        name: 'net',
        label: 'payslips.column.netPay'.tr(),
        width: 140,
      ),
      ManagementGridColumn(
        name: 'paid',
        label: 'payslips.column.paid'.tr(),
        width: 120,
      ),
      ManagementGridColumn(
        name: 'actions',
        label: 'payslips.column.actions'.tr(),
        width: 100,
      ),
    ],
    rows: [
      for (final payslip in _payslips)
        [
          Text(
            payrollPeriodText(payslip.periodYear, payslip.periodMonth),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          StatusChip(
            label: payrollRunStatusLabel(payslip.runStatus),
            color: payrollRunStatusColor(payslip.runStatus),
          ),
          Text(payrollMoney(payslip.grossPay, payslip.currency)),
          Text(payrollMoney(payslip.deductionsTotal, payslip.currency)),
          Text(
            payrollMoney(payslip.netPay, payslip.currency),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(payrollDateLabel(payslip.paidAt)),
          TextButton.icon(
            onPressed: () => _openPayslip(payslip),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text('payslips.view'.tr()),
          ),
        ],
    ],
  );

  Future<void> _openPayslip(Payslip payslip) async {
    try {
      final detail = await GlobalPopupDialog.withLoading(
        context,
        () => api.myPayslip(payslip.id),
        message: 'payslips.loading'.tr(),
      );
      if (!mounted) return;
      await _showBreakdown(detail);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _showBreakdown(Payslip payslip) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payrollPeriodText(payslip.periodYear, payslip.periodMonth),
                    style: const TextStyle(
                      fontSize: StyleFont.largeSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                StatusChip(
                  label: payrollRunStatusLabel(payslip.runStatus),
                  color: payrollRunStatusColor(payslip.runStatus),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [payslip.employeeCode, payslip.jobTitle, payslip.department]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .join(' · '),
              style: const TextStyle(color: StyleColor.muted),
            ),
            const SizedBox(height: 16),
            _breakdownGroup('payslips.breakdown.earnings'.tr(), [
              DetailRow(
                label: 'payslips.breakdown.baseSalary'.tr(),
                value: payrollMoney(payslip.baseSalary, payslip.currency),
              ),
              DetailRow(
                label: 'payslips.breakdown.allowance'.tr(),
                value: payrollMoney(payslip.allowance, payslip.currency),
              ),
              DetailRow(
                label: 'payslips.breakdown.bonus'.tr(),
                value: payrollMoney(payslip.bonus, payslip.currency),
              ),
              DetailRow(
                label: 'payslips.breakdown.overtime'.tr(),
                value: payrollMoney(payslip.overtime, payslip.currency),
              ),
              const Divider(height: 20),
              DetailRow(
                label: 'payslips.breakdown.grossPay'.tr(),
                value: payrollMoney(payslip.grossPay, payslip.currency),
                emphasize: true,
              ),
            ]),
            const SizedBox(height: 12),
            _breakdownGroup('payslips.breakdown.deductions'.tr(), [
              DetailRow(
                label: 'payslips.breakdown.tax'.tr(),
                value: payrollMoney(payslip.tax, payslip.currency),
              ),
              DetailRow(
                label: 'payslips.breakdown.otherDeductions'.tr(),
                value: payrollMoney(payslip.otherDeductions, payslip.currency),
              ),
              const Divider(height: 20),
              DetailRow(
                label: 'payslips.breakdown.totalDeductions'.tr(),
                value: payrollMoney(payslip.deductionsTotal, payslip.currency),
                emphasize: true,
              ),
            ]),
            const SizedBox(height: 12),
            Card(
              color: StyleColor.softMint,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'payslips.breakdown.netPay'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      payrollMoney(payslip.netPay, payslip.currency),
                      style: const TextStyle(
                        fontSize: StyleFont.largeSize,
                        fontWeight: FontWeight.w700,
                        color: StyleColor.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (payslip.paidAt != null)
              DetailRow(
                label: 'payslips.breakdown.paidOn'.tr(),
                value: payrollDateLabel(payslip.paidAt),
              ),
            if (payslip.notes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'payroll.field.notes'.tr(),
                style: TextStyle(
                  color: StyleColor.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(payslip.notes!.trim()),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _breakdownGroup(String title, List<Widget> rows) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: StyleColor.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    ),
  );

  static String _textOrDash(String? value) {
    final text = value?.trim();
    return text?.isNotEmpty == true ? text! : '—';
  }
}
