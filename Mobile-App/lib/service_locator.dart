import 'package:get_it/get_it.dart';
import 'services/claude_api_service.dart';
import 'services/database_service.dart';
import 'services/elo_service.dart';
import 'services/json_export_service.dart';
import 'services/photo_storage_service.dart';
import 'services/segmentation_service.dart';
import 'services/settings_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  getIt.registerSingleton<DatabaseService>(DatabaseService());
  getIt.registerSingleton<PhotoStorageService>(PhotoStorageService());
  getIt.registerSingleton<EloService>(EloService());
  getIt.registerSingleton<SettingsService>(SettingsService());
  getIt.registerSingleton<ClaudeApiService>(ClaudeApiService(getIt<SettingsService>()));
  getIt.registerSingleton<JsonExportService>(JsonExportService(getIt<DatabaseService>(), getIt<PhotoStorageService>()));
  getIt.registerSingleton<SegmentationService>(SegmentationService(getIt<PhotoStorageService>()));

  // Warm caches
  await getIt<PhotoStorageService>().init();
  await getIt<SettingsService>().getShowSegmented();
}
