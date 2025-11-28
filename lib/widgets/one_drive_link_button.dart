// lib/widgets/one_drive_link_button.dart

import 'package:flutter/material.dart';

class OneDriveLinkButton extends StatelessWidget {
  final String? url;
  final VoidCallback onPressed;

  const OneDriveLinkButton({
    super.key,
    required this.url,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = url != null && url!.trim().isNotEmpty;

    return IconButton(
      icon: Icon(
        Icons.cloud_outlined,
        color: hasLink ? Colors.blueAccent : Colors.grey.shade600,
      ),
      tooltip: hasLink
          ? 'Otwórz / edytuj link OneDrive'
          : 'Dodaj link do OneDrive',
      onPressed: onPressed,
    );
  }
}
