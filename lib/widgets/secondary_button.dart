import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool block;

  const SecondaryButton({super.key, required this.onPressed, required this.child, this.block = true});

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: block ? const Size.fromHeight(48) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: child,
    );

    if (block) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }
}
