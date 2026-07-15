import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'tracker_controller.dart';

class TrackerView extends GetView<TrackerController> {
  const TrackerView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Run tracker')),
        body: Obx(
          () => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stat('Distance',
                    '${controller.distanceKm.value.toStringAsFixed(2)} km'),
                _stat('Elapsed', _formatDuration(controller.elapsed.value)),
                _stat(
                    'Pace', _formatPace(controller.currentPaceSecPerKm.value)),
                const SizedBox(height: 20),
                Chip(
                  label: Text(controller.movementState.value.toUpperCase()),
                  avatar: Icon(controller.movementState.value == 'running'
                      ? Icons.directions_run
                      : Icons.directions_walk),
                ),
                if (controller.errorMessage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(controller.errorMessage.value!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const Spacer(),
                if (!controller.isTracking.value)
                  FilledButton(
                      onPressed: controller.start, child: const Text('Start')),
                if (controller.isTracking.value) ...[
                  if (!controller.isPaused.value)
                    OutlinedButton(
                        onPressed: controller.pause,
                        child: const Text('Pause')),
                  if (controller.isPaused.value)
                    FilledButton(
                        onPressed: controller.start,
                        child: const Text('Resume')),
                  FilledButton.tonal(
                      onPressed: controller.stop, child: const Text('Stop')),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _stat(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [Text(label), const Spacer(), Text(value)]),
      );

  String _formatDuration(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  String _formatPace(double secondsPerKm) {
    if (secondsPerKm <= 0) return '--:-- /km';
    return '${(secondsPerKm ~/ 60).toString().padLeft(2, '0')}:${(secondsPerKm % 60).round().toString().padLeft(2, '0')} /km';
  }
}
