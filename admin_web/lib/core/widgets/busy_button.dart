import 'package:flutter/material.dart';

/// A main action button that blocks repeat taps while work is running.
class BusyButton extends StatelessWidget {
  const BusyButton({
    required this.label,
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isBusy ? null : onPressed,
        child: isBusy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  semanticsLabel: 'Please wait',
                ),
              )
            : Text(label),
      ),
    );
  }
}
