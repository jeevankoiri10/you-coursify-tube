import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copies [url] to the clipboard and confirms with a brief snackbar.
Future<void> copyLink(BuildContext context, String? url) async {
  if (url == null || url.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Link copied to clipboard'),
      duration: Duration(seconds: 2),
    ),
  );
}
