import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'person.dart';
import 'photo.dart';
import 'services/face_recognition_service.dart';
import 'services/person_storage.dart';
import 'services/photo_storage.dart';
import 'services/photo_sharing_service.dart';

// ============================================================
// APP COLORS
// ============================================================

const Color primary = Color(0xFF2563EB);
const Color primaryDark = Color(0xFF1D4ED8);
const Color background = Color(0xFFF8FAFC);
const Color textPrimary = Color(0xFF0F172A);
const Color textSecondary = Color(0xFF64748B);
const Color border = Color(0xFFE2E8F0);

const Color success = Color(0xFF16A34A);
const Color successLight = Color(0xFFDCFCE7);

const Color warning = Color(0xFFD97706);
const Color warningLight = Color(0xFFFEF3C7);

const Color danger = Color(0xFFDC2626);
const Color dangerLight = Color(0xFFFEE2E2);

// ============================================================
// FACE SCAN SCREEN
// ============================================================

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  final ImagePicker _picker = ImagePicker();

  final FaceRecognitionService _faceService =
      FaceRecognitionService.instance;

  final PersonStorage _personStorage =
      PersonStorage.instance;

  final PhotoStorage _photoStorage =
      PhotoStorage.instance;

  final PhotoSharingService _sharingService =
      PhotoSharingService.instance;

  File? _image;

  bool _isScanning = false;
  bool _isInitialized = false;
  bool _isSharing = false;

  int _detectedFaceCount = 0;

  List<RecognitionResult> _results = [];

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _faceService.initialize();
      await _personStorage.initialize();
      await _photoStorage.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Face scanner initialization error: $e');

      if (!mounted) return;

      setState(() {
        _isInitialized = false;
      });

      _showMessage(
        'Unable to initialize face recognition.',
        isError: true,
      );
    }
  }

  // ============================================================
  // TAKE PHOTO
  // ============================================================

  Future<void> _takePhoto() async {
    if (!_isInitialized || _isScanning || _isSharing) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (photo == null || !mounted) return;

      await _recognizePhoto(photo);
    } catch (e) {
      debugPrint('Camera error: $e');

      if (!mounted) return;

      _showMessage(
        'Unable to take photo.',
        isError: true,
      );
    }
  }

  // ============================================================
  // PICK FROM GALLERY
  // ============================================================

  Future<void> _pickFromGallery() async {
    if (!_isInitialized || _isScanning || _isSharing) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (photo == null || !mounted) return;

      await _recognizePhoto(photo);
    } catch (e) {
      debugPrint('Gallery error: $e');

      if (!mounted) return;

      _showMessage(
        'Unable to select photo.',
        isError: true,
      );
    }
  }

  // ============================================================
  // RECOGNIZE PHOTO
  // ============================================================

  Future<void> _recognizePhoto(XFile photo) async {
    if (!mounted) return;

    setState(() {
      _image = File(photo.path);
      _results = [];
      _detectedFaceCount = 0;
      _isScanning = true;
    });

    try {
      final List<Person> people = _personStorage.getPeople();

      if (people.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isScanning = false;
        });

        _showMessage(
          'No people are registered yet.',
          isError: true,
        );

        return;
      }

      // --------------------------------------------------------
      // DETECT FACES
      // --------------------------------------------------------

      final faces = await _faceService.detectFaces(
        photo.path,
      );

      if (!mounted) return;

      setState(() {
        _detectedFaceCount = faces.length;
      });

      // --------------------------------------------------------
      // MATCH REGISTERED PEOPLE
      // --------------------------------------------------------

      final List<FaceMatchResult> matches =
    await _faceService.findFaceMatches(
  photo.path,
  threshold: 0.60,
);

      // --------------------------------------------------------
      // BUILD RESULTS
      // --------------------------------------------------------

      final List<RecognitionResult> recognitionResults =
          matches.map((match) {
        return RecognitionResult(
          person: match.person,
          similarity: match.score,
          isRecognized: match.isRecognized,
        );
      }).toList();

      // --------------------------------------------------------
      // SAVE PHOTO
      // --------------------------------------------------------

      final List<Person> matchedPeople = matches
          .where((match) => match.isRecognized)
          .map((match) => match.person!)
          .toList();

      if (matchedPeople.isNotEmpty) {
        final FacePhoto facePhoto = FacePhoto(
          id: DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
          imagePath: photo.path,
          recognizedPeople: matchedPeople
              .map((person) => person.name)
              .toSet()
              .toList(),
          createdAt: DateTime.now(),
        );

        await _photoStorage.addPhoto(facePhoto);
      }

      if (!mounted) return;

      setState(() {
        _results = recognitionResults;
        _isScanning = false;
      });

      // --------------------------------------------------------
      // SHOW RESULT
      // --------------------------------------------------------

      if (matchedPeople.isNotEmpty) {
        final int shareableCount = matchedPeople
            .where((person) => person.canReceivePhotos)
            .length;

        _showMessage(
          '${matchedPeople.length} '
          '${matchedPeople.length == 1 ? 'person' : 'people'} identified.',
        );

        if (shareableCount > 0) {
          Future.delayed(
            const Duration(milliseconds: 400),
            () {
              if (mounted) {
                _showShareDialog(matchedPeople);
              }
            },
          );
        }
      } else {
        _showMessage(
          _detectedFaceCount == 0
              ? 'No faces detected in this photo.'
              : '$_detectedFaceCount '
                  '${_detectedFaceCount == 1 ? 'face' : 'faces'} detected, '
                  'but no registered person matched.',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Face recognition error: $e');

      if (!mounted) return;

      setState(() {
        _isScanning = false;
      });

      _showMessage(
        'Face recognition failed. Please try again.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SHARE PHOTO
  // ============================================================

  Future<void> _sharePhotoWithPeople(
    List<Person> people,
  ) async {
    if (_image == null) {
      _showMessage(
        'No photo available to share.',
        isError: true,
      );
      return;
    }

    final List<Person> shareablePeople = people
        .where((person) => person.canReceivePhotos)
        .toList();

    if (shareablePeople.isEmpty) {
      _showMessage(
        'No selected profile can receive this photo.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final int successfulShares =
          await _sharingService.sharePhotoWithPeople(
        imagePath: _image!.path,
        people: shareablePeople,
      );

      if (!mounted) return;

      setState(() {
        _isSharing = false;
      });

      if (successfulShares == 0) {
        _showMessage(
          'Photo could not be shared.',
          isError: true,
        );
        return;
      }

      _showMessage(
        'Photo shared with '
        '$successfulShares '
        '${successfulShares == 1 ? 'person' : 'people'}.',
      );
    } catch (e) {
      debugPrint('Photo sharing error: $e');

      if (!mounted) return;

      setState(() {
        _isSharing = false;
      });

      _showMessage(
        'Unable to share photo.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SHARE REVIEW SHEET
  // ============================================================

  void _showShareDialog(List<Person> people) {
    final List<Person> shareablePeople = people
        .where((person) => person.canReceivePhotos)
        .toList();

    if (shareablePeople.isEmpty) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ShareReviewSheet(
          people: people,
          shareablePeople: shareablePeople,
          personImage: _personImage,
          onShare: (selectedPeople) async {
            Navigator.pop(sheetContext);

            await _sharePhotoWithPeople(
              selectedPeople,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PERSON IMAGE
  // ============================================================

  ImageProvider? _personImage(Person person) {
    if (person.imagePath.isEmpty) {
      return null;
    }

    final File file = File(person.imagePath);

    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // RESET
  // ============================================================

  void _resetScan() {
    if (_isScanning || _isSharing) return;

    setState(() {
      _image = null;
      _results = [];
      _detectedFaceCount = 0;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final int recognizedCount =
        _results.where((result) => result.isRecognized).length;

    final int shareableCount = _results
        .where(
          (result) =>
              result.person?.canReceivePhotos ?? false,
        )
        .length;

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 18),

              _buildPhotoPreview(),

              if (_isScanning) ...[
                const SizedBox(height: 16),
                _buildScanningCard(),
              ],

              if (!_isScanning && _results.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildRecognitionSummary(
                  recognizedCount,
                  shareableCount,
                ),
                const SizedBox(height: 18),
                _buildResultsSection(),
              ],

              const SizedBox(height: 22),

              _buildActionButtons(),

              if (_image != null &&
                  !_isScanning &&
                  !_isSharing) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _resetScan,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                    ),
                    label: const Text(
                      'Scan another photo',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 18,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  primary,
                  Color(0xFF60A5FA),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.face_retouching_natural_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FaceShare AI',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Smart photo sharing',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scan a group photo',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'FaceShare AI will identify registered people '
          'and prepare the photo for individual profiles.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PHOTO PREVIEW
  // ============================================================

  Widget _buildPhotoPreview() {
    return Container(
      width: double.infinity,
      height: 375,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _image == null
          ? _buildEmptyPhotoState()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _image!,
                  fit: BoxFit.cover,
                ),

                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isScanning
                              ? 'Scanning'
                              : 'Photo selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isScanning)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.18),
                      child: const Center(
                        child: _ScanningIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEmptyPhotoState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.groups_rounded,
            size: 40,
            color: primary,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ready to identify people',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Take a group photo or select one\nfrom your gallery.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: textSecondary,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SCANNING CARD
  // ============================================================

  Widget _buildScanningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 23,
            height: 23,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primary,
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyzing photo',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Finding faces and matching registered profiles...',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildRecognitionSummary(
    int recognizedCount,
    int shareableCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Scan complete',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.face_rounded,
                  value: '$_detectedFaceCount',
                  label: 'Faces found',
                  color: primary,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.verified_rounded,
                  value: '$recognizedCount',
                  label: 'Identified',
                  color: success,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.share_rounded,
                  value: '$shareableCount',
                  label: 'Shareable',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULTS
  // ============================================================

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Identified people',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            Spacer(),
            Icon(
              Icons.people_alt_outlined,
              size: 20,
              color: textSecondary,
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          'Each recognized person can have this photo shared to their profile.',
          style: TextStyle(
            fontSize: 12,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ..._results.asMap().entries.map(
          (entry) {
            return _RecognitionCard(
              faceNumber: entry.key + 1,
              result: entry.value,
              personImage: _personImage,
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: (!_isInitialized ||
                    _isScanning ||
                    _isSharing)
                ? null
                : _takePhoto,
            icon: const Icon(
              Icons.camera_alt_rounded,
            ),
            label: Text(
              _isScanning
                  ? 'Analyzing...'
                  : 'Take Group Photo',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  const Color(0xFFCBD5E1),
              disabledForegroundColor:
                  Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: (!_isInitialized ||
                    _isScanning ||
                    _isSharing)
                ? null
                : _pickFromGallery,
            icon: const Icon(
              Icons.photo_library_outlined,
            ),
            label: const Text(
              'Choose from Gallery',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(
                color: Color(0xFFBFDBFE),
                width: 1.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SUMMARY ITEM
// ================================================================

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// RECOGNITION RESULT
// ================================================================

class RecognitionResult {
  final Person? person;
  final double similarity;
  final bool isRecognized;

  const RecognitionResult({
    required this.person,
    required this.similarity,
    required this.isRecognized,
  });

  String get personName {
    return person?.name ?? 'Unknown Person';
  }

  String? get faceShareUserId {
    return person?.faceShareUserId;
  }
}

// ================================================================
// RECOGNITION CARD
// ================================================================

class _RecognitionCard extends StatelessWidget {
  final int faceNumber;
  final RecognitionResult result;
  final ImageProvider? Function(Person person) personImage;

  const _RecognitionCard({
    required this.faceNumber,
    required this.result,
    required this.personImage,
  });

  @override
  Widget build(BuildContext context) {
    final bool recognized = result.isRecognized;
    final Person? person = result.person;

    final ImageProvider? image =
        person == null ? null : personImage(person);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: recognized
              ? successLight
              : dangerLight,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: recognized
                    ? successLight
                    : dangerLight,
                backgroundImage: image,
                child: image == null
                    ? Icon(
                        recognized
                            ? Icons.person_rounded
                            : Icons.person_off_rounded,
                        color: recognized
                            ? success
                            : danger,
                        size: 26,
                      )
                    : null,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$faceNumber',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  recognized
                      ? person!.name
                      : 'Unknown person',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  recognized
                      ? (person!.canReceivePhotos
                          ? 'Ready for individual sharing'
                          : 'Photo sharing unavailable')
                      : 'No registered profile matched',
                  style: TextStyle(
                    fontSize: 11,
                    color: recognized
                        ? (person!.canReceivePhotos
                            ? success
                            : warning)
                        : danger,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusIcon(
            recognized: recognized,
            shareable:
                person?.canReceivePhotos ?? false,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STATUS ICON
// ================================================================

class _StatusIcon extends StatelessWidget {
  final bool recognized;
  final bool shareable;

  const _StatusIcon({
    required this.recognized,
    required this.shareable,
  });

  @override
  Widget build(BuildContext context) {
    if (!recognized) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: dangerLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close_rounded,
          color: danger,
          size: 18,
        ),
      );
    }

    if (!shareable) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: warningLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.block_rounded,
          color: warning,
          size: 17,
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: successLight,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: success,
        size: 19,
      ),
    );
  }
}

// ================================================================
// SHARE REVIEW SHEET
// ================================================================

class _ShareReviewSheet extends StatefulWidget {
  final List<Person> people;
  final List<Person> shareablePeople;
  final ImageProvider? Function(Person person) personImage;
  final Future<void> Function(List<Person>) onShare;

  const _ShareReviewSheet({
    required this.people,
    required this.shareablePeople,
    required this.personImage,
    required this.onShare,
  });

  @override
  State<_ShareReviewSheet> createState() =>
      _ShareReviewSheetState();
}

class _ShareReviewSheetState
    extends State<_ShareReviewSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();

    _selectedIds = widget.shareablePeople
        .map((person) => person.id)
        .toSet();
  }

  List<Person> get _selectedPeople {
    return widget.shareablePeople
        .where(
          (person) =>
              _selectedIds.contains(person.id),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 680,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),

            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review & Share',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Choose who should receive this photo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedPeople.length} of '
                        '${widget.shareablePeople.length} '
                        'profiles selected',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIds.length ==
                              widget.shareablePeople
                                  .length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds = widget
                                .shareablePeople
                                .map(
                                  (person) =>
                                      person.id,
                                )
                                .toSet();
                          }
                        });
                      },
                      child: Text(
                        _selectedIds.length ==
                                widget
                                    .shareablePeople
                                    .length
                            ? 'Clear'
                            : 'Select all',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                itemCount: widget.people.length,
                itemBuilder: (context, index) {
                  final person = widget.people[index];

                  final bool canShare =
                      person.canReceivePhotos;

                  final bool selected =
                      _selectedIds.contains(
                    person.id,
                  );

                  final ImageProvider? image =
                      widget.personImage(person);

                  return _PersonShareTile(
                    person: person,
                    image: image,
                    selected: selected,
                    canShare: canShare,
                    onTap: canShare
                        ? () {
                            setState(() {
                              if (selected) {
                                _selectedIds
                                    .remove(person.id);
                              } else {
                                _selectedIds
                                    .add(person.id);
                              }
                            });
                          }
                        : null,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                8,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed:
                      _selectedPeople.isEmpty
                          ? null
                          : () => widget.onShare(
                                _selectedPeople,
                              ),
                  icon: const Icon(
                    Icons.send_rounded,
                    size: 19,
                  ),
                  label: Text(
                    _selectedPeople.isEmpty
                        ? 'Select people to continue'
                        : 'Share with ${_selectedPeople.length} '
                            '${_selectedPeople.length == 1 ? 'person' : 'people'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFFE2E8F0),
                    disabledForegroundColor:
                        const Color(0xFF94A3B8),
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PERSON SHARE TILE
// ================================================================

class _PersonShareTile extends StatelessWidget {
  final Person person;
  final ImageProvider? image;
  final bool selected;
  final bool canShare;
  final VoidCallback? onTap;

  const _PersonShareTile({
    required this.person,
    required this.image,
    required this.selected,
    required this.canShare,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: canShare ? 1 : 0.55,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin:
              const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEFF6FF)
                : Colors.white,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF93C5FD)
                  : border,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor:
                    const Color(0xFFDBEAFE),
                backgroundImage: image,
                child: image == null
                    ? const Icon(
                        Icons.person_rounded,
                        color: primary,
                      )
                    : null,
              ),

              const SizedBox(width: 11),

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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canShare
                          ? 'Ready to receive'
                          : 'Sharing disabled',
                      style: TextStyle(
                        fontSize: 11,
                        color: canShare
                            ? success
                            : warning,
                      ),
                    ),
                  ],
                ),
              ),

              if (canShare)
                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? primary
                          : const Color(
                              0xFFCBD5E1,
                            ),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                      : null,
                )
              else
                const Icon(
                  Icons.block_rounded,
                  size: 20,
                  color: warning,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SCANNING INDICATOR
// ================================================================

class _ScanningIndicator extends StatelessWidget {
  const _ScanningIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 115,
      height: 115,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 9),
          Text(
            'Scanning...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}