import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/data/repositories/local_wellness_repository.dart';
import 'youwell_app.dart';

/// Connect storage and application state once, before rendering any screen.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalWellnessRepository(
    await SharedPreferences.getInstance(),
    storageKey: AppEnvironment.storageKey,
  );
  final controller = WellnessController(
    saved: await repository.read(),
    persist: repository.write,
  );
  runApp(YouWellApp(controller: controller));
}
