import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PetCoachApp());
}

class PetCoachApp extends StatelessWidget {
  const PetCoachApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'PET Coach AI',
        debugShowCheckedModeBanner: false,
        initialRoute: AppPages.initial,
        getPages: AppPages.pages,
      );
}
