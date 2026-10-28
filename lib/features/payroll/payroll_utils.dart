import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

String payrollMoney(double value, [String? currency]) {
  final code = (currency?.trim().isNotEmpty ?? false)
      ? currency!.trim().toUpperCase()
      : 'USD';
  final fixed = value.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final grouped = StringBuffer();
  for (var index = 0; index < whole.length; index++) {
    if (index > 0 && (whole.length - index) % 3 == 0) grouped.write(',');
    grouped.write(whole[index]);
  }
  return '${value < 0 ? '-' : ''}$code $grouped${fixed.substring(dot)}';
}

String payrollAmountText(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

double? payrollParseAmount(String? value) =>
    double.tryParse((value ?? '').trim());

String normalizePayrollCurrency(String? value) {
  final text = (value ?? '').trim();
  return text.isEmpty ? 'USD' : text.toUpperCase();
}

String? validatePayrollAmount(
  String? value, {
  String label = '',
  bool required = true,
}) {
  final text = (value ?? '').trim();
  final field = label.trim().isEmpty
      ? 'payroll.validation.amountLabel'.tr()
      : label;
  if (text.isEmpty) {
    return required
        ? 'payroll.validation.amountRequired'.tr(namedArgs: {'label': field})
        : null;
  }
  final amount = double.tryParse(text);
  if (amount == null) return 'payroll.validation.amountInvalid'.tr();
  if (amount < 0) {
    return 'payroll.validation.amountNegative'.tr(namedArgs: {'label': field});
  }
  return null;
}

String? validatePayrollCurrency(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return RegExp(r'^[A-Za-z]{3}$').hasMatch(text)
      ? null
      : 'payroll.validation.currency'.tr();
}

String? validatePayrollDate(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) == null
      ? 'payroll.validation.date'.tr()
      : null;
}

/// Maps a payroll status code to its localized label, falling back to the raw
/// code for values the app does not know about yet.
String payrollStatusLabel(String code) {
  const keys = <String, String>{
    'DRAFT': 'payroll.runStatus.draft',
    'APPROVED': 'payroll.runStatus.approved',
    'PAID': 'payroll.runStatus.paid',
    'CANCELLED': 'payroll.runStatus.cancelled',
    'ACTIVE': 'payroll.employment.active',
    'ON_LEAVE': 'payroll.employment.onLeave',
    'TERMINATED': 'payroll.employment.terminated',
  };
  final key = keys[code];
  return key == null ? code : key.tr();
}

String employmentStatusLabel(String status) {
  final code = status.trim();
  return code.isEmpty
      ? 'payroll.employment.active'.tr()
      : payrollStatusLabel(code);
}

Color employmentStatusColor(String status) => switch (status) {
  'ON_LEAVE' => StyleColor.accent,
  'TERMINATED' => const Color(0xFFB3261E),
  _ => StyleColor.success,
};

String payrollRunStatusLabel(String? status) {
  final code = status?.trim() ?? '';
  return code.isEmpty
      ? 'payroll.runStatus.draft'.tr()
      : payrollStatusLabel(code);
}

Color payrollRunStatusColor(String? status) => switch (status) {
  'APPROVED' => StyleColor.teal,
  'PAID' => StyleColor.success,
  'CANCELLED' => const Color(0xFFB3261E),
  _ => StyleColor.muted,
};

String payrollDateLabel(DateTime? value) {
  if (value == null) return '—';
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

const _payrollMonthKeys = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

String payrollMonthName(int month) => month >= 1 && month <= 12
    ? 'payroll.months.${_payrollMonthKeys[month - 1]}'.tr()
    : 'payroll.monthFallback'.tr();

/// Localized `<Month> <Year>` label for payroll periods.
String payrollPeriodText(int? year, int? month) {
  if (year == null || month == null || month < 1 || month > 12) {
    return 'payroll.periodFallback'.tr();
  }
  return '${payrollMonthName(month)} $year';
}

/// Thrown for client-side payroll rules so [Api.errorMessage] shows a clean
/// message inside the shared error dialog.
class PayrollMessage implements Exception {
  const PayrollMessage(this.message);

  final String message;

  @override
  String toString() => message;
}
