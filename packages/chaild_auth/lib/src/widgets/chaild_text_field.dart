import 'package:flutter/material.dart';

class ChaildTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final void Function(String)? onChanged;
  final bool autofocus;
  final bool enabled;

  const ChaildTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.textInputAction,
    this.onEditingComplete,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  State<ChaildTextField> createState() => _ChaildTextFieldState();
}

class _ChaildTextFieldState extends State<ChaildTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure && _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onEditingComplete: widget.onEditingComplete,
          onChanged: widget.onChanged,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ── Divider with label ────────────────────────────────────────────────────────

class ChaildDividerOr extends StatelessWidget {
  const ChaildDividerOr({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: textStyle),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
