import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/services/hydration_service.dart';
import 'app/services/offline_session_sync_service.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Get.putAsync(() => HydrationService().init(), permanent: true);
  await Get.putAsync(() => OfflineSessionSyncService().init(), permanent: true);
  // Existing anonymous sessions cannot complete phone verification. Clear them
  // once so every subsequent account is authenticated by a verified number.
  if (FirebaseAuth.instance.currentUser?.isAnonymous ?? false) {
    await FirebaseAuth.instance.signOut();
  }
  final initialRoute = FirebaseAuth.instance.currentUser == null
      ? AppPages.initial
      : Routes.examSelection;
  runApp(PetCoachApp(initialRoute: initialRoute));
}

class PetCoachApp extends StatelessWidget {
  const PetCoachApp({required this.initialRoute, super.key});

  final String initialRoute;

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'PET Coach',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: initialRoute,
        getPages: AppPages.pages,
      );
}
