// lib/widgets/one_drive_link_button.dart

import 'package:flutter/material.dart';

class OneDriveLinkButton extends StatelessWidget {
  final String? url;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const OneDriveLinkButton({
    super.key,
    required this.url,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = url != null && url!.trim().isNotEmpty;

    return GestureDetector(
      onLongPress: onLongPress,
      child: IconButton(
        icon: Icon(
          Icons.cloud_outlined,
          color: hasLink ? Colors.blueAccent : Colors.grey.shade600,
        ),
        tooltip: hasLink ? 'Open link' : 'Add link',
        onPressed: onTap,
      ),
    );
  }
}
