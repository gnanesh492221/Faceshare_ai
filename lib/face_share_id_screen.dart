import 'package:flutter/material.dart';

import 'person.dart';

class FaceShareIdScreen extends StatelessWidget {
  final Person person;

  const FaceShareIdScreen({
    super.key,
    required this.person,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'FaceShare ID',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(
              Icons.face_retouching_natural,
              size: 70,
              color: Color(0xFF2563EB),
            ),

            const SizedBox(height: 20),

            const Text(
              'Your FaceShare ID',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Use this ID to identify your FaceShare account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color:
                      const Color(0xFFE2E8F0),
                ),
              ),

              child: Column(
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  SelectableText(
                    person.faceShareUserId,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(0xFF2563EB),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    const Color(0xFFDBEAFE),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color:
                        Color(0xFF2563EB),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This ID will be used for future cross-device sharing.',
                      style: TextStyle(
                        color:
                            Color(0xFF1E40AF),
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