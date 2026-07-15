import 'package:flutter/material.dart';

import '../../../data/models/exam_config.dart';

/// Direction C: gradient-led consumer SaaS visual exploration.
class ExamSelectionPreviewC extends StatelessWidget {
  const ExamSelectionPreviewC({super.key});

  static const _exams = [
    ExamConfig(
        id: 'up_home_guard',
        distanceKm: 4.8,
        timeLimitMin: 28,
        name: 'UP Home Guard'),
    ExamConfig(
        id: 'ssc_gd',
        distanceKm: 1.6,
        timeLimitMin: 6.5,
        name: 'SSC GD (Male)'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                Color(0xFF202048),
                Color(0xFF6C3BC7),
                Color(0xFFFF6174)
              ])),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      CircleAvatar(
                          backgroundColor: Color(0x33FFFFFF),
                          child: Icon(Icons.auto_awesome, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('PET Coach AI',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const Spacer(flex: 2),
                    const Text('Find your\nfinish line.',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            height: .96,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    const Text(
                        'Personalized preparation starts with your target exam.',
                        style:
                            TextStyle(color: Color(0xDFFFFFFF), fontSize: 16)),
                    const SizedBox(height: 28),
                    ..._exams.map(_examCard),
                    const Spacer(),
                  ]),
            ),
          ),
        ),
      );

  Widget _examCard(ExamConfig exam) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0x24FFFFFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x5CFFFFFF))),
        child: Row(children: [
          const Icon(Icons.flag_rounded, color: Color(0xFFFFD76A)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(exam.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('${exam.distanceKm} km  •  ${exam.timeLimitMin} min',
                    style: const TextStyle(color: Color(0xDFFFFFFF))),
              ])),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      );
}
