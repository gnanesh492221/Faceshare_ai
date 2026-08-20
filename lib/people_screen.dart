import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'person.dart';
import 'person_photos_screen.dart';
import 'services/face_recognition_service.dart';
import 'services/person_storage.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() =>
      _PeopleScreenState();
}

class _PeopleScreenState
    extends State<PeopleScreen> {
  final ImagePicker _picker =
      ImagePicker();

  final PersonStorage _storage =
      PersonStorage.instance;

  final FaceRecognitionService _faceService =
      FaceRecognitionService.instance;

  final List<Person> _people = [];

  bool _isLoading = true;
  bool _isAddingPerson = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    try {
      await _storage.initialize();
      await _faceService.initialize();

      final savedPeople =
          _storage.getPeople();

      if (!mounted) return;

      setState(() {
        _people
          ..clear()
          ..addAll(savedPeople);

        _isLoading = false;
      });
    } catch (e) {
      debugPrint(
        'People initialization error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load people.',
      );
    }
  }

  // ============================================================
  // ADD PERSON
  // ============================================================

  Future<void> _addPerson() async {
    if (_isAddingPerson) return;

    final controller =
        TextEditingController();

    final String? name =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add Person',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              labelText: 'Person name',
              hintText: 'Example: Arun',
              border:
                  OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value =
                    controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(
                    dialogContext,
                    value,
                  );
                }
              },
              child:
                  const Text('Next'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted ||
        name == null ||
        name.trim().isEmpty) {
      return;
    }

    setState(() {
      _isAddingPerson = true;
    });

    try {
      // ========================================================
      // TAKE REGISTRATION PHOTO
      // ========================================================

      final XFile? pickedImage =
          await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice:
            CameraDevice.front,
      );

      if (pickedImage == null) {
        return;
      }

      if (!mounted) return;

      // ========================================================
      // DETECT FACE
      // ========================================================

      _showMessage(
        'Analyzing registration photo...',
      );

      final faces =
          await _faceService.detectFaces(
        pickedImage.path,
      );

      if (!mounted) return;

      // ========================================================
      // NO FACE
      // ========================================================

      if (faces.isEmpty) {
        _showMessage(
          'No face detected. '
          'Please take a clear front-facing photo.',
        );
        return;
      }

      // ========================================================
      // MULTIPLE FACES
      // ========================================================

      if (faces.length > 1) {
        _showMessage(
          'Multiple faces detected. '
          'Please register one person at a time.',
        );
        return;
      }

      // ========================================================
      // CREATE EMBEDDING
      // ========================================================

      _showMessage(
        'Creating face profile...',
      );

      final embedding =
          await _faceService.createEmbedding(
        faces.first,
        pickedImage.path,
      );

      if (!mounted) return;

      final embeddingList =
          embedding.toList();

      // ========================================================
      // VALIDATE EMBEDDING
      // ========================================================

      if (embeddingList.isEmpty) {
        _showMessage(
          'Unable to create a face profile. '
          'Please try again.',
        );
        return;
      }

      debugPrint(
        'Registration embedding length: '
        '${embeddingList.length}',
      );

      // ========================================================
      // CHECK DUPLICATE
      // ========================================================

      Person? existingPerson;

      for (final existing
          in _people) {
        if (existing.faceEmbedding.isEmpty) {
          continue;
        }

        try {
          final double similarity =
              _faceService.compare(
            existing.faceEmbedding,
            embeddingList,
          );

          debugPrint(
            'Registration comparison → '
            '${existing.name}: '
            '${similarity.toStringAsFixed(4)}',
          );

          const double duplicateThreshold =
              0.60;

          if (similarity >=
              duplicateThreshold) {
            existingPerson =
                existing;
            break;
          }
        } catch (e) {
          debugPrint(
            'Duplicate comparison error: $e',
          );
        }
      }

      // ========================================================
      // DUPLICATE FOUND
      // ========================================================

      if (existingPerson != null) {
        _showMessage(
          '${existingPerson.name} '
          'is already registered.',
        );
        return;
      }

      // ========================================================
      // CREATE PERSON
      // ========================================================

      final String personId =
          DateTime.now()
              .millisecondsSinceEpoch
              .toString();

      final Person person =
          Person(
        id: personId,
        name: name.trim(),
        imagePath: pickedImage.path,

        // IMPORTANT:
        // This is the registered facial identity.
        faceEmbedding:
            embeddingList,

        faceShareUserId:
            'FS_$personId',

        sharingEnabled: true,
      );

      // ========================================================
      // SAVE PERSON
      // ========================================================

      await _storage.addPerson(
        person,
      );

      if (!mounted) return;

      setState(() {
        _people.add(person);
      });

      // ========================================================
      // SUCCESS
      // ========================================================

      _showSuccessMessage(
        '${person.name} registered successfully!',
      );
    } catch (e) {
      debugPrint(
        'Add person error: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to create face profile.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingPerson = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN PERSON PHOTOS
  // ============================================================

  void _openPersonPhotos(
    Person person,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PersonPhotosScreen(
          person: person,
        ),
      ),
    );
  }

  // ============================================================
  // DELETE PERSON
  // ============================================================

  Future<void> _confirmDelete(
    Person person,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove Person',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to '
            'remove ${person.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true ||
        !mounted) {
      return;
    }

    try {
      await _storage.deletePerson(
        person.id,
      );

      if (!mounted) return;

      setState(() {
        _people.removeWhere(
          (item) =>
              item.id == person.id,
        );
      });

      _showMessage(
        '${person.name} removed.',
      );
    } catch (e) {
      debugPrint(
        'Delete person error: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to remove ${person.name}.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration:
              const Duration(seconds: 3),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccessMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFF16A34A),
          content: Row(
            children: [
              const Icon(
                Icons
                    .check_circle_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
          duration:
              const Duration(seconds: 3),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.all(25),
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFDBEAFE),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .people_alt_rounded,
                size: 55,
                color:
                    Color(0xFF2563EB),
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            const Text(
              'No people registered',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF0F172A),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Register people you frequently '
              'share photos with.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Color(0xFF64748B),
                fontSize: 15,
              ),
            ),
            const SizedBox(
              height: 25,
            ),
            ElevatedButton.icon(
              onPressed:
                  _isAddingPerson
                      ? null
                      : _addPerson,
              icon: const Icon(
                Icons.person_add,
              ),
              label: const Text(
                'Register First Person',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF2563EB,
                ),
                foregroundColor:
                    Colors.white,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color:
                Color(0xFF2563EB),
          ),
          SizedBox(height: 16),
          Text(
            'Loading people...',
            style: TextStyle(
              color:
                  Color(0xFF64748B),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        title: const Text(
          'People',
          style: TextStyle(
            color:
                Color(0xFF0F172A),
            fontWeight:
                FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _people.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  itemCount:
                      _people.length,
                  itemBuilder:
                      (context, index) {
                    final person =
                        _people[index];

                    return _PersonCard(
                      person: person,
                      onTap: () {
                        _openPersonPhotos(
                          person,
                        );
                      },
                      onDelete: () {
                        _confirmDelete(
                          person,
                        );
                      },
                    );
                  },
                ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _isAddingPerson
                ? null
                : _addPerson,
        backgroundColor:
            const Color(0xFF2563EB),
        foregroundColor:
            Colors.white,
        icon: _isAddingPerson
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons
                    .person_add_alt_1,
              ),
        label: Text(
          _isAddingPerson
              ? 'Adding...'
              : 'Add Person',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// PERSON CARD
// ==================================================================

class _PersonCard
    extends StatelessWidget {
  final Person person;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PersonCard({
    required this.person,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool hasFaceProfile =
        person.faceEmbedding.isNotEmpty;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 0,
      color: Colors.white,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            children: [
              // IMAGE
              ClipOval(
                child: Image.file(
                  File(
                    person.imagePath,
                  ),
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      width: 58,
                      height: 58,
                      color:
                          const Color(
                        0xFFDBEAFE,
                      ),
                      child:
                          const Icon(
                        Icons.person,
                        color:
                            Color(
                          0xFF2563EB,
                        ),
                        size: 30,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              // INFORMATION
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(
                          0xFF0F172A,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      children: [
                        Icon(
                          hasFaceProfile
                              ? Icons
                                  .verified_rounded
                              : Icons
                                  .face_retouching_natural,
                          size: 15,
                          color:
                              hasFaceProfile
                                  ? const Color(
                                      0xFF16A34A,
                                    )
                                  : const Color(
                                      0xFF2563EB,
                                    ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Flexible(
                          child: Text(
                            hasFaceProfile
                                ? 'Face profile ready'
                                : 'Face profile missing',
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize:
                                  13,
                              color:
                                  hasFaceProfile
                                      ? const Color(
                                          0xFF16A34A,
                                        )
                                      : const Color(
                                          0xFFDC2626,
                                        ),
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .share_rounded,
                          size: 14,
                          color:
                              Color(
                            0xFF94A3B8,
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          person
                                  .sharingEnabled
                              ? 'FaceShare enabled'
                              : 'Sharing disabled',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            color:
                                Color(
                              0xFF94A3B8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // MENU
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
                onSelected:
                    (value) {
                  if (value ==
                      'delete') {
                    onDelete();
                  }
                },
                itemBuilder:
                    (context) {
                  return const [
                    PopupMenuItem<
                        String>(
                      value:
                          'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline,
                            color:
                                Colors.red,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Remove',
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}