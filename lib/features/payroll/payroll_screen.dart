import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/components/empty_state.dart';
import '../../core/components/form_dialog.dart';
import '../../core/components/global_popup_dialog.dart';
import '../../core/components/load_error_panel.dart';
import '../../core/components/localized_builder.dart';
import '../../core/components/management_data_grid.dart';
import '../../core/components/management_panel.dart';
import '../../core/components/marketplace_app_bar.dart';
import '../../core/components/mk_text_form_field.dart';
import '../../core/components/show_error.dart';
import '../../core/components/status_chip.dart';
import '../../core/models.dart';
import '../../core/singleton.dart';
import 'payroll_utils.dart';
import 'payroll_widgets.dart';

enum _PayrollTab { employees, runs }

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  _PayrollTab _tab = _PayrollTab.employees;

  final _employeeSearch = TextEditingController();
  Timer? _searchTimer;
  String _employeeStatus = 'ALL';
  String _employeeQuery = '';
  bool _loadingEmployees = false;
  Object? _employeesError;
  List<EmployeeProfile> _employees = [];

  bool _loadingRuns = false;
  Object? _runsError;
  List<PayrollRun> _runs = [];

  PayrollRun? _selectedRun;
  List<Payslip> _payslips = [];
  bool _loadingRun = false;
  Object? _runError;

  Account? get _account => Singleton.instance.account;
  bool get _canManage => _account?.canManagePayroll == true;
  bool get _canApprove => _account?.canApprovePayroll == true;
  bool get _hasAccess => _account?.canAccessPayroll == true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadRuns();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _employeeSearch.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _employeesError = null;
    });
    try {
      final page = await api.payrollEmployees(
        status: _employeeStatus,
        query: _employeeQuery,
      );
      if (!mounted) return;
      setState(() => _employees = page.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _employeesError = error);
    } finally {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _loadRuns() async {
    setState(() {
      _loadingRuns = true;
      _runsError = null;
    });
    try {
      final page = await api.payrollRuns();
      if (!mounted) return;
      setState(() => _runs = page.items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _runsError = error);
    } finally {
      if (mounted) setState(() => _loadingRuns = false);
    }
  }

  Future<void> _refreshCurrent() =>
      _tab == _PayrollTab.employees ? _loadEmployees() : _loadRuns();

  void _selectTab(_PayrollTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (tab == _PayrollTab.employees && _employees.isEmpty) {
      _loadEmployees();
    }
    if (tab == _PayrollTab.runs && _runs.isEmpty) _loadRuns();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = value.trim();
      if (query == _employeeQuery) return;
      setState(() => _employeeQuery = query);
      _loadEmployees();
    });
  }

  void _storeEmployee(EmployeeProfile employee) {
    final index = _employees.indexWhere(
      (item) => item.userId == employee.userId,
    );
    if (index >= 0) {
      _employees[index] = employee;
    } else {
      _employees = [..._employees, employee]
        ..sort((a, b) => a.employeeLabel.compareTo(b.employeeLabel));
    }
  }

  void _storeRun(PayrollRun run) {
    final index = _runs.indexWhere((item) => item.id == run.id);
    if (index >= 0) {
      _runs[index] = run;
    } else {
      _runs.insert(0, run);
    }
  }

  @override
  Widget build(BuildContext context) => LocalizedBuilder(
    builder: (context) => Scaffold(
      appBar: MarketplaceAppBar(
        title: 'payroll.title'.tr(),
        showNotifications: false,
        showManagement: false,
        showProfileAvatar: false,
      ).build(context),
      body: !_hasAccess
          ? EmptyState(
              title: 'payroll.accessRequired'.tr(),
              message: 'payroll.accessMessage'.tr(),
              icon: Icons.lock_outline_rounded,
            )
          : Material(
              color: StyleColor.canvas,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 840;
                  final content = SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _tab == _PayrollTab.employees
                        ? _employeesPanel(wide)
                        : _runsSection(wide),
                  );

                  if (!wide) {
                    return Column(
                      children: [
                        _tabSelector(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refreshCurrent,
                            child: content,
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PayrollRail(tab: _tab, onSelect: _selectTab),
                      const VerticalDivider(width: 1, color: StyleColor.line),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshCurrent,
                          child: content,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    ),
  );

  Widget _tabSelector() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: SizedBox(
      width: double.infinity,
      child: SegmentedButton<_PayrollTab>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _PayrollTab.employees,
            label: Text('payroll.tab.employees'.tr()),
          ),
          ButtonSegment(
            value: _PayrollTab.runs,
            label: Text('payroll.tab.runs'.tr()),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (selection) => _selectTab(selection.first),
      ),
    ),
  );

  Widget _employeesPanel(bool wide) => ManagementPanel(
    title: 'payroll.employeeProfiles'.tr(),
    icon: Icons.badge_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _employeeToolbar(wide),
        if (_loadingEmployees) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        if (_loadingEmployees && _employees.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_employeesError != null && _employees.isEmpty)
          LoadErrorPanel(error: _employeesError!, onRetry: _loadEmployees)
        else if (_employees.isEmpty)
          EmptyState(
            title: 'payroll.noEmployees'.tr(),
            message: 'payroll.noEmployeesMessage'.tr(),
            icon: Icons.badge_outlined,
          )
        else if (wide)
          _employeeGrid()
        else
          Column(
            children: [
              for (final employee in _employees)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: EmployeeSummaryCard(
                    employee: employee,
                    canManage: _canManage,
                    onEdit: () => _showEmployeeDialog(employee: employee),
                    onStatusSelected: (status) =>
                        _changeEmployeeStatus(employee, status),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _employeeToolbar(bool wide) {
    final search = MKTextFormField(
      controller: _employeeSearch,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        labelText: 'common.search'.tr(),
        hintText: 'payroll.searchHint'.tr(),
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
    final status = DropdownButtonFormField<String>(
      initialValue: _employeeStatus,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'common.status'.tr()),
      items: [
        DropdownMenuItem(value: 'ALL', child: Text('payroll.allStatuses'.tr())),
        DropdownMenuItem(
          value: 'ACTIVE',
          child: Text(employmentStatusLabel('ACTIVE')),
        ),
        DropdownMenuItem(
          value: 'ON_LEAVE',
          child: Text(employmentStatusLabel('ON_LEAVE')),
        ),
        DropdownMenuItem(
          value: 'TERMINATED',
          child: Text(employmentStatusLabel('TERMINATED')),
        ),
      ],
      onChanged: (value) {
        if (value == null || value == _employeeStatus) return;
        setState(() => _employeeStatus = value);
        _loadEmployees();
      },
    );
    final actions = <Widget>[
      if (_canManage)
        FilledButton.icon(
          onPressed: _enrollEmployee,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text('payroll.enroll'.tr()),
        ),
      IconButton(
        tooltip: 'common.refresh'.tr(),
        onPressed: _loadingEmployees ? null : _loadEmployees,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ];

    if (wide) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 320, child: search),
          SizedBox(width: 190, child: status),
          ...actions,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: status),
            const SizedBox(width: 8),
            ...actions,
          ],
        ),
      ],
    );
  }

  Widget _employeeGrid() => ManagementDataGrid(
    columns: [
      ManagementGridColumn(
        name: 'employee',
        label: 'payroll.column.employee'.tr(),
        width: 240,
      ),
      ManagementGridColumn(
        name: 'code',
        label: 'payroll.column.code'.tr(),
        width: 130,
      ),
      ManagementGridColumn(
        name: 'role',
        label: 'payroll.column.role'.tr(),
        width: 200,
      ),
      ManagementGridColumn(
        name: 'base',
        label: 'payroll.column.baseSalary'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'allowance',
        label: 'payroll.column.allowance'.tr(),
        width: 140,
      ),
      ManagementGridColumn(
        name: 'status',
        label: 'payroll.column.status'.tr(),
        width: 130,
      ),
      ManagementGridColumn(
        name: 'actions',
        label: 'payroll.column.actions'.tr(),
        width: 150,
      ),
    ],
    rows: [
      for (final employee in _employees)
        [
          _employeeIdentity(employee),
          Text(employee.employeeLabel),
          _twoLine(employee.jobTitle, employee.department),
          Text(payrollMoney(employee.baseSalary, employee.currency)),
          Text(payrollMoney(employee.allowance, employee.currency)),
          StatusChip(
            label: employmentStatusLabel(employee.status),
            color: employmentStatusColor(employee.status),
          ),
          _employeeActions(employee),
        ],
    ],
  );

  Widget _employeeIdentity(EmployeeProfile employee) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        employee.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      Text(
        '@${employee.username ?? 'user-${employee.userId}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: StyleColor.muted, fontSize: 12),
      ),
    ],
  );

  Widget _twoLine(String? primary, String? secondary) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        primary?.trim().isNotEmpty == true ? primary!.trim() : '—',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      if (secondary?.trim().isNotEmpty == true)
        Text(
          secondary!.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: StyleColor.muted, fontSize: 12),
        ),
    ],
  );

  Widget _employeeActions(EmployeeProfile employee) {
    if (!_canManage) return const Text('—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'payroll.editEmployee'.tr(),
          onPressed: () => _showEmployeeDialog(employee: employee),
          icon: const Icon(Icons.edit_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: 'payroll.changeStatus'.tr(),
          onSelected: (status) => _changeEmployeeStatus(employee, status),
          itemBuilder: (_) => [
            for (final status in const ['ACTIVE', 'ON_LEAVE', 'TERMINATED'])
              PopupMenuItem(
                value: status,
                child: Text(employmentStatusLabel(status)),
              ),
          ],
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    );
  }

  Widget _runsSection(bool wide) =>
      _selectedRun == null ? _runsPanel(wide) : _runDetail(wide);

  Widget _runsPanel(bool wide) => ManagementPanel(
    title: 'payroll.tab.runs'.tr(),
    icon: Icons.receipt_long_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_canManage)
              FilledButton.icon(
                onPressed: _createRun,
                icon: const Icon(Icons.add_rounded),
                label: Text('payroll.newRun'.tr()),
              ),
            IconButton(
              tooltip: 'common.refresh'.tr(),
              onPressed: _loadingRuns ? null : _loadRuns,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_loadingRuns) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 12),
        if (_loadingRuns && _runs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_runsError != null && _runs.isEmpty)
          LoadErrorPanel(error: _runsError!, onRetry: _loadRuns)
        else if (_runs.isEmpty)
          EmptyState(
            title: 'payroll.noRuns'.tr(),
            message: 'payroll.noRunsMessage'.tr(),
            icon: Icons.receipt_long_outlined,
          )
        else if (wide)
          _runsGrid()
        else
          Column(
            children: [
              for (final run in _runs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PayrollRunCard(
                    run: run,
                    onOpen: () => _openRun(run.id),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _runsGrid() => ManagementDataGrid(
    columns: [
      ManagementGridColumn(
        name: 'period',
        label: 'payroll.column.period'.tr(),
        width: 170,
      ),
      ManagementGridColumn(
        name: 'status',
        label: 'payroll.column.status'.tr(),
        width: 140,
      ),
      ManagementGridColumn(
        name: 'gross',
        label: 'payroll.column.gross'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'deductions',
        label: 'payroll.column.deductions'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'net',
        label: 'payroll.column.netPay'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'created',
        label: 'payroll.column.created'.tr(),
        width: 150,
      ),
      ManagementGridColumn(
        name: 'actions',
        label: 'payroll.column.actions'.tr(),
        width: 110,
      ),
    ],
    rows: [
      for (final run in _runs)
        [
          Text(
            payrollPeriodText(run.periodYear, run.periodMonth),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          StatusChip(
            label: payrollRunStatusLabel(run.status),
            color: payrollRunStatusColor(run.status),
          ),
          Text(payrollMoney(run.totalGross, run.currency)),
          Text(payrollMoney(run.totalDeductions, run.currency)),
          Text(
            payrollMoney(run.totalNet, run.currency),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(payrollDateLabel(run.createdAt)),
          TextButton.icon(
            onPressed: () => _openRun(run.id),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text('payroll.open'.tr()),
          ),
        ],
    ],
  );

  Widget _runDetail(bool wide) {
    final run = _selectedRun!;
    final actions = _runActionButtons(run);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagementPanel(
          title: payrollPeriodText(run.periodYear, run.periodMonth),
          icon: Icons.receipt_long_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _closeRun,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text('payroll.allRuns'.tr()),
                  ),
                  StatusChip(
                    label: payrollRunStatusLabel(run.status),
                    color: payrollRunStatusColor(run.status),
                  ),
                  if (_loadingRun)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  IconButton(
                    tooltip: 'common.refresh'.tr(),
                    onPressed: _loadingRun ? null : () => _openRun(run.id),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 14,
                    children: [
                      PayrollMetricTile(
                        label: 'payroll.column.gross'.tr(),
                        value: payrollMoney(run.totalGross, run.currency),
                      ),
                      PayrollMetricTile(
                        label: 'payroll.column.deductions'.tr(),
                        value: payrollMoney(run.totalDeductions, run.currency),
                      ),
                      PayrollMetricTile(
                        label: 'payroll.column.netPay'.tr(),
                        value: payrollMoney(run.totalNet, run.currency),
                        color: StyleColor.success,
                      ),
                      PayrollMetricTile(
                        label: 'payroll.column.created'.tr(),
                        value: payrollDateLabel(run.createdAt),
                      ),
                      if (run.approvedAt != null)
                        PayrollMetricTile(
                          label: 'payroll.column.approved'.tr(),
                          value: payrollDateLabel(run.approvedAt),
                        ),
                      if (run.paidAt != null)
                        PayrollMetricTile(
                          label: 'payroll.column.paid'.tr(),
                          value: payrollDateLabel(run.paidAt),
                        ),
                    ],
                  ),
                ),
              ),
              if (run.notes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  run.notes!.trim(),
                  style: const TextStyle(color: StyleColor.muted),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
        if (_runError != null)
          LoadErrorPanel(error: _runError!, onRetry: () => _openRun(run.id)),
        ManagementPanel(
          title: 'payroll.payslips'.tr(
            namedArgs: {'count': '${_payslips.length}'},
          ),
          icon: Icons.description_outlined,
          child: _payslipContent(run, wide),
        ),
      ],
    );
  }

  Widget _payslipContent(PayrollRun run, bool wide) {
    if (_loadingRun && _payslips.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_runError != null && _payslips.isEmpty) {
      return LoadErrorPanel(error: _runError!, onRetry: () => _openRun(run.id));
    }
    if (_payslips.isEmpty) {
      return EmptyState(
        title: 'payroll.noPayslips'.tr(),
        message: 'payroll.noPayslipsMessage'.tr(),
        icon: Icons.description_outlined,
      );
    }
    if (!wide) {
      return Column(
        children: [
          for (final payslip in _payslips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PayslipCard(
                payslip: payslip,
                onEdit: run.isDraft && _canManage
                    ? () => _editPayslip(payslip)
                    : null,
              ),
            ),
        ],
      );
    }
    return ManagementDataGrid(
      columns: [
        ManagementGridColumn(
          name: 'employee',
          label: 'payroll.column.employee'.tr(),
          width: 220,
        ),
        ManagementGridColumn(
          name: 'code',
          label: 'payroll.column.code'.tr(),
          width: 110,
        ),
        ManagementGridColumn(
          name: 'base',
          label: 'payroll.column.base'.tr(),
          width: 120,
        ),
        ManagementGridColumn(
          name: 'allowance',
          label: 'payroll.column.allowance'.tr(),
          width: 120,
        ),
        ManagementGridColumn(
          name: 'bonus',
          label: 'payroll.column.bonus'.tr(),
          width: 100,
        ),
        ManagementGridColumn(
          name: 'overtime',
          label: 'payroll.column.overtime'.tr(),
          width: 100,
        ),
        ManagementGridColumn(
          name: 'tax',
          label: 'payroll.column.tax'.tr(),
          width: 100,
        ),
        ManagementGridColumn(
          name: 'other',
          label: 'payroll.column.other'.tr(),
          width: 100,
        ),
        ManagementGridColumn(
          name: 'net',
          label: 'payroll.column.net'.tr(),
          width: 130,
        ),
        ManagementGridColumn(
          name: 'actions',
          label: 'payroll.column.actions'.tr(),
          width: 80,
        ),
      ],
      rows: [
        for (final payslip in _payslips)
          [
            _twoLine(
              payslip.displayName,
              payslip.jobTitle ?? payslip.department,
            ),
            Text(payslip.employeeCode ?? '—'),
            Text(payrollMoney(payslip.baseSalary, payslip.currency)),
            Text(payrollMoney(payslip.allowance, payslip.currency)),
            Text(payrollMoney(payslip.bonus, payslip.currency)),
            Text(payrollMoney(payslip.overtime, payslip.currency)),
            Text(payrollMoney(payslip.tax, payslip.currency)),
            Text(payrollMoney(payslip.otherDeductions, payslip.currency)),
            Text(
              payrollMoney(payslip.netPay, payslip.currency),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (run.isDraft && _canManage)
              IconButton(
                tooltip: 'payroll.adjustPayslip'.tr(),
                onPressed: () => _editPayslip(payslip),
                icon: const Icon(Icons.edit_outlined),
              )
            else
              const Text('—'),
          ],
      ],
    );
  }

  List<Widget> _runActionButtons(PayrollRun run) => [
    if (run.isDraft && _canManage)
      OutlinedButton.icon(
        onPressed: () => _runAction(
          title: 'payroll.regenerateTitle'.tr(),
          message: 'payroll.regenerateMessage'.tr(),
          confirmLabel: 'payroll.regenerate'.tr(),
          action: () => api.regeneratePayrollRun(run.id),
          successMessage: 'payroll.regenerateSuccess'.tr(),
          reloadPayslips: true,
        ),
        icon: const Icon(Icons.refresh_rounded),
        label: Text('payroll.regenerate'.tr()),
      ),
    if (run.isDraft && _canManage)
      OutlinedButton.icon(
        onPressed: () => _runAction(
          title: 'payroll.cancelRunTitle'.tr(),
          message: 'payroll.cancelRunMessage'.tr(),
          confirmLabel: 'payroll.cancelRun'.tr(),
          action: () => api.cancelPayrollRun(run.id),
          successMessage: 'payroll.cancelRunSuccess'.tr(),
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: Text('payroll.cancelRun'.tr()),
      ),
    if (run.isDraft && _canApprove)
      FilledButton.icon(
        onPressed: () => _runAction(
          title: 'payroll.approveTitle'.tr(),
          message: 'payroll.approveMessage'.tr(),
          confirmLabel: 'payroll.approve'.tr(),
          action: () => api.approvePayrollRun(run.id),
          successMessage: 'payroll.approveSuccess'.tr(),
        ),
        icon: const Icon(Icons.verified_outlined),
        label: Text('payroll.approve'.tr()),
      ),
    if (run.isApproved && _canApprove)
      FilledButton.icon(
        onPressed: () => _runAction(
          title: 'payroll.markPaidTitle'.tr(),
          message: 'payroll.markPaidMessage'.tr(),
          confirmLabel: 'payroll.markPaid'.tr(),
          action: () => api.payPayrollRun(run.id),
          successMessage: 'payroll.markPaidSuccess'.tr(),
        ),
        icon: const Icon(Icons.price_check_rounded),
        label: Text('payroll.markPaid'.tr()),
      ),
  ];

  Future<void> _runAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<PayrollRun> Function() action,
    required String successMessage,
    bool reloadPayslips = false,
  }) async {
    final confirmed = await GlobalPopupDialog.yesNoPrompt(
      context,
      title: title,
      message: message,
      yesText: confirmLabel,
      noText: 'common.cancel'.tr(),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() {
        _selectedRun = updated;
        _storeRun(updated);
      });
      if (reloadPayslips) await _openRun(updated.id);
      if (mounted) {
        await GlobalPopupDialog.success(context, message: successMessage);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _openRun(int runId) async {
    PayrollRun? existing;
    for (final run in _runs) {
      if (run.id == runId) {
        existing = run;
        break;
      }
    }
    setState(() {
      _selectedRun = existing;
      _payslips = [];
      _runError = null;
      _loadingRun = true;
    });
    try {
      final run = await api.payrollRun(runId);
      final page = await api.payrollRunPayslips(runId);
      if (!mounted) return;
      setState(() {
        _selectedRun = run;
        _payslips = page.items;
        _storeRun(run);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _runError = error);
    } finally {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  void _closeRun() {
    setState(() {
      _selectedRun = null;
      _payslips = [];
      _runError = null;
    });
  }

  Future<void> _enrollEmployee() async {
    final enrolled = _employees.map((employee) => employee.userId).toSet();
    List<Account> candidates;
    try {
      final page = await api.managementUsers();
      candidates = page.items
          .where(
            (account) =>
                account.active && !enrolled.contains(account.profile.id),
          )
          .toList();
    } catch (error) {
      if (mounted) showError(context, error);
      return;
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      await GlobalPopupDialog.success(
        context,
        title: 'payroll.nothingToEnroll'.tr(),
        message: 'payroll.nothingToEnrollMessage'.tr(),
      );
      return;
    }
    final created = await _showEmployeeDialog(candidates: candidates);
    if (created != null && mounted) {
      setState(() => _storeEmployee(created));
    }
  }

  Future<EmployeeProfile?> _showEmployeeDialog({
    EmployeeProfile? employee,
    List<Account>? candidates,
  }) async {
    final isEdit = employee != null;
    final formKey = GlobalKey<FormState>();
    var selectedUserId = employee?.userId ?? candidates!.first.profile.id;
    final code = TextEditingController(text: employee?.employeeCode ?? '');
    final jobTitle = TextEditingController(text: employee?.jobTitle ?? '');
    final department = TextEditingController(text: employee?.department ?? '');
    final baseSalary = TextEditingController(
      text: employee == null ? '' : payrollAmountText(employee.baseSalary),
    );
    final allowance = TextEditingController(
      text: employee == null ? '' : payrollAmountText(employee.allowance),
    );
    final currency = TextEditingController(text: employee?.currency ?? 'USD');
    final hireDate = TextEditingController(
      text: employee == null ? '' : payrollDateLabel(employee.hireDate),
    );
    final bankName = TextEditingController(text: employee?.bankName ?? '');
    final bankAccount = TextEditingController(
      text: employee?.bankAccount ?? '',
    );

    return showMarketplaceFormDialog<EmployeeProfile>(
      context: context,
      title: isEdit
          ? 'payroll.editTitle'.tr(namedArgs: {'name': employee.displayName})
          : 'payroll.enrollTitle'.tr(),
      formKey: formKey,
      submitLabel: isEdit ? 'common.saveChanges'.tr() : 'payroll.enroll'.tr(),
      submitIcon: isEdit ? Icons.save_outlined : Icons.person_add_alt_1_rounded,
      onClosed: () {
        code.dispose();
        jobTitle.dispose();
        department.dispose();
        baseSalary.dispose();
        allowance.dispose();
        currency.dispose();
        hireDate.dispose();
        bankName.dispose();
        bankAccount.dispose();
      },
      content: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (isEdit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StyleColor.canvas,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${employee.displayName} · ${employee.employeeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: selectedUserId,
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: InputDecoration(
                labelText: 'payroll.field.account'.tr(),
              ),
              items: [
                for (final account in candidates!)
                  DropdownMenuItem(
                    value: account.profile.id,
                    child: Text(
                      '${account.profile.displayName} · '
                      '${account.email ?? account.profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) selectedUserId = value;
              },
              validator: (value) =>
                  value == null ? 'payroll.accountRequired'.tr() : null,
            ),
          if (!isEdit)
            MKTextFormField(
              controller: code,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'payroll.field.employeeCode'.tr(),
                hintText: 'payroll.employeeCodeHint'.tr(),
                counterText: '',
              ),
            ),
          MKTextFormField(
            controller: jobTitle,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'payroll.field.jobTitle'.tr(),
              counterText: '',
            ),
          ),
          MKTextFormField(
            controller: department,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'payroll.field.department'.tr(),
              counterText: '',
            ),
          ),
          MKTextFormField(
            controller: baseSalary,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'payroll.field.baseSalary'.tr(),
            ),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.baseSalary'.tr(),
            ),
          ),
          MKTextFormField(
            controller: allowance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'payroll.field.allowance'.tr(),
              hintText: '0.00',
            ),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.allowance'.tr(),
              required: false,
            ),
          ),
          MKTextFormField(
            controller: currency,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'payroll.field.currency'.tr(),
              hintText: 'USD',
              counterText: '',
            ),
            validator: validatePayrollCurrency,
          ),
          MKTextFormField(
            controller: hireDate,
            decoration: InputDecoration(
              labelText: 'payroll.field.hireDate'.tr(),
              hintText: 'payroll.hireDateHint'.tr(),
            ),
            validator: validatePayrollDate,
          ),
          MKTextFormField(
            controller: bankName,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'payroll.field.bankName'.tr(),
              counterText: '',
            ),
          ),
          MKTextFormField(
            controller: bankAccount,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'payroll.field.bankAccount'.tr(),
              counterText: '',
            ),
          ),
        ],
      ),
      onSubmit: (_) {
        final body = <String, dynamic>{
          if (!isEdit) 'userId': selectedUserId,
          if (!isEdit && code.text.trim().isNotEmpty)
            'employeeCode': code.text.trim(),
          'jobTitle': jobTitle.text.trim(),
          'department': department.text.trim(),
          'baseSalary': payrollParseAmount(baseSalary.text),
          'allowance': payrollParseAmount(allowance.text) ?? 0,
          if (currency.text.trim().isNotEmpty)
            'currency': normalizePayrollCurrency(currency.text),
          if (hireDate.text.trim().isNotEmpty) 'hireDate': hireDate.text.trim(),
          'bankName': bankName.text.trim(),
          'bankAccount': bankAccount.text.trim(),
        };
        return isEdit
            ? api.updatePayrollEmployee(employee.userId, body)
            : api.enrollPayrollEmployee(body);
      },
    );
  }

  Future<void> _changeEmployeeStatus(
    EmployeeProfile employee,
    String status,
  ) async {
    if (status == employee.status) return;
    if (status == 'TERMINATED') {
      final confirmed = await GlobalPopupDialog.yesNoPrompt(
        context,
        title: 'payroll.terminateTitle'.tr(),
        message: 'payroll.terminateMessage'.tr(
          namedArgs: {'name': employee.displayName},
        ),
        yesText: 'payroll.terminate'.tr(),
        noText: 'common.cancel'.tr(),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final updated = await api.setPayrollEmployeeStatus(
        employee.userId,
        status,
      );
      if (!mounted) return;
      setState(() => _storeEmployee(updated));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _createRun() async {
    final now = DateTime.now();
    final formKey = GlobalKey<FormState>();
    var month = now.month;
    final year = TextEditingController(text: '${now.year}');
    final currency = TextEditingController(text: 'USD');
    final notes = TextEditingController();

    final created = await showMarketplaceFormDialog<PayrollRun>(
      context: context,
      title: 'payroll.createRunTitle'.tr(),
      formKey: formKey,
      submitLabel: 'payroll.createRun'.tr(),
      submitIcon: Icons.add_rounded,
      onClosed: () {
        year.dispose();
        currency.dispose();
        notes.dispose();
      },
      content: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          MKTextFormField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'payroll.field.year'.tr()),
            validator: (value) {
              final parsed = int.tryParse((value ?? '').trim());
              if (parsed == null || parsed < 2000 || parsed > 2100) {
                return 'payroll.yearRange'.tr();
              }
              return null;
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: month,
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: InputDecoration(labelText: 'payroll.field.month'.tr()),
            items: [
              for (var value = 1; value <= 12; value++)
                DropdownMenuItem(
                  value: value,
                  child: Text(payrollMonthName(value)),
                ),
            ],
            onChanged: (value) {
              if (value != null) month = value;
            },
          ),
          MKTextFormField(
            controller: currency,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'payroll.field.currency'.tr(),
              hintText: 'USD',
              counterText: '',
            ),
            validator: validatePayrollCurrency,
          ),
          MKTextFormField(
            controller: notes,
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'payroll.field.notes'.tr(),
              counterText: '',
            ),
          ),
        ],
      ),
      onSubmit: (_) {
        final parsedYear = int.tryParse(year.text.trim());
        if (parsedYear == null) {
          throw PayrollMessage('payroll.error.invalidYear'.tr());
        }
        if (parsedYear > now.year ||
            (parsedYear == now.year && month > now.month)) {
          throw PayrollMessage('payroll.error.futurePeriod'.tr());
        }
        return api.createPayrollRun({
          'year': parsedYear,
          'month': month,
          'currency': normalizePayrollCurrency(currency.text),
          if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        });
      },
    );
    if (created != null && mounted) {
      setState(() {
        _storeRun(created);
        _tab = _PayrollTab.runs;
      });
      await _openRun(created.id);
    }
  }

  Future<void> _editPayslip(Payslip payslip) async {
    final run = _selectedRun;
    if (run == null || !run.isDraft || !_canManage) return;
    final formKey = GlobalKey<FormState>();
    final bonus = TextEditingController(text: payrollAmountText(payslip.bonus));
    final overtime = TextEditingController(
      text: payrollAmountText(payslip.overtime),
    );
    final tax = TextEditingController(text: payrollAmountText(payslip.tax));
    final other = TextEditingController(
      text: payrollAmountText(payslip.otherDeductions),
    );
    final notes = TextEditingController(text: payslip.notes ?? '');

    final updated = await showMarketplaceFormDialog<Payslip>(
      context: context,
      title: 'payroll.adjustTitle'.tr(namedArgs: {'name': payslip.displayName}),
      formKey: formKey,
      submitLabel: 'payroll.savePayslip'.tr(),
      submitIcon: Icons.save_outlined,
      onClosed: () {
        bonus.dispose();
        overtime.dispose();
        tax.dispose();
        other.dispose();
        notes.dispose();
      },
      content: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StyleColor.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'payroll.grossDeductions'.tr(
                namedArgs: {
                  'gross': payrollMoney(payslip.grossPay, payslip.currency),
                  'deductions': payrollMoney(
                    payslip.deductionsTotal,
                    payslip.currency,
                  ),
                },
              ),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          MKTextFormField(
            controller: bonus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'payroll.field.bonus'.tr()),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.bonus'.tr(),
              required: false,
            ),
          ),
          MKTextFormField(
            controller: overtime,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'payroll.field.overtime'.tr(),
            ),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.overtime'.tr(),
              required: false,
            ),
          ),
          MKTextFormField(
            controller: tax,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'payroll.field.tax'.tr()),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.tax'.tr(),
              required: false,
            ),
          ),
          MKTextFormField(
            controller: other,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'payroll.field.otherDeductions'.tr(),
            ),
            validator: (value) => validatePayrollAmount(
              value,
              label: 'payroll.field.otherDeductions'.tr(),
              required: false,
            ),
          ),
          MKTextFormField(
            controller: notes,
            maxLines: 2,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'payroll.field.notes'.tr(),
              counterText: '',
            ),
          ),
        ],
      ),
      onSubmit: (_) {
        final bonusValue = payrollParseAmount(bonus.text) ?? 0;
        final overtimeValue = payrollParseAmount(overtime.text) ?? 0;
        final taxValue = payrollParseAmount(tax.text) ?? 0;
        final otherValue = payrollParseAmount(other.text) ?? 0;
        final gross =
            payslip.baseSalary + payslip.allowance + bonusValue + overtimeValue;
        if (taxValue + otherValue > gross) {
          throw PayrollMessage('payroll.error.deductionsExceed'.tr());
        }
        return api.updatePayrollPayslip(payslip.id, {
          'bonus': bonusValue,
          'overtime': overtimeValue,
          'tax': taxValue,
          'otherDeductions': otherValue,
          if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        });
      },
    );
    if (updated != null && mounted) {
      setState(() {
        _payslips = [
          for (final item in _payslips) item.id == updated.id ? updated : item,
        ];
      });
      await _refreshRunTotals();
    }
  }

  Future<void> _refreshRunTotals() async {
    final run = _selectedRun;
    if (run == null) return;
    try {
      final updated = await api.payrollRun(run.id);
      if (!mounted) return;
      setState(() {
        _selectedRun = updated;
        _storeRun(updated);
      });
    } catch (_) {
      // The edited payslip is already shown; totals refresh on next open.
    }
  }
}

class _PayrollRail extends StatelessWidget {
  const _PayrollRail({required this.tab, required this.onSelect});

  final _PayrollTab tab;
  final ValueChanged<_PayrollTab> onSelect;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      width: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _railItem(
              icon: Icons.badge_outlined,
              label: 'payroll.tab.employees'.tr(),
              selected: tab == _PayrollTab.employees,
              onTap: () => onSelect(_PayrollTab.employees),
            ),
            _railItem(
              icon: Icons.receipt_long_outlined,
              label: 'payroll.tab.runs'.tr(),
              selected: tab == _PayrollTab.runs,
              onTap: () => onSelect(_PayrollTab.runs),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _railItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: selected ? StyleColor.sand : Colors.transparent,
          foregroundColor: selected ? StyleColor.ink : StyleColor.muted,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon),
      ),
    ),
  );
}
