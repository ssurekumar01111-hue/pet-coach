import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/exam_config.dart';
import 'exam_selection_controller.dart';

class ExamSelectionView extends GetView<ExamSelectionController> {
  const ExamSelectionView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choose your exam')),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(children: controller.exams.map(_examTile).toList());
        }),
      );
  Widget _examTile(ExamConfig exam) => ListTile(
        title: Text(exam.name),
        subtitle: Text('${exam.distanceKm} km in ${exam.timeLimitMin} min'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => controller.selectExam(exam),
      );
}
