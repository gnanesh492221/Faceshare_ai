import 'dart:io';

import 'package:flutter/material.dart';

import 'photo.dart';
import 'services/photo_storage.dart';

class MyPhotosScreen extends StatefulWidget {
  const MyPhotosScreen({super.key});

  @override
  State<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends State<MyPhotosScreen> {
  final PhotoStorage _photoStorage = PhotoStorage.instance;

  List<FacePhoto> _photos = [];
  bool _isLoading = true;

  static const Color primary = Color(0xFF2563EB);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      await _photoStorage.initialize();

      final photos = _photoStorage.getPhotos();

      if (!mounted) return;

      setState(() {
        _photos = photos.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading photos: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to load photos.');
    }
  }

  Future<void> _deletePhoto(FacePhoto photo) async {
    final confirmed = await _confirmDelete(
      title: 'Delete photo?',
      message:
          'This photo will be permanently removed from My Photos.',
    );

    if (!confirmed) return;

    try {
      await _photoStorage.deletePhoto(photo.id);

      if (!mounted) return;

      setState(() {
        _photos.removeWhere((item) => item.id == photo.id);
      });

      _showMessage('Photo deleted successfully.');
    } catch (e) {
      debugPrint('Delete error: $e');

      if (!mounted) return;

      _showMessage('Unable to delete photo.');
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFDC2626),
              ),
              SizedBox(width: 10),
              Text('Delete photo?'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: textMuted,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _openPhoto(FacePhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoDetailsScreen(
          photo: photo,
          onDelete: () async {
            Navigator.pop(context);
            await _deletePhoto(photo);
          },
        ),
      ),
    );
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

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Photos',
              style: TextStyle(
                color: textDark,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${_photos.length} saved ${_photos.length == 1 ? 'photo' : 'photos'}',
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPhotos,
            icon: const Icon(
              Icons.refresh_rounded,
              color: textDark,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : _photos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPhotos,
                  color: primary,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      10,
                      18,
                      30,
                    ),
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    itemCount: _photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.72,
                    ),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];

                      return _PhotoCard(
                        photo: photo,
                        dateText: _formatDate(
                          photo.createdAt,
                        ),
                        onTap: () => _openPhoto(photo),
                        onDelete: () =>
                            _deletePhoto(photo),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.photo_library_rounded,
                size: 44,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Photos Yet',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photos with recognized people will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Capture Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final FacePhoto photo;
  final String dateText;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoCard({
    required this.photo,
    required this.dateText,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);
    final exists = file.existsSync();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: exists
                          ? Image.file(
                              file,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color:
                                  const Color(0xFFE2E8F0),
                              child: const Center(
                                child: Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 40,
                                  color:
                                      Color(0xFF64748B),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.black.withOpacity(.65),
                        borderRadius:
                            BorderRadius.circular(11),
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius:
                              BorderRadius.circular(11),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.face_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${photo.recognizedPeople.length} '
                            '${photo.recognizedPeople.length == 1 ? 'person' : 'people'}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      photo.recognizedPeople.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoDetailsScreen extends StatelessWidget {
  final FacePhoto photo;
  final VoidCallback onDelete;

  const PhotoDetailsScreen({
    super.key,
    required this.photo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Photo Details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete photo',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: file.existsSync()
                    ? InteractiveViewer(
                        minScale: .8,
                        maxScale: 4,
                        child: Image.file(
                          file,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 70,
                      ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                22,
                22,
                22,
                25,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recognized People',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: photo.recognizedPeople
                        .map(
                          (name) => Chip(
                            avatar: const Icon(
                              Icons.person_rounded,
                              size: 17,
                              color: Color(0xFF2563EB),
                            ),
                            label: Text(name),
                            backgroundColor:
                                const Color(0xFFEFF6FF),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Saved on '
                    '${photo.createdAt.day.toString().padLeft(2, '0')}/'
                    '${photo.createdAt.month.toString().padLeft(2, '0')}/'
                    '${photo.createdAt.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
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