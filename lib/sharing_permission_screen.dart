import 'package:flutter/material.dart';

import 'services/sharing_permission_service.dart';

class SharingPermissionScreen extends StatefulWidget {
  const SharingPermissionScreen({super.key});

  @override
  State<SharingPermissionScreen> createState() =>
      _SharingPermissionScreenState();
}

class _SharingPermissionScreenState
    extends State<SharingPermissionScreen> {
  bool _sharingEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final SharingPermissionService _permissionService =
      SharingPermissionService.instance;

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    try {
      final enabled =
          await _permissionService.getSharingEnabled();

      if (!mounted) return;

      setState(() {
        _sharingEnabled = enabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load sharing permission.',
          ),
        ),
      );
    }
  }

  Future<void> _changePermission(bool value) async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _permissionService.setSharingEnabled(value);

      if (!mounted) return;

      setState(() {
        _sharingEnabled = value;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Photo sharing enabled.'
                : 'Photo sharing disabled.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update sharing permission.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sharing Permission',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        size: 48,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Center(
                    child: Text(
                      'Photo Sharing',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Control whether other FaceShare users can '
                    'share photos with you when you are recognized.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _sharingEnabled
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _sharingEnabled
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            color: _sharingEnabled
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                          ),
                        ),

                        const SizedBox(width: 14),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Allow Photo Sharing',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                  color:
                                      Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Allow other users to share '
                                'recognized photos with you.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Switch(
                                value: _sharingEnabled,
                                onChanged:
                                    _changePermission,
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Color(0xFF475569),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can change this permission '
                            'at any time. Your FaceShare ID '
                            'remains unchanged.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF475569),
                            ),
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