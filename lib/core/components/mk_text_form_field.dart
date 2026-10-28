import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared marketplace text input. Keep field appearance and common behavior
/// here so forms can be restyled consistently from one place.
class MKTextFormField extends StatelessWidget {
  const MKTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.autovalidateMode,
    this.mouseCursor,
  }) : assert(controller == null || initialValue == null);

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool autofocus;
  final bool readOnly;
  final bool? enabled;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final MouseCursor? mouseCursor;

  static const _radius = BorderRadius.all(Radius.circular(14));
  static const _borderColor = Color(0xFFDCE6E3);

  InputDecoration _styledDecoration(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final baseBorder = OutlineInputBorder(
      borderRadius: _radius,
      borderSide: const BorderSide(color: _borderColor, width: .5),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: _radius,
      borderSide: BorderSide(color: errorColor, width: .7),
    );
    return decoration.copyWith(
      filled: decoration.filled ?? true,
      fillColor: decoration.fillColor ?? Colors.white,
      contentPadding:
          decoration.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: decoration.border ?? baseBorder,
      enabledBorder: decoration.enabledBorder ?? baseBorder,
      disabledBorder: decoration.disabledBorder ?? baseBorder,
      focusedBorder:
          decoration.focusedBorder ??
          OutlineInputBorder(
            borderRadius: _radius,
            borderSide: const BorderSide(color: Color(0xFF12302E), width: 1),
          ),
      errorBorder: decoration.errorBorder ?? errorBorder,
      focusedErrorBorder: decoration.focusedErrorBorder ?? errorBorder,
    );
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    initialValue: initialValue,
    focusNode: focusNode,
    decoration: _styledDecoration(context),
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    textCapitalization: textCapitalization,
    style: style,
    textAlign: textAlign,
    autofillHints: autofillHints,
    obscureText: obscureText,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    autofocus: autofocus,
    readOnly: readOnly,
    enabled: enabled,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    validator: validator,
    onSaved: onSaved,
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    inputFormatters: inputFormatters,
    autovalidateMode: autovalidateMode,
    mouseCursor: mouseCursor,
  );
}
