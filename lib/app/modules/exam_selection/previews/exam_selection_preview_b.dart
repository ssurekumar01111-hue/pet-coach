import 'package:flutter/material.dart';

import '../../../data/models/exam_config.dart';

/// Direction B: bright, energetic athletic visual exploration.
class ExamSelectionPreviewB extends StatelessWidget {
  const ExamSelectionPreviewB({super.key});

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
        backgroundColor: const Color(0xFFF7F8F4),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.bolt_rounded, color: Color(0xFFFF4D00), size: 30),
                SizedBox(width: 8),
                Text('PET COACH',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: .8)),
                Spacer(),
                CircleAvatar(
                    backgroundColor: Color(0xFF18221D),
                    child: Icon(Icons.person_outline, color: Colors.white)),
              ]),
              const SizedBox(height: 34),
              const Text('What are we\ntraining for?',
                  style: TextStyle(
                      color: Color(0xFF101512),
                      fontSize: 37,
                      height: 1,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Choose an exam and let’s set your pace.',
                  style: TextStyle(color: Color(0xFF637068), fontSize: 16)),
              const SizedBox(height: 28),
              ..._exams.map(_examCard),
              const Spacer(),
              const Text('YOUR NEXT RUN STARTS HERE',
                  style: TextStyle(
                      color: Color(0xFF637068),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2)),
            ]),
          ),
        ),
      );

  Widget _examCard(ExamConfig exam) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 8))
            ]),
        child: Row(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: const Color(0xFFFF4D00),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.directions_run_rounded,
                  color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(exam.name,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text('${exam.distanceKm} km  ·  ${exam.timeLimitMin} min limit',
                    style: const TextStyle(color: Color(0xFF637068))),
              ])),
          const Icon(Icons.arrow_circle_right_rounded,
              color: Color(0xFF101512), size: 30),
        ]),
      );
}
