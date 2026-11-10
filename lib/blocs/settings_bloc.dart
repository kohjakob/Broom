import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/claude_api_service.dart';
import '../services/database_service.dart';
import '../services/json_export_service.dart';
import '../services/photo_storage_service.dart';
import '../services/segmentation_service.dart';
import '../services/settings_service.dart';

sealed class SettingsEvent {}

class LoadSettings extends SettingsEvent {}

class UpdateApiKey extends SettingsEvent {
  final String key;
  UpdateApiKey(this.key);
}

class TestApiKey extends SettingsEvent {}

class ToggleShowSegmented extends SettingsEvent {
  final bool value;
  ToggleShowSegmented(this.value);
}

class ExportData extends SettingsEvent {}

class ClearExportedFile extends SettingsEvent {}

class ImportData extends SettingsEvent {
  final File file;
  ImportData(this.file);
}

enum TestStatus { idle, testing, success, failure }
enum DataOpStatus { idle, exporting, importing }

// Sentinel value for copyWith to distinguish between "not provided" and "set to null"
const _undefined = Object();

class SettingsState {
  final String apiKey;
  final TestStatus testStatus;
  final bool showSegmented;
  final DataOpStatus dataOpStatus;
  final File? exportedFile;
  final ImportResult? importResult;
  final String? dataError;

  const SettingsState({
    this.apiKey = '',
    this.testStatus = TestStatus.idle,
    this.showSegmented = true,
    this.dataOpStatus = DataOpStatus.idle,
    this.exportedFile,
    this.importResult,
    this.dataError,
  });

  SettingsState copyWith({
    String? apiKey,
    TestStatus? testStatus,
    bool? showSegmented,
    DataOpStatus? dataOpStatus,
    Object? exportedFile = _undefined,
    Object? importResult = _undefined,
    Object? dataError = _undefined,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      testStatus: testStatus ?? this.testStatus,
      showSegmented: showSegmented ?? this.showSegmented,
      dataOpStatus: dataOpStatus ?? this.dataOpStatus,
      exportedFile: exportedFile == _undefined ? this.exportedFile : exportedFile as File?,
      importResult: importResult == _undefined ? this.importResult : importResult as ImportResult?,
      dataError: dataError == _undefined ? this.dataError : dataError as String?,
    );
  }
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _settings;
  final ClaudeApiService _claude;
  final DatabaseService _db;
  final PhotoStorageService _photoStorage;
  final SegmentationService _segmentation;
  final JsonExportService _jsonExport;

  SettingsBloc(this._settings, this._claude, this._db, this._photoStorage, this._segmentation, this._jsonExport) : super(const SettingsState()) {
    on<LoadSettings>(_onLoad);
    on<UpdateApiKey>(_onUpdateApiKey);
    on<TestApiKey>(_onTestApiKey);
    on<ToggleShowSegmented>(_onToggleShowSegmented);
    on<ExportData>(_onExport);
    on<ClearExportedFile>(_onClearExportedFile);
    on<ImportData>(_onImport);
  }

  Future<void> _onLoad(LoadSettings event, Emitter<SettingsState> emit) async {
    final key = await _settings.getApiKey();
    final showSeg = await _settings.getShowSegmented();
    emit(state.copyWith(apiKey: key, showSegmented: showSeg));
  }

  Future<void> _onUpdateApiKey(UpdateApiKey event, Emitter<SettingsState> emit) async {
    await _settings.setApiKey(event.key);
    emit(state.copyWith(apiKey: event.key, testStatus: TestStatus.idle));
  }

  Future<void> _onTestApiKey(TestApiKey event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(testStatus: TestStatus.testing));
    final success = await _claude.testApiKey();
    emit(state.copyWith(testStatus: success ? TestStatus.success : TestStatus.failure));
    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(testStatus: TestStatus.idle));
  }

  Future<void> _onToggleShowSegmented(ToggleShowSegmented event, Emitter<SettingsState> emit) async {
    await _settings.setShowSegmented(event.value);
    emit(state.copyWith(showSegmented: event.value));

    // Update all item thumbnails to match the new setting
    final items = await _db.getAllItems();
    for (final item in items) {
      if (item.images.isEmpty) continue;
      final originalPath = item.images.first;
      final segPath = _segmentation.segmentedRelativePath(originalPath);
      final segAbsPath = await _photoStorage.resolvePhotoPath(segPath);
      final segExists = File(segAbsPath).existsSync();

      String newThumb;
      if (event.value && segExists) {
        newThumb = segPath;
      } else {
        newThumb = originalPath;
      }

      if (item.thumbnailImage != newThumb) {
        await _db.updateItem(item.copyWith(thumbnailImage: newThumb));
      }
    }
  }

  Future<void> _onExport(ExportData event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(
      dataOpStatus: DataOpStatus.exporting,
      dataError: null,
    ));
    try {
      final file = await _jsonExport.exportData();
      emit(state.copyWith(
        dataOpStatus: DataOpStatus.idle,
        exportedFile: file,
      ));
    } catch (e) {
      emit(state.copyWith(
        dataOpStatus: DataOpStatus.idle,
        dataError: 'Export failed: $e',
        exportedFile: null,
      ));
    }
  }

  void _onClearExportedFile(ClearExportedFile event, Emitter<SettingsState> emit) {
    emit(state.copyWith(exportedFile: null));
  }

  Future<void> _onImport(ImportData event, Emitter<SettingsState> emit) async {
    // Clear any previous import result to ensure listener triggers on next import
    emit(state.copyWith(
      dataOpStatus: DataOpStatus.importing,
      dataError: null,
      importResult: null,
    ));
    try {
      final result = await _jsonExport.importData(event.file);
      emit(state.copyWith(
        dataOpStatus: DataOpStatus.idle,
        importResult: result,
        dataError: result.error,
      ));
    } catch (e) {
      emit(state.copyWith(
        dataOpStatus: DataOpStatus.idle,
        dataError: 'Import failed: $e',
        importResult: null,
      ));
    }
  }
}
