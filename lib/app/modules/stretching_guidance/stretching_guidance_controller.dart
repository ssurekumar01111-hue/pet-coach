import 'dart:async';

import 'package:get/get.dart';

enum StretchTiming { preRun, postRun }

class Stretch {
  const Stretch({
    required this.name,
    required this.targetMuscle,
    required this.durationSeconds,
    required this.instructions,
    required this.whenToUse,
  });

  final String name;
  final String targetMuscle;
  final int durationSeconds;
  final String instructions;
  final StretchTiming whenToUse;
}

class StretchingGuidanceController extends GetxController {
  final activeStretchName = RxnString();
  final remainingSeconds = 0.obs;
  Timer? _timer;

  static const stretches = <Stretch>[
    Stretch(name: 'Leg swings', targetMuscle: 'Hips & hamstrings', durationSeconds: 30, instructions: 'Hold a wall, swing one leg gently forward and back. Switch sides halfway.', whenToUse: StretchTiming.preRun),
    Stretch(name: 'High knees', targetMuscle: 'Hip flexors', durationSeconds: 30, instructions: 'March briskly in place, lifting knees to a comfortable height and keeping your chest tall.', whenToUse: StretchTiming.preRun),
    Stretch(name: 'Walking lunges', targetMuscle: 'Glutes & quads', durationSeconds: 40, instructions: 'Step into a short, controlled lunge. Keep your front knee aligned over your foot.', whenToUse: StretchTiming.preRun),
    Stretch(name: 'Ankle circles', targetMuscle: 'Ankles & calves', durationSeconds: 30, instructions: 'Lift one foot and make slow circles at the ankle. Change direction, then switch sides.', whenToUse: StretchTiming.preRun),
    Stretch(name: 'Easy march', targetMuscle: 'Full body', durationSeconds: 45, instructions: 'March with relaxed arm swings, gradually raising your cadence before the run.', whenToUse: StretchTiming.preRun),
    Stretch(name: 'Hamstring stretch', targetMuscle: 'Hamstrings', durationSeconds: 30, instructions: 'Place one heel forward, hinge gently at the hips, and keep your back long. Switch sides halfway.', whenToUse: StretchTiming.postRun),
    Stretch(name: 'Standing quad stretch', targetMuscle: 'Quadriceps', durationSeconds: 30, instructions: 'Hold a support, bring one heel toward your glute, and keep both knees close. Switch sides halfway.', whenToUse: StretchTiming.postRun),
    Stretch(name: 'Calf stretch', targetMuscle: 'Calves', durationSeconds: 30, instructions: 'Step one foot back, press the heel down, and lean forward gently. Switch sides halfway.', whenToUse: StretchTiming.postRun),
    Stretch(name: 'Figure-four glute stretch', targetMuscle: 'Glutes', durationSeconds: 30, instructions: 'Sit or stand supported, cross one ankle over the opposite thigh, and ease into a gentle stretch.', whenToUse: StretchTiming.postRun),
    Stretch(name: 'Hip flexor stretch', targetMuscle: 'Hip flexors', durationSeconds: 30, instructions: 'Use a short kneeling or standing lunge and tuck your pelvis slightly. Switch sides halfway.', whenToUse: StretchTiming.postRun),
  ];

  List<Stretch> forTiming(StretchTiming timing) =>
      stretches.where((stretch) => stretch.whenToUse == timing).toList();

  void startTimer(Stretch stretch) {
    _timer?.cancel();
    activeStretchName.value = stretch.name;
    remainingSeconds.value = stretch.durationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value <= 1) {
        stopTimer();
      } else {
        remainingSeconds.value--;
      }
    });
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    activeStretchName.value = null;
    remainingSeconds.value = 0;
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
