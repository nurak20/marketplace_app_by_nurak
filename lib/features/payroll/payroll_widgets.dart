import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/components/status_chip.dart';
import '../../core/models.dart';
import 'payroll_utils.dart';

const _employmentStatuses = ['ACTIVE', 'ON_LEAVE', 'TERMINATED'];

/// Compact metric used in payroll summaries.
class PayrollMetricTile extends StatelessWidget {
  const PayrollMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: StyleColor.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color ?? StyleColor.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Mobile card for one employee profile.
class EmployeeSummaryCard extends StatelessWidget {
  const EmployeeSummaryCard({
    super.key,
    required this.employee,
    this.canManage = false,
    this.onEdit,
    this.onStatusSelected,
  });

  final EmployeeProfile employee;
  final bool canManage;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      employee.employeeLabel,
      if (employee.jobTitle?.trim().isNotEmpty == true)
        employee.jobTitle!.trim(),
      if (employee.department?.trim().isNotEmpty == true)
        employee.department!.trim(),
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StyleColor.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: employmentStatusLabel(employee.status),
                  color: employmentStatusColor(employee.status),
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'payroll.changeStatus'.tr(),
                    onSelected: onStatusSelected,
                    itemBuilder: (_) => [
                      for (final status in _employmentStatuses)
                        PopupMenuItem(
                          value: status,
                          child: Text(employmentStatusLabel(status)),
                        ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                PayrollMetricTile(
                  label: 'payroll.column.baseSalary'.tr(),
                  value: payrollMoney(employee.baseSalary, employee.currency),
                ),
                PayrollMetricTile(
                  label: 'payroll.column.allowance'.tr(),
                  value: payrollMoney(employee.allowance, employee.currency),
                ),
              ],
            ),
            if (canManage && onEdit != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text('profile.edit'.tr()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mobile card for one payroll run.
class PayrollRunCard extends StatelessWidget {
  const PayrollRunCard({super.key, required this.run, required this.onOpen});

  final PayrollRun run;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    payrollPeriodText(run.periodYear, run.periodMonth),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                StatusChip(
                  label: payrollRunStatusLabel(run.status),
                  color: payrollRunStatusColor(run.status),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                PayrollMetricTile(
                  label: 'payroll.column.netPay'.tr(),
                  value: payrollMoney(run.totalNet, run.currency),
                  color: StyleColor.success,
                ),
                PayrollMetricTile(
                  label: 'payroll.column.gross'.tr(),
                  value: payrollMoney(run.totalGross, run.currency),
                ),
                PayrollMetricTile(
                  label: 'payroll.column.deductions'.tr(),
                  value: payrollMoney(run.totalDeductions, run.currency),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared payslip row used by the staff run detail and self-service screens.
class PayslipCard extends StatelessWidget {
  const PayslipCard({
    super.key,
    required this.payslip,
    this.onTap,
    this.onEdit,
  });

  final Payslip payslip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: StyleColor.softMint,
        foregroundColor: StyleColor.ink,
        child: Icon(Icons.receipt_long_outlined),
      ),
      title: Text(
        payslip.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'payroll.cardNet'.tr(
          namedArgs: {
            'code': payslip.employeeCode ?? '—',
            'amount': payrollMoney(payslip.netPay, payslip.currency),
          },
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: onEdit != null
          ? IconButton(
              tooltip: 'payroll.adjustPayslip'.tr(),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            )
          : payslip.runStatus != null
          ? StatusChip(
              label: payrollRunStatusLabel(payslip.runStatus),
              color: payrollRunStatusColor(payslip.runStatus),
            )
          : const Icon(Icons.chevron_right_rounded),
    ),
  );
}
