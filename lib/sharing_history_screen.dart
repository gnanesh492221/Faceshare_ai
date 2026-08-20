import 'dart:io';

import 'package:flutter/material.dart';

import 'services/sharing_storage.dart';
import 'sharing_history.dart';

class SharingHistoryScreen extends StatefulWidget {
  const SharingHistoryScreen({
    super.key,
  });

  @override
  State<SharingHistoryScreen> createState() =>
      _SharingHistoryScreenState();
}

class _SharingHistoryScreenState
    extends State<SharingHistoryScreen> {
  final SharingStorage _storage =
      SharingStorage.instance;

  List<SharingHistory> _history = [];
  bool _loading = true;

  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      await _storage.initialize();

      final history = _storage.getHistory();

      if (!mounted) return;

      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      debugPrint('History loading error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Unable to load sharing history.',
      );
    }
  }

  Future<void> _deleteHistory(
    SharingHistory item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete history?',
          ),
          content: const Text(
            'This sharing record will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _storage.deleteHistory(item.id);

      if (!mounted) return;

      setState(() {
        _history.removeWhere(
          (history) => history.id == item.id,
        );
      });

      _showMessage('History deleted.');
    } catch (e) {
      debugPrint('Delete history error: $e');

      if (!mounted) return;

      _showMessage('Unable to delete history.');
    }
  }

  Future<void> _clearHistory() async {
    if (_history.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Clear sharing history?',
          ),
          content: const Text(
            'All sharing history records will be permanently deleted. Your original photos will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _storage.clearHistory();

      if (!mounted) return;

      setState(() {
        _history.clear();
      });

      _showMessage('Sharing history cleared.');
    } catch (e) {
      debugPrint('Clear history error: $e');

      if (!mounted) return;

      _showMessage(
        'Unable to clear sharing history.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  String _formatDate(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Sharing History',
              style: TextStyle(
                color: textDark,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_history.length} sharing ${_history.length == 1 ? 'record' : 'records'}',
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _clearHistory,
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Color(0xFFDC2626),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : _history.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      10,
                      16,
                      30,
                    ),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];

                      return _buildHistoryCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius:
                    BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 44,
                color: primary,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Sharing History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photos you share with people will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    SharingHistory item,
  ) {
    final file = File(item.imagePath);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(15),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 76,
                      height: 76,
                      color:
                          const Color(0xFFE2E8F0),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF64748B),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFEFF6FF),
                          borderRadius:
                              BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 14,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shared with '
                          '${item.sharedWith.length} '
                          '${item.sharedWith.length == 1 ? 'person' : 'people'}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 14,
                            color: textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.sharedWith.join(', '),
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatDate(item.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'History options',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF64748B),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteHistory(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}