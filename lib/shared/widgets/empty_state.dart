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
            // Source art is 1024², drawn at 96: without cacheWidth Flutter
            // decodes the full bitmap into memory for a thumbnail. 2x covers
            // the highest-DPI display the app runs on.
            child: Image.asset(
              'assets/images/no-data.png',
              width: 96,
              cacheWidth: 192,
            ),
          ),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
