import 'dart:io';

import 'package:flutter/material.dart';

import 'person.dart';
import 'photo.dart';
import 'services/photo_storage.dart';

class PersonPhotosScreen extends StatefulWidget {
  final Person person;

  const PersonPhotosScreen({
    super.key,
    required this.person,
  });

  @override
  State<PersonPhotosScreen> createState() =>
      _PersonPhotosScreenState();
}

class _PersonPhotosScreenState
    extends State<PersonPhotosScreen> {
  final PhotoStorage _photoStorage =
      PhotoStorage.instance;

  List<FacePhoto> _photos = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      await _photoStorage.initialize();

      final photos =
          _photoStorage.getPhotosForPerson(
        widget.person.name,
      );

      // Newest first.
      photos.sort(
        (a, b) =>
            b.createdAt.compareTo(a.createdAt),
      );

      if (!mounted) return;

      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'Person photos loading error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load photos.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: Text(
          widget.person.name,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          Padding(
            padding:
                const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_photos.length} photos',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            )
          : _photos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPhotos,
                  child: GridView.builder(
                    padding:
                        const EdgeInsets.all(12),
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _photos.length,
                    itemBuilder:
                        (context, index) {
                      final photo =
                          _photos[index];

                      return _PhotoTile(
                        photo: photo,
                        onTap: () {
                          _openPhoto(
                            context,
                            index,
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(25),
              decoration:
                  const BoxDecoration(
                color: Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 55,
                color: Color(0xFF2563EB),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'No photos of ${widget.person.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'When this person is recognized in a photo, it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPEN PHOTO
  // ============================================================

  void _openPhoto(
    BuildContext context,
    int index,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullPhotoScreen(
          photos: _photos,
          initialIndex: index,
        ),
      ),
    );
  }
}

// ==================================================================
// PHOTO TILE
// ==================================================================

class _PhotoTile extends StatelessWidget {
  final FacePhoto photo;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(photo.imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: const Color(0xFFE2E8F0),
        child: Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder:
              (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFF64748B),
                size: 32,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================================================================
// FULL PHOTO VIEW
// ==================================================================

class _FullPhotoScreen extends StatefulWidget {
  final List<FacePhoto> photos;
  final int initialIndex;

  const _FullPhotoScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_FullPhotoScreen> createState() =>
      _FullPhotoScreenState();
}

class _FullPhotoScreenState
    extends State<_FullPhotoScreen> {
  late PageController _controller;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex =
        widget.initialIndex;

    _controller = PageController(
      initialPage:
          widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),

      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final photo =
              widget.photos[index];

          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.file(
                File(photo.imagePath),
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 60,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}