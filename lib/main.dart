import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'people_screen.dart';
import 'face_scan_screen.dart';
import 'sharing_history_screen.dart';
import 'sharing_permission_screen.dart';
import 'register_face_screen.dart';
import 'my_photos_screen.dart';
import 'received_photos_screen.dart';
import 'services/face_share_id_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final faceShareId =
      await FaceShareIdService.instance.createOrGetFaceShareId();

  debugPrint('FaceShare ID: $faceShareId');

  runApp(const FaceShareAI());
}

// ============================================================
// APP
// ============================================================

class FaceShareAI extends StatelessWidget {
  const FaceShareAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FaceShare AI',

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
        ),

        scaffoldBackgroundColor:
            const Color(0xFFF6F8FC),
      ),

      home: const HomeScreen(),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  late final FaceDetector _faceDetector;

  File? _selectedImage;

  bool _isAnalyzing = false;

  int _currentIndex = 0;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  // ==========================================================
  // MESSAGE
  // ==========================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ==========================================================
  // CAMERA
  // ==========================================================

  Future<void> _openCamera() async {
    try {
      final XFile? image =
          await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
      });

      _showPhotoPreview();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not open camera.',
      );
    }
  }

  // ==========================================================
  // GALLERY
  // ==========================================================

  Future<void> _openGallery() async {
    try {
      final XFile? image =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = File(image.path);
      });

      _showPhotoPreview();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not open gallery.',
      );
    }
  }

  // ==========================================================
  // PHOTO PREVIEW
  // ==========================================================

  void _showPhotoPreview() {
    if (_selectedImage == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (sheetContext) {
        return Container(
          height:
              MediaQuery.of(context).size.height *
                  0.82,

          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),

          child: Column(
            children: [
              const SizedBox(height: 12),

              const _BottomSheetHandle(),

              const SizedBox(height: 20),

              const Text(
                'Photo Preview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Ready for AI face analysis',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),

                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(24),

                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24,
                ),

                child: SizedBox(
                  width: double.infinity,

                  child:
                      ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () {
                            _analyzePhoto(
                              sheetContext,
                            );
                          },

                    icon: const Icon(
                      Icons.auto_awesome,
                    ),

                    label: const Text(
                      'Analyze with AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.bold,
                      ),
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
                        vertical: 17,
                      ),

                      elevation: 0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // FACE ANALYSIS
  // ==========================================================

  Future<void> _analyzePhoto(
    BuildContext sheetContext,
  ) async {
    if (_selectedImage == null ||
        _isAnalyzing) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    Navigator.pop(sheetContext);

    try {
      final InputImage inputImage =
          InputImage.fromFile(
        _selectedImage!,
      );

      final List<Face> faces =
          await _faceDetector.processImage(
        inputImage,
      );

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showFaceDetectionResult(
        faces.length,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
      });

      _showMessage(
        'Face detection failed. Please try again.',
      );
    }
  }

  // ==========================================================
  // DETECTION RESULT
  // ==========================================================

  void _showFaceDetectionResult(
    int faceCount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (resultContext) {
        final bool foundFaces =
            faceCount > 0;

        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            28,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const _BottomSheetHandle(),

              const SizedBox(height: 24),

              Container(
                width: 76,
                height: 76,

                decoration:
                    BoxDecoration(
                  color: foundFaces
                      ? const Color(
                          0xFFDCFCE7)
                      : const Color(
                          0xFFFEE2E2),

                  shape: BoxShape.circle,
                ),

                child: Icon(
                  foundFaces
                      ? Icons
                          .face_retouching_natural
                      : Icons.face_outlined,

                  color: foundFaces
                      ? const Color(
                          0xFF16A34A)
                      : const Color(
                          0xFFDC2626),

                  size: 38,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                foundFaces
                    ? 'Faces Detected'
                    : 'No Faces Found',

                style:
                    const TextStyle(
                  fontSize: 23,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                foundFaces
                    ? 'FaceShare AI found '
                        '$faceCount '
                        '${faceCount == 1 ? 'person' : 'people'} '
                        'in your photo.'
                    : 'Try another photo containing people.',

                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color:
                      Color(0xFF64748B),
                ),
              ),

              if (foundFaces) ...[
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,

                  padding:
                      const EdgeInsets.all(
                    17,
                  ),

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFFEFF6FF),
                        Color(0xFFF5F3FF),
                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .all(10),

                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child:
                            const Icon(
                          Icons
                              .people_alt_rounded,
                          color:
                              Color(0xFF2563EB),
                        ),
                      ),

                      const SizedBox(
                        width: 13,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            Text(
                              '$faceCount '
                              '${faceCount == 1 ? 'person' : 'people'} found',

                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            const Text(
                              'Ready for smart sharing',
                              style:
                                  TextStyle(
                                color:
                                    Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons
                            .check_circle,
                        color:
                            Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      resultContext,
                    );

                    if (foundFaces) {
                      _showShareScreen();
                    }
                  },

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
                      vertical: 16,
                    ),

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                  ),

                  child: Text(
                    foundFaces
                        ? 'Continue to Smart Sharing'
                        : 'Close',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // SMART SHARING
  // ==========================================================

  void _showShareScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (shareContext) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            28,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Center(
                child:
                    _BottomSheetHandle(),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      11,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFEFF6FF,
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),

                    child:
                        const Icon(
                      Icons.auto_awesome,
                      color:
                          Color(0xFF2563EB),
                    ),
                  ),

                  const SizedBox(width: 13),

                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        'Smart Sharing',
                        style:
                            TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              Color(0xFF0F172A),
                        ),
                      ),

                      SizedBox(height: 3),

                      Text(
                        'Choose your recipients',
                        style:
                            TextStyle(
                          color:
                              Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const _SharePerson(
                name: 'Arun',
                selected: true,
              ),

              const _SharePerson(
                name: 'Priya',
                selected: true,
              ),

              const SizedBox(height: 8),

              Container(
                padding:
                    const EdgeInsets.all(
                  14,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF8FAFC,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),

                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color:
                          Color(0xFF475569),
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Only opted-in FaceShare users can receive shared photos.',
                        style:
                            TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color:
                              Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,

                child:
                    ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                      shareContext,
                    );

                    _showSharedMessage();
                  },

                  icon: const Icon(
                    Icons.send_rounded,
                    size: 19,
                  ),

                  label: const Text(
                    'Share Automatically',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
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
                      vertical: 16,
                    ),

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // SHARED MESSAGE
  // ==========================================================

  void _showSharedMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
            ),
            SizedBox(width: 10),
            Text(
              'Photo shared successfully.',
            ),
          ],
        ),

        behavior:
            SnackBarBehavior.floating,

        margin:
            const EdgeInsets.all(16),

        backgroundColor:
            const Color(0xFF16A34A),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  void _openPeople() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PeopleScreen(),
      ),
    );
  }

  void _openFaceScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const FaceScanScreen(),
      ),
    );
  }

  void _openSharingHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SharingHistoryScreen(),
      ),
    );
  }

  void _openMyPhotos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MyPhotosScreen(),
      ),
    );
  }

  void _openReceivedPhotos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ReceivedPhotosScreen(),
      ),
    );
  }

  void _openRegisterFace() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RegisterFaceScreen(),
      ),
    );
  }

  void _openSharingPermission() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const SharingPermissionScreen(),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  void _onBottomNavigationTap(
    int index,
  ) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        break;

      case 1:
        _openMyPhotos();
        break;

      case 2:
        _openSharingHistory();
        break;

      case 3:
        _openRegisterFace();
        break;
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F8FC),

      body: SafeArea(
        bottom: false,

        child: Stack(
          children: [
            CustomScrollView(
              physics:
                  const BouncingScrollPhysics(),

              slivers: [
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,

                    // IMPORTANT:
                    // keeps content safely above
                    // floating navigation.
                    105,
                  ),

                  sliver: SliverList(
                    delegate:
                        SliverChildListDelegate(
                      [
                        _buildHeader(),

                        const SizedBox(
                          height: 28,
                        ),

                        _buildGreeting(),

                        const SizedBox(
                          height: 22,
                        ),

                        _buildHeroCard(),

                        const SizedBox(
                          height: 20,
                        ),

                        // No Shared / Received /
                        // People statistics bar.

                        _buildSectionHeader(
                          'Quick Actions',
                          'View all',
                          _showAllActions,
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        _buildQuickActions(),

                        const SizedBox(
                          height: 30,
                        ),

                        _buildSectionHeader(
                          'Recent Activity',
                          'History',
                          _openSharingHistory,
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        _buildRecentActivity(),

                        const SizedBox(
                          height: 28,
                        ),

                        _buildProfileCard(),

                        const SizedBox(
                          height: 30,
                        ),

                        _buildHowItWorks(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (_isAnalyzing)
              Container(
                color: Colors.black54,

                child: const Center(
                  child: Card(
                    elevation: 10,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.all(
                        Radius.circular(24),
                      ),
                    ),

                    child: Padding(
                      padding:
                          EdgeInsets.all(28),

                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,

                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,

                            child:
                                CircularProgressIndicator(
                              strokeWidth: 4,
                              color:
                                  Color(
                                0xFF2563EB,
                              ),
                            ),
                          ),

                          SizedBox(height: 20),

                          Text(
                            'AI is analyzing faces',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 6),

                          Text(
                            'Please wait...',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF64748B,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      bottomNavigationBar:
          _buildBottomNavigation(),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 47,
          height: 47,

          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFF2563EB),
                Color(0xFF4F46E5),
              ],
            ),

            borderRadius:
                BorderRadius.circular(
              15,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    const Color(
                  0xFF2563EB,
                ).withValues(
                  alpha: 0.20,
                ),

                blurRadius: 15,

                offset:
                    const Offset(0, 6),
              ),
            ],
          ),

          child: const Icon(
            Icons.face_retouching_natural,
            color: Colors.white,
            size: 26,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'FaceShare',
                style:
                    TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              SizedBox(height: 1),

              Text(
                'AI powered sharing',
                style:
                    TextStyle(
                  fontSize: 11,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        _HeaderIconButton(
          icon:
              Icons.notifications_none_rounded,

          onTap: () {
            _showMessage(
              'No new notifications.',
            );
          },
        ),

        const SizedBox(width: 8),

        // PROFESSIONAL PROFILE BUTTON
        _ProfileNavigator(
          onTap: _openRegisterFace,
        ),
      ],
    );
  }

  // ==========================================================
  // GREETING
  // ==========================================================

  Widget _buildGreeting() {
    return const Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          'Good evening, Gnanesh 👋',

          style: TextStyle(
            fontSize: 27,
            fontWeight:
                FontWeight.w800,
            color:
                Color(0xFF0F172A),
            letterSpacing: -0.6,
          ),
        ),

        SizedBox(height: 7),

        Text(
          'Capture once. Share intelligently.',
          style: TextStyle(
            fontSize: 14,
            color:
                Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // HERO CARD
  // ==========================================================

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(23),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,

          colors: [
            Color(0xFF2563EB),
            Color(0xFF4F46E5),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          28,
        ),

        boxShadow: [
          BoxShadow(
            color:
                const Color(
              0xFF2563EB,
            ).withValues(
              alpha: 0.25,
            ),

            blurRadius: 25,

            offset:
                const Offset(0, 12),
          ),
        ],
      ),

      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -45,

            child: Container(
              width: 155,
              height: 155,

              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withValues(
                  alpha: 0.07,
                ),

                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            right: 30,
            bottom: -65,

            child: Container(
              width: 130,
              height: 130,

              decoration:
                  BoxDecoration(
                color: Colors.white
                    .withValues(
                  alpha: 0.05,
                ),

                shape:
                    BoxShape.circle,
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withValues(
                    alpha: 0.14,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                ),

                child: const Row(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Colors.white,
                    ),

                    SizedBox(width: 5),

                    Text(
                      'AI READY',
                      style:
                          TextStyle(
                        fontSize: 10,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Scan a group photo',

                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Colors.white,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'FaceShare AI finds people automatically\nand helps you share with the right ones.',

                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color:
                      Colors.white70,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _openCamera,

                      icon:
                          const Icon(
                        Icons
                            .camera_alt_rounded,
                        size: 19,
                      ),

                      label:
                          const Text(
                        'Scan Photo',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors.white,

                        foregroundColor:
                            const Color(
                          0xFF2563EB,
                        ),

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                        ),

                        elevation: 0,

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

                  const SizedBox(width: 10),

                  _HeroIconButton(
                    icon:
                        Icons
                            .photo_library_outlined,
                    onTap:
                        _openGallery,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION HEADER
  // ==========================================================

  Widget _buildSectionHeader(
    String title,
    String action,
    VoidCallback onTap,
  ) {
    return Row(
      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            color:
                Color(0xFF0F172A),
          ),
        ),

        const Spacer(),

        GestureDetector(
          onTap: onTap,

          child: Row(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Text(
                action,
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Color(0xFF2563EB),
                ),
              ),

              const SizedBox(width: 4),

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 11,
                color:
                    Color(0xFF2563EB),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // QUICK ACTIONS
  // ==========================================================

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder:
          (context, constraints) {
        const double spacing = 12;

        final double width =
            (constraints.maxWidth -
                    spacing) /
                2;

        return GridView.builder(
          shrinkWrap: true,

          physics:
              const NeverScrollableScrollPhysics(),

          itemCount: 4,

          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,

            crossAxisSpacing:
                spacing,

            mainAxisSpacing:
                spacing,

            childAspectRatio:
                width / 120,
          ),

          itemBuilder:
              (context, index) {
            switch (index) {
              case 0:
                return _ActionCard(
                  icon:
                      Icons.people_alt_rounded,
                  title:
                      'People',
                  subtitle:
                      'Manage friends',
                  iconColor:
                      const Color(
                    0xFF7C3AED,
                  ),
                  backgroundColor:
                      const Color(
                    0xFFF3E8FF,
                  ),
                  onTap:
                      _openPeople,
                );

              case 1:
                return _ActionCard(
                  icon:
                      Icons
                          .photo_library_rounded,
                  title:
                      'My Photos',
                  subtitle:
                      'Your gallery',
                  iconColor:
                      const Color(
                    0xFF2563EB,
                  ),
                  backgroundColor:
                      const Color(
                    0xFFEFF6FF,
                  ),
                  onTap:
                      _openMyPhotos,
                );

              case 2:
                return _ActionCard(
                  icon:
                      Icons
                          .inbox_rounded,
                  title:
                      'Received',
                  subtitle:
                      'Shared with you',
                  iconColor:
                      const Color(
                    0xFF0891B2,
                  ),
                  backgroundColor:
                      const Color(
                    0xFFCFFAFE,
                  ),
                  onTap:
                      _openReceivedPhotos,
                );

              case 3:
                return _ActionCard(
                  icon:
                      Icons
                          .face_retouching_natural,
                  title:
                      'Register Face',
                  subtitle:
                      'Create profile',
                  iconColor:
                      const Color(
                    0xFF16A34A,
                  ),
                  backgroundColor:
                      const Color(
                    0xFFDCFCE7,
                  ),
                  onTap:
                      _openRegisterFace,
                );

              default:
                return const SizedBox();
            }
          },
        );
      },
    );
  }

  // ==========================================================
  // RECENT ACTIVITY
  // ==========================================================

  Widget _buildRecentActivity() {
    return Container(
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border: Border.all(
          color:
              const Color(0xFFE7EBF2),
        ),
      ),

      child: Column(
        children: [
          _ActivityItem(
            icon:
                Icons
                    .check_circle_rounded,

            iconColor:
                const Color(
              0xFF16A34A,
            ),

            title:
                'Photo shared successfully',

            subtitle:
                'Shared with Arun',

            time:
                'Today · 2:35 PM',
          ),

          const Divider(
            height: 22,
            color:
                Color(0xFFF1F5F9),
          ),

          _ActivityItem(
            icon:
                Icons.inbox_rounded,

            iconColor:
                const Color(
              0xFF2563EB,
            ),

            title:
                'New photo received',

            subtitle:
                'From Priya',

            time:
                'Today · 1:20 PM',
          ),

          const Divider(
            height: 22,
            color:
                Color(0xFFF1F5F9),
          ),

          _ActivityItem(
            icon:
                Icons.face_rounded,

            iconColor:
                const Color(
              0xFF7C3AED,
            ),

            title:
                'Face scan completed',

            subtitle:
                '3 people detected',

            time:
                'Yesterday',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PROFILE CARD
  // ==========================================================

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _openRegisterFace,

      child: Container(
        padding:
            const EdgeInsets.all(20),

        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            begin:
                Alignment.topLeft,
            end:
                Alignment.bottomRight,

            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),

          borderRadius:
              BorderRadius.circular(
            24,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.08,
              ),

              blurRadius: 20,

              offset:
                  const Offset(0, 8),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,

              padding:
                  const EdgeInsets.all(
                3,
              ),

              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,

                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF60A5FA),
                    Color(0xFF818CF8),
                  ],
                ),
              ),

              child: Container(
                decoration:
                    const BoxDecoration(
                  color:
                      Color(0xFF1E293B),

                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons
                      .person_rounded,
                  color:
                      Colors.white,
                  size: 29,
                ),
              ),
            ),

            const SizedBox(width: 14),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    'Your FaceShare Profile',

                    style:
                        TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Colors.white,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Identity registered • Ready to share',

                    style:
                        TextStyle(
                      fontSize: 11,
                      color:
                          Colors.white60,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding:
                  const EdgeInsets.all(
                10,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF16A34A,
                ).withValues(
                  alpha: 0.15,
                ),

                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),

              child:
                  const Icon(
                Icons
                    .verified_rounded,
                color:
                    Color(0xFF4ADE80),
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // HOW IT WORKS
  // ==========================================================

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        const Text(
          'How FaceShare Works',

          style:
              TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
            color:
                Color(0xFF0F172A),
          ),
        ),

        const SizedBox(height: 15),

        _StepCard(
          number: '01',
          icon:
              Icons.camera_alt_outlined,
          title:
              'Capture',
          description:
              'Take a group photo.',
        ),

        _StepCard(
          number: '02',
          icon:
              Icons.face_retouching_natural,
          title:
              'Recognize',
          description:
              'AI identifies registered people.',
        ),

        _StepCard(
          number: '03',
          icon:
              Icons.person_search_rounded,
          title:
              'Select',
          description:
              'Choose who should receive the photo.',
        ),

        _StepCard(
          number: '04',
          icon:
              Icons.send_rounded,
          title:
              'Share',
          description:
              'Send the photo to selected FaceShare users.',
        ),
      ],
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNavigation() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16,
      ),

      height: 72,

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        border: Border.all(
          color:
              const Color(0xFFE7EBF2),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.10,
            ),

            blurRadius: 25,

            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Row(
        children: [
          Expanded(
            child:
                _BottomNavItem(
              icon:
                  Icons.home_outlined,
              activeIcon:
                  Icons.home_rounded,
              label: 'Home',
              selected:
                  _currentIndex == 0,
              onTap: () {
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
          ),

          Expanded(
            child:
                _BottomNavItem(
              icon:
                  Icons.photo_library_outlined,
              activeIcon:
                  Icons.photo_library_rounded,
              label: 'Photos',
              selected:
                  _currentIndex == 1,
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
                _openMyPhotos();
              },
            ),
          ),

          // ==================================================
          // CENTER SCANNER
          // ==================================================

          SizedBox(
            width: 76,

            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = 2;
                  });

                  _openFaceScanner();
                },

                child: Container(
                  width: 58,
                  height: 58,

                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,

                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF4F46E5),
                      ],
                    ),

                    shape:
                        BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(
                          0xFF2563EB,
                        ).withValues(
                          alpha: 0.30,
                        ),

                        blurRadius: 16,

                        offset:
                            const Offset(
                          0,
                          7,
                        ),
                      ),
                    ],
                  ),

                  child:
                      const Icon(
                    Icons
                        .document_scanner_rounded,
                    color:
                        Colors.white,
                    size: 27,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child:
                _BottomNavItem(
              icon:
                  Icons.history_outlined,
              activeIcon:
                  Icons.history_rounded,
              label: 'History',
              selected:
                  _currentIndex == 3,
              onTap: () {
                setState(() {
                  _currentIndex = 3;
                });

                _openSharingHistory();
              },
            ),
          ),

          Expanded(
            child:
                _BottomNavItem(
              icon:
                  Icons.person_outline_rounded,
              activeIcon:
                  Icons.person_rounded,
              label: 'Profile',
              selected:
                  _currentIndex == 4,
              onTap: () {
                setState(() {
                  _currentIndex = 4;
                });

                _openRegisterFace();
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ALL FEATURES
  // ==========================================================

  void _showAllActions() {
    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      backgroundColor:
          Colors.transparent,

      builder: (sheetContext) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            28,
          ),

          decoration:
              const BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const _BottomSheetHandle(),

              const SizedBox(height: 20),

              const Text(
                'All Features',

                style:
                    TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Manage your FaceShare workspace',

                style:
                    TextStyle(
                  fontSize: 13,
                  color:
                      Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 20),

              // Shared / Received / People
              // are intentionally NOT included.

              _FeatureRow(
                icon:
                    Icons.camera_alt_rounded,
                title:
                    'Scan Photo',
                subtitle:
                    'Detect faces with AI',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openCamera();
                },
              ),

              _FeatureRow(
                icon:
                    Icons.photo_library_rounded,
                title:
                    'My Photos',
                subtitle:
                    'View your personal gallery',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openMyPhotos();
                },
              ),

              _FeatureRow(
                icon:
                    Icons.history_rounded,
                title:
                    'Sharing History',
                subtitle:
                    'View your sharing activity',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openSharingHistory();
                },
              ),

              _FeatureRow(
                icon:
                    Icons.lock_outline_rounded,
                title:
                    'Sharing Permission',
                subtitle:
                    'Control sharing access',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openSharingPermission();
                },
              ),

              _FeatureRow(
                icon:
                    Icons.face_retouching_natural,
                title:
                    'Face Profile',
                subtitle:
                    'Manage your registered face',
                onTap: () {
                  Navigator.pop(
                    sheetContext,
                  );

                  _openRegisterFace();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// ACTION CARD
// ============================================================

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.white,

      borderRadius:
          BorderRadius.circular(20),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(20),

        child: Container(
          width: double.infinity,

          padding:
              const EdgeInsets.all(14),

          decoration:
              BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
              20,
            ),

            border: Border.all(
              color:
                  const Color(
                0xFFE7EBF2,
              ),
            ),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color:
                      backgroundColor,

                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),

                child: Icon(
                  icon,
                  color:
                      iconColor,
                  size: 21,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                title,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV ITEM
// ============================================================

class _BottomNavItem
    extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,

      behavior:
          HitTestBehavior.opaque,

      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [
          Icon(
            selected
                ? activeIcon
                : icon,

            size: 22,

            color: selected
                ? const Color(
                    0xFF2563EB,
                  )
                : const Color(
                    0xFF94A3B8,
                  ),
          ),

          const SizedBox(height: 4),

          Text(
            label,

            style:
                TextStyle(
              fontSize: 10,

              fontWeight:
                  selected
                      ? FontWeight.w700
                      : FontWeight.w500,

              color: selected
                  ? const Color(
                      0xFF2563EB,
                    )
                  : const Color(
                      0xFF94A3B8,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE NAVIGATOR
// ============================================================

class _ProfileNavigator
    extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileNavigator({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        width: 43,
        height: 43,

        padding:
            const EdgeInsets.all(2),

        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,

          gradient:
              const LinearGradient(
            colors: [
              Color(0xFF2563EB),
              Color(0xFF7C3AED),
            ],
          ),
        ),

        child: Container(
          decoration:
              const BoxDecoration(
            color: Colors.white,

            shape:
                BoxShape.circle,
          ),

          child: const Icon(
            Icons.person_rounded,
            color:
                Color(0xFF2563EB),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER BUTTON
// ============================================================

class _HeaderIconButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.white,

      borderRadius:
          BorderRadius.circular(14),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(14),

        child: Container(
          width: 43,
          height: 43,

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              14,
            ),

            border: Border.all(
              color:
                  const Color(
                0xFFE7EBF2,
              ),
            ),
          ),

          child: Icon(
            icon,
            size: 21,
            color:
                const Color(
              0xFF0F172A,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO ICON
// ============================================================

class _HeroIconButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.white
          .withValues(
        alpha: 0.15,
      ),

      borderRadius:
          BorderRadius.circular(14),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(14),

        child: Container(
          width: 52,
          height: 49,

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              14,
            ),

            border: Border.all(
              color: Colors.white
                  .withValues(
                alpha: 0.25,
              ),
            ),
          ),

          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ACTIVITY ITEM
// ============================================================

class _ActivityItem
    extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,

          decoration:
              BoxDecoration(
            color: iconColor
                .withValues(
              alpha: 0.10,
            ),

            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),

          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Text(
                title,

                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                  color:
                      Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,

                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        Text(
          time,

          style:
              const TextStyle(
            fontSize: 10,
            color:
                Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STEP CARD
// ============================================================

class _StepCard
    extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String description;

  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border: Border.all(
          color:
              const Color(
            0xFFE7EBF2,
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFEFF6FF,
              ),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Center(
              child: Text(
                number,

                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF2563EB),
                ),
              ),
            ),
          ),

          const SizedBox(width: 13),

          Container(
            width: 39,
            height: 39,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF8FAFC,
              ),

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Icon(
              icon,
              size: 20,
              color:
                  const Color(
                0xFF2563EB,
              ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  description,

                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARE PERSON
// ============================================================

class _SharePerson
    extends StatelessWidget {
  final String name;
  final bool selected;

  const _SharePerson({
    required this.name,
    required this.selected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 11,
      ),

      decoration:
          BoxDecoration(
        color: selected
            ? const Color(
                0xFFF8FAFF,
              )
            : Colors.white,

        border: Border.all(
          color: selected
              ? const Color(
                  0xFFBFDBFE,
                )
              : const Color(
                  0xFFE2E8F0,
                ),
        ),

        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),

      child: Row(
        children: [
          const CircleAvatar(
            radius: 21,

            backgroundColor:
                Color(0xFFDBEAFE),

            child: Icon(
              Icons.person_rounded,
              color:
                  Color(0xFF2563EB),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              name,

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
                color:
                    Color(0xFF0F172A),
              ),
            ),
          ),

          Icon(
            selected
                ? Icons
                    .check_circle_rounded
                : Icons.circle_outlined,

            color: selected
                ? const Color(
                    0xFF2563EB,
                  )
                : const Color(
                    0xFF94A3B8,
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FEATURE ROW
// ============================================================

class _FeatureRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),

      leading: Container(
        width: 45,
        height: 45,

        decoration:
            BoxDecoration(
          color:
              const Color(0xFFEFF6FF),

          borderRadius:
              BorderRadius.circular(
            13,
          ),
        ),

        child: Icon(
          icon,
          color:
              const Color(0xFF2563EB),
        ),
      ),

      title: Text(
        title,

        style:
            const TextStyle(
          fontWeight:
              FontWeight.w700,
          fontSize: 14,
        ),
      ),

      subtitle: Text(
        subtitle,

        style:
            const TextStyle(
          fontSize: 11,
          color:
              Color(0xFF64748B),
        ),
      ),

      trailing:
          const Icon(
        Icons
            .arrow_forward_ios_rounded,
        size: 15,
        color:
            Color(0xFF94A3B8),
      ),

      onTap: onTap,
    );
  }
}

// ============================================================
// BOTTOM SHEET HANDLE
// ============================================================

class _BottomSheetHandle
    extends StatelessWidget {
  const _BottomSheetHandle();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 42,
      height: 5,

      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFE2E8F0,
        ),

        borderRadius:
            BorderRadius.circular(
          10,
        ),
      ),
    );
  }
}