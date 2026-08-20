import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'person.dart';
import 'services/person_storage.dart';
import 'services/face_share_id_service.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() =>
      _RegisterFaceScreenState();
}

class _RegisterFaceScreenState
    extends State<RegisterFaceScreen> {
  final ImagePicker _picker = ImagePicker();

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: false,
      enableContours: false,
      enableClassification: false,
    ),
  );

  final TextEditingController _nameController =
      TextEditingController();

  File? _selectedImage;

  bool _isChecking = false;
  bool _isSaving = false;

  int _detectedFaces = 0;

  @override
  void dispose() {
    _faceDetector.close();
    _nameController.dispose();
    super.dispose();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
        _detectedFaces = 0;
      });

      await _checkFace();
    } catch (e) {
      _showMessage(
        'Unable to open camera.',
      );
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> _chooseFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
        _detectedFaces = 0;
      });

      await _checkFace();
    } catch (e) {
      _showMessage(
        'Unable to open gallery.',
      );
    }
  }

  // ============================================================
  // FACE DETECTION
  // ============================================================

  Future<void> _checkFace() async {
    if (_selectedImage == null) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final InputImage inputImage =
          InputImage.fromFile(_selectedImage!);

      final List<Face> faces =
          await _faceDetector.processImage(
        inputImage,
      );

      if (!mounted) return;

      setState(() {
        _detectedFaces = faces.length;
        _isChecking = false;
      });

      if (faces.isEmpty) {
        _showMessage(
          'No face detected. Please choose a clear photo of yourself.',
        );
      } else if (faces.length > 1) {
        _showMessage(
          'Multiple faces detected. Please use a photo with only your face.',
        );
      } else {
        _showMessage(
          'Face detected successfully.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });

      _showMessage(
        'Face detection failed.',
      );
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _registerFace() async {
    if (_selectedImage == null) {
      _showMessage(
        'Please select a photo first.',
      );
      return;
    }

    final name =
        _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'Please enter your name.',
      );
      return;
    }

    if (_detectedFaces != 1) {
      _showMessage(
        'Please use a photo containing exactly one face.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ----------------------------------------------------------
      // Initialize storage
      // ----------------------------------------------------------

      await PersonStorage.instance.initialize();

      // ----------------------------------------------------------
      // Get the current user's FaceShare ID
      // ----------------------------------------------------------

      final faceShareUserId =
          await FaceShareIdService.instance
              .createOrGetFaceShareId();

      // ----------------------------------------------------------
      // Check whether this user is already registered
      // ----------------------------------------------------------

      final existing =
          PersonStorage.instance
              .getPersonByFaceShareId(
        faceShareUserId,
      );

      final person = Person(
        id: existing?.id ??
            DateTime.now()
                .millisecondsSinceEpoch
                .toString(),

        name: name,

        imagePath:
            _selectedImage!.path,

        // Actual face embedding will be added
        // when we integrate the recognition model.
        faceEmbedding:
            existing?.faceEmbedding ??
                <double>[],

        faceShareUserId:
            faceShareUserId,

        // User has explicitly registered,
        // so sharing is enabled by default.
        sharingEnabled: true,
      );

      if (existing == null) {
        await PersonStorage.instance
            .addPerson(person);
      } else {
        await PersonStorage.instance
            .updatePerson(person);
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showRegisteredDialog(
        person,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        'Could not register your face.',
      );

      debugPrint(
        'Face registration error: $e',
      );
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  void _showRegisteredDialog(
    Person person,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 10),
              Text(
                'Face Registered',
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${person.name}!',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Your FaceShare identity is ready.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF1F5F9),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FaceShare ID',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      person.faceShareUserId,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF2563EB),
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
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
          'Register My Face',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight:
                FontWeight.bold,
          ),
        ),
        foregroundColor:
            const Color(0xFF0F172A),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Your FaceShare Profile',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Register your face so FaceShare can identify you in photos.',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 25),

              // --------------------------------------------------
              // NAME
              // --------------------------------------------------

              const Text(
                'Your Name',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller:
                    _nameController,
                decoration:
                    InputDecoration(
                  hintText:
                      'Enter your name',
                  prefixIcon:
                      const Icon(
                    Icons.person_outline,
                  ),
                  filled: true,
                  fillColor:
                      Colors.white,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // --------------------------------------------------
              // PHOTO
              // --------------------------------------------------

              Container(
                width:
                    double.infinity,
                height: 300,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFE2E8F0),
                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                ),
                clipBehavior:
                    Clip.antiAlias,
                child:
                    _selectedImage == null
                        ? const Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              Icon(
                                Icons
                                    .face_retouching_natural,
                                size: 70,
                                color:
                                    Color(
                                  0xFF94A3B8,
                                ),
                              ),
                              SizedBox(
                                height: 15,
                              ),
                              Text(
                                'No face photo selected',
                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFF64748B,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
              ),

              const SizedBox(height: 15),

              // --------------------------------------------------
              // FACE STATUS
              // --------------------------------------------------

              if (_isChecking)
                const Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        Color(0xFF2563EB),
                  ),
                )
              else if (_selectedImage !=
                  null)
                _buildFaceStatus(),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // CAMERA + GALLERY
              // --------------------------------------------------

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _isChecking
                              ? null
                              : _takePhoto,
                      icon: const Icon(
                        Icons
                            .camera_alt_outlined,
                      ),
                      label:
                          const Text(
                        'Camera',
                      ),
                      style:
                          OutlinedButton
                              .styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _isChecking
                              ? null
                              : _chooseFromGallery,
                      icon: const Icon(
                        Icons
                            .photo_library_outlined,
                      ),
                      label:
                          const Text(
                        'Gallery',
                      ),
                      style:
                          OutlinedButton
                              .styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // --------------------------------------------------
              // REGISTER BUTTON
              // --------------------------------------------------

              SizedBox(
                width:
                    double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _isSaving ||
                              _isChecking
                          ? null
                          : _registerFace,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .face_retouching_natural,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Registering...'
                        : 'Register My Face',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF2563EB,
                    ),
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 17,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------
              // PRIVACY INFO
              // --------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.all(
                  15,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .privacy_tip_outlined,
                      color:
                          Color(0xFF2563EB),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your face registration is associated with your FaceShare ID. Only use this feature with your own face and with appropriate permission from others.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Color(0xFF475569),
                        ),
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

  // ============================================================
  // FACE STATUS WIDGET
  // ============================================================

  Widget _buildFaceStatus() {
    final bool valid =
        _detectedFaces == 1;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: valid
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFFEDD5),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            valid
                ? Icons.check_circle
                : Icons.warning_amber_rounded,
            color: valid
                ? const Color(0xFF16A34A)
                : const Color(0xFFEA580C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              valid
                  ? 'Exactly one face detected. Ready to register.'
                  : _detectedFaces == 0
                      ? 'No face detected.'
                      : '$_detectedFaces faces detected. Please use a photo with only your face.',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                color: valid
                    ? const Color(
                        0xFF166534,
                      )
                    : const Color(
                        0xFF9A3412,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}