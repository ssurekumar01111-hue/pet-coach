import 'package:flutter/material.dart';

import '../../../data/models/exam_config.dart';

/// Direction A: dark tactical/military visual exploration.
class ExamSelectionPreviewA extends StatelessWidget {
  const ExamSelectionPreviewA({super.key});

  static const _exams = [
    ExamConfig(
      id: 'up_home_guard',
      distanceKm: 4.8,
      timeLimitMin: 28,
      name: 'UP Home Guard',
    ),
    ExamConfig(
      id: 'ssc_gd',
      distanceKm: 1.6,
      timeLimitMin: 6.5,
      name: 'SSC GD (Male)',
    ),
  ];

  @override
  Widget build(BuildContext context) => Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Scaffold(
          backgroundColor: const Color(0xFF0E1411),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PET COACH AI',
                    style: TextStyle(
                      color: Color(0xFFA8C686),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select your\nmission.',
                    style: TextStyle(
                      fontSize: 38,
                      height: .98,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Train precisely for your qualifying standard.',
                    style: TextStyle(color: Color(0xFF9BA69C), fontSize: 16),
                  ),
                  const SizedBox(height: 30),
                  ..._exams.map(_examCard),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A241D),
                      border: Border.all(color: const Color(0xFF334637)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFFA8C686)),
                        SizedBox(width: 12),
                        Expanded(child: Text('DISCIPLINE BUILDS READINESS')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _examCard(ExamConfig exam) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF172019),
          border: Border.all(color: const Color(0xFF415941)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam.name,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(children: [
              _metric(Icons.route_outlined, '${exam.distanceKm} KM'),
              const SizedBox(width: 24),
              _metric(Icons.timer_outlined, '${exam.timeLimitMin} MIN'),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: Color(0xFFA8C686)),
            ]),
          ],
        ),
      );

  Widget _metric(IconData icon, String text) => Row(children: [
        Icon(icon, size: 17, color: const Color(0xFFA8C686)),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]);
}
