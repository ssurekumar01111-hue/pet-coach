import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'session_summary_controller.dart';

class SessionSummaryView extends GetView<SessionSummaryController> {
  const SessionSummaryView({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Session summary')),
        body: const Center(
          child: Text('AI coaching feedback will appear here after your run.'),
        ),
      );
}
