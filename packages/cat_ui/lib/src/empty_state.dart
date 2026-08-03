import 'package:flutter/material.dart';

/// Centered "nothing to show" placeholder: dimmed illustration above a
/// message. Used wherever a list can legitimately be empty.
class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.60,
            child: Image.asset(
              'assets/images/no-data.png',
              width: 96,
              package: 'cat_ui',
            ),
          ),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
