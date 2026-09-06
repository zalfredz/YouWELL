import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/data/repositories/local_wellness_repository.dart';
import 'youwell_app.dart';

/// Connect storage and application state once, before rendering any screen.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localRepository = LocalWellnessRepository(
    await SharedPreferences.getInstance(),
    storageKey: AppEnvironment.storageKey,
  );
  final controller = WellnessController(
    saved: await localRepository.read(),
    persist: localRepository.write,
  );
  final auth = AppEnvironment.hasSupabaseConfig
      ? await _connectedAuth(controller, localRepository)
      : AppAuthController.disabled(
          wellness: controller,
          localRepository: localRepository,
        );
  await auth.initialize();
  runApp(YouWellApp(controller: controller, auth: auth));
}

Future<AppAuthController> _connectedAuth(
  WellnessController controller,
  LocalWellnessRepository localRepository,
) async {
  await Supabase.initialize(
    url: AppEnvironment.supabaseUrl,
    publishableKey: AppEnvironment.supabasePublishableKey,
  );
  return AppAuthController.connected(
    client: Supabase.instance.client,
    wellness: controller,
    localRepository: localRepository,
  );
}
