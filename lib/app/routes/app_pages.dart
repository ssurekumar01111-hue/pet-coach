import 'package:get/get.dart';

import '../modules/auth/auth_binding.dart';
import '../modules/auth/auth_view.dart';
import '../modules/auth/otp_verification_view.dart';
import '../modules/exam_selection/exam_selection_binding.dart';
import '../modules/exam_selection/exam_selection_view.dart';
import '../modules/injury_risk/injury_risk_binding.dart';
import '../modules/injury_risk/injury_risk_view.dart';
import '../modules/leaderboard/leaderboard_binding.dart';
import '../modules/leaderboard/leaderboard_view.dart';
import '../modules/profile/profile_binding.dart';
import '../modules/profile/profile_view.dart';
import '../modules/pace_optimization/pace_optimization_binding.dart';
import '../modules/pace_optimization/pace_optimization_view.dart';
import '../modules/progress_timeline/progress_timeline_binding.dart';
import '../modules/progress_timeline/progress_timeline_view.dart';
import '../modules/qualification_readiness/qualification_readiness_binding.dart';
import '../modules/qualification_readiness/qualification_readiness_view.dart';
import '../modules/session_summary/session_summary_binding.dart';
import '../modules/session_summary/session_summary_view.dart';
import '../modules/stretching_guidance/stretching_guidance_binding.dart';
import '../modules/stretching_guidance/stretching_guidance_view.dart';
import '../modules/tracker/tracker_binding.dart';
import '../modules/tracker/tracker_view.dart';
import '../modules/training_plan/training_plan_binding.dart';
import '../modules/training_plan/training_plan_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.auth;

  static final pages = <GetPage<dynamic>>[
    GetPage(name: Routes.auth, page: AuthView.new, binding: AuthBinding()),
    GetPage(
      name: Routes.otpVerification,
      page: OtpVerificationView.new,
      binding: AuthBinding(),
    ),
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
    GetPage(
      name: Routes.profile,
      page: ProfileView.new,
      binding: ProfileBinding(),
    ),
    GetPage(
      name: Routes.progressTimeline,
      page: ProgressTimelineView.new,
      binding: ProgressTimelineBinding(),
    ),
    GetPage(
      name: Routes.qualificationReadiness,
      page: QualificationReadinessView.new,
      binding: QualificationReadinessBinding(),
    ),
    GetPage(
      name: Routes.paceOptimization,
      page: PaceOptimizationView.new,
      binding: PaceOptimizationBinding(),
    ),
    GetPage(
      name: Routes.trainingPlan,
      page: TrainingPlanView.new,
      binding: TrainingPlanBinding(),
    ),
    GetPage(
      name: Routes.leaderboard,
      page: LeaderboardView.new,
      binding: LeaderboardBinding(),
    ),
    GetPage(
      name: Routes.stretchingGuidance,
      page: StretchingGuidanceView.new,
      binding: StretchingGuidanceBinding(),
    ),
    GetPage(
        name: Routes.injuryRisk,
        page: InjuryRiskView.new,
        binding: InjuryRiskBinding()),
  ];
}
