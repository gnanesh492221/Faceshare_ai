import 'dart:io';

import 'package:flutter/material.dart';

import 'received_photo.dart';
import 'services/received_photo_service.dart';
import 'services/received_storage.dart';

class ReceivedPhotosScreen extends StatefulWidget {
  const ReceivedPhotosScreen({
    super.key,
  });

  @override
  State<ReceivedPhotosScreen> createState() =>
      _ReceivedPhotosScreenState();
}

class _ReceivedPhotosScreenState
    extends State<ReceivedPhotosScreen> {
  final ReceivedStorage _storage =
      ReceivedStorage.instance;

  final ReceivedPhotoService _service =
      ReceivedPhotoService.instance;

  List<ReceivedPhoto> _photos = [];

  bool _isLoading = true;
  bool _isSyncing = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadPhotos();
  }

  // ============================================================
  // LOAD + SYNC
  // ============================================================

  Future<void> _loadPhotos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _storage.initialize();

      // --------------------------------------------------------
      // FIRST SHOW LOCAL PHOTOS
      // --------------------------------------------------------

      final List<ReceivedPhoto> localPhotos =
          _storage.getPhotos();

      if (mounted) {
        setState(() {
          _photos = localPhotos;
        });
      }

      // --------------------------------------------------------
      // SYNC FIREBASE
      // --------------------------------------------------------

      await _syncPhotos();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load received photos.';
      });
    }
  }

  // ============================================================
  // FIREBASE SYNC
  // ============================================================

  Future<void> _syncPhotos() async {
    if (_isSyncing) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await _service.syncForCurrentUser();

      await _storage.initialize();

      final List<ReceivedPhoto> photos =
          _storage.getPhotos();

      if (!mounted) return;

      setState(() {
        _photos = photos;
      });
    } catch (e) {
      // Local photos should still remain visible.
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshPhotos() async {
    await _syncPhotos();

    if (!mounted) return;

    await _storage.initialize();

    setState(() {
      _photos = _storage.getPhotos();
    });
  }

  // ============================================================
  // DELETE PHOTO
  // ============================================================

  Future<void> _deletePhoto(
    ReceivedPhoto photo,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete photo?',
          ),
          content: const Text(
            'This photo will be removed from your device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storage.deletePhoto(
        photo.id,
      );

      if (!mounted) return;

      setState(() {
        _photos.removeWhere(
          (item) => item.id == photo.id,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Photo deleted.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete photo.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE ALL
  // ============================================================

  Future<void> _deleteAllPhotos() async {
    if (_photos.isEmpty) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete all photos?',
          ),
          content: Text(
            'This will remove all ${_photos.length} received photos from this device.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Delete all',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _storage.clearAll();

      if (!mounted) return;

      setState(() {
        _photos.clear();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'All received photos deleted.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to delete photos.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // OPEN PHOTO
  // ============================================================

  void _openPhoto(
    ReceivedPhoto photo,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ReceivedPhotoViewer(
          photo: photo,
          onDelete: () async {
            Navigator.pop(context);

            await _deletePhoto(photo);
          },
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final DateTime now =
        DateTime.now();

    final Duration difference =
        now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inDays == 0) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    final String day =
        date.day.toString().padLeft(2, '0');

    final String month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      backgroundColor:
          theme.colorScheme.surface,

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            theme.colorScheme.surface,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Received Photos',
              style: TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            if (!_isLoading)
              Text(
                '${_photos.length} photo${_photos.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w400,
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
          ],
        ),

        actions: [
          if (_isSyncing)
            const Padding(
              padding:
                  EdgeInsets.all(18),
              child: SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Sync',
              onPressed: _syncPhotos,
              icon: const Icon(
                Icons.sync_rounded,
              ),
            ),

          if (_photos.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value ==
                    'delete_all') {
                  _deleteAllPhotos();
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(
                          Icons
                              .delete_outline,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete all',
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_photos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshPhotos,
      child: GridView.builder(
        padding:
            const EdgeInsets.all(16),
        physics:
            const AlwaysScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: _photos.length,
        itemBuilder: (
          context,
          index,
        ) {
          final ReceivedPhoto photo =
              _photos[index];

          return _PhotoCard(
            photo: photo,
            formattedDate:
                _formatDate(
              photo.receivedAt,
            ),
            onTap: () {
              _openPhoto(photo);
            },
            onDelete: () {
              _deletePhoto(photo);
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final ThemeData theme =
        Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshPhotos,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.28,
          ),

          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: theme
                .colorScheme
                .primary
                .withValues(
                  alpha: 0.45,
                ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              'No received photos',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w700,
                color: theme
                    .colorScheme
                    .onSurface,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 40,
            ),
            child: Text(
              'Photos shared with you will appear here.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: FilledButton.icon(
              onPressed: _syncPhotos,
              icon: const Icon(
                Icons.sync_rounded,
              ),
              label: const Text(
                'Check for new photos',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme
                  .colorScheme
                  .error,
            ),

            const SizedBox(height: 16),

            Text(
              _errorMessage!,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _loadPhotos,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Try again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PHOTO CARD
// ================================================================

class _PhotoCard extends StatelessWidget {
  final ReceivedPhoto photo;
  final String formattedDate;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoCard({
    required this.photo,
    required this.formattedDate,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final File imageFile =
        File(photo.imagePath);

    return Material(
      color: theme
          .colorScheme
          .surfaceContainerHighest,
      borderRadius:
          BorderRadius.circular(20),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageFile.existsSync()
                      ? Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: theme
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Icon(
                            Icons
                                .broken_image_outlined,
                            size: 42,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black
                          .withValues(
                        alpha: 0.55,
                      ),
                      shape:
                          const CircleBorder(),
                      child: InkWell(
                        customBorder:
                            const CircleBorder(),
                        onTap: onDelete,
                        child: const Padding(
                          padding:
                              EdgeInsets.all(8),
                          child: Icon(
                            Icons
                                .delete_outline,
                            size: 18,
                            color:
                                Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration:
                            BoxDecoration(
                          color: theme
                              .colorScheme
                              .primaryContainer,
                          shape:
                              BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          size: 17,
                          color: theme
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          photo.senderName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .schedule_outlined,
                        size: 14,
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),

                      const SizedBox(width: 5),

                      Expanded(
                        child: Text(
                          formattedDate,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FULL SCREEN VIEWER
// ================================================================

class _ReceivedPhotoViewer
    extends StatelessWidget {
  final ReceivedPhoto photo;
  final VoidCallback onDelete;

  const _ReceivedPhotoViewer({
    required this.photo,
    required this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final File file =
        File(photo.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              photo.senderName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            Text(
              _formatDate(
                photo.receivedAt,
              ),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
            ),
          ),
        ],
      ),

      body: Center(
        child: file.existsSync()
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                ),
              )
            : const Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Image is no longer available.',
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    final String day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final String month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    final String hour =
        date.hour.toString().padLeft(
              2,
              '0',
            );

    final String minute =
        date.minute.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year} • '
        '$hour:$minute';
  }
}