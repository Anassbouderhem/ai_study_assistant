import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool block;

  const PrimaryButton({super.key, required this.onPressed, required this.child, this.block = true});

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: block ? const Size.fromHeight(52) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: child,
    );

    if (block) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }
}
