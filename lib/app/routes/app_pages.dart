import 'package:get/get.dart';

import '../modules/auth/auth_binding.dart';
import '../modules/auth/auth_view.dart';
import '../modules/exam_selection/exam_selection_binding.dart';
import '../modules/exam_selection/exam_selection_view.dart';
import '../modules/session_summary/session_summary_binding.dart';
import '../modules/session_summary/session_summary_view.dart';
import '../modules/tracker/tracker_binding.dart';
import '../modules/tracker/tracker_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.auth;

  static final pages = <GetPage<dynamic>>[
    GetPage(name: Routes.auth, page: AuthView.new, binding: AuthBinding()),
    GetPage(
      name: Routes.examSelection,
      page: ExamSelectionView.new,
      binding: ExamSelectionBinding(),
    ),
    GetPage(
      name: Routes.tracker,
      page: TrackerView.new,
      binding: TrackerBinding(),
    ),
    GetPage(
      name: Routes.sessionSummary,
      page: SessionSummaryView.new,
      binding: SessionSummaryBinding(),
    ),
  ];
}
