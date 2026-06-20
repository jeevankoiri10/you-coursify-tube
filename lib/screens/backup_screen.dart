import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../state/library_controller.dart';

/// One place for all export / import actions.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.controller});

  final LibraryController controller;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  LibraryController get _c => widget.controller;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportJson() =>
      _run(() => BackupService.export(_c));

  Future<void> _exportCsv() =>
      _run(() => BackupService.exportCsv(_c));

  Future<void> _importJson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import data?'),
        content: const Text(
          'This replaces ALL current folders, links and notes with the '
          'contents of the backup file you pick. Export first if unsure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      final imported = await BackupService.pickAndImport(_c);
      _snack(imported ? 'Data imported.' : 'Import cancelled.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final folders = _c.folders.length;
        final links = _c.library.items.length;
        final notes = _c.library.notes.length;
        return Scaffold(
          appBar: AppBar(title: const Text('Export & Import')),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFF1C1C20),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.dataset_outlined,
                              color: Color(0xFFFF6E6E)),
                          const SizedBox(width: 12),
                          Text(
                            '$folders folders · $links links · $notes notes',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Heading('Backup (recommended)'),
                  _ActionTile(
                    icon: Icons.upload_file,
                    title: 'Export all data (JSON)',
                    subtitle:
                        'A complete backup you can re-import to restore everything.',
                    onTap: _busy ? null : _exportJson,
                  ),
                  _ActionTile(
                    icon: Icons.download,
                    title: 'Import data (JSON)',
                    subtitle: 'Restore from a backup file. Replaces current data.',
                    onTap: _busy ? null : _importJson,
                  ),
                  const SizedBox(height: 20),
                  const _Heading('Spreadsheet'),
                  _ActionTile(
                    icon: Icons.table_chart_outlined,
                    title: 'Export as CSV',
                    subtitle:
                        'A flat list of every link and note for Excel/Sheets. '
                        'Read-only — use JSON to restore.',
                    onTap: _busy ? null : _exportCsv,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Exports open the share sheet so you can save to Files, '
                    'Drive, or send to yourself.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black45,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1C1C20),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0x33FF4D4D),
          child: Icon(icon, color: const Color(0xFFFF4D4D)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
