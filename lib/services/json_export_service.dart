import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/category.dart';
import 'database_service.dart';
import 'photo_storage_service.dart';

class ImportResult {
  final int itemsImported;
  final int categoriesImported;
  final String? error;

  const ImportResult({
    this.itemsImported = 0,
    this.categoriesImported = 0,
    this.error,
  });
}

class JsonExportService {
  final DatabaseService _db;
  final PhotoStorageService _photoStorage;

  JsonExportService(this._db, this._photoStorage);

  /// Exports all data + photos as a ZIP archive.
  ///
  /// DB reads and platform-channel path resolution happen on the main isolate,
  /// then the CPU- and I/O-heavy work (reading every image file, building the
  /// Archive, encoding the ZIP, writing it to disk) is shipped to a background
  /// isolate so the UI keeps animating.
  Future<File> exportData() async {
    final items = await _db.getAllItems();
    final categories = await _db.getAllCategories();

    // Build category id → name map
    final categoryNameMap = <String, String>{};
    for (final cat in categories) {
      categoryNameMap[cat.categoryId] = cat.name;
    }

    // Build manifest JSON (string form, serializable across isolates)
    final manifest = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => {
        'name': c.name,
        if (c.emoji != null) 'emoji': c.emoji,
      }).toList(),
      'items': items.map((item) {
        return {
          'name': item.name,
          'description': item.description,
          'ranking': item.ranking,
          'rating_count': item.ratingCount,
          'categories': item.categories
              .map((id) => categoryNameMap[id])
              .where((name) => name != null)
              .toList(),
          'images': item.images,
          'thumbnail_image': item.thumbnailImage,
          'created_at': item.createdAt.toIso8601String(),
          'updated_at': item.updatedAt.toIso8601String(),
        };
      }).toList(),
    };
    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);

    // Resolve every image's absolute path here (uses path_provider → main isolate only).
    final imagesToZip = <Map<String, String>>[];
    final addedPaths = <String>{};
    for (final item in items) {
      for (final imagePath in item.images) {
        if (!addedPaths.contains(imagePath)) {
          addedPaths.add(imagePath);
          imagesToZip.add({
            'archive': imagePath,
            'abs': await _photoStorage.resolvePhotoPath(imagePath),
          });
        }
        final segPath = _segmentedPath(imagePath);
        if (!addedPaths.contains(segPath)) {
          addedPaths.add(segPath);
          imagesToZip.add({
            'archive': segPath,
            'abs': await _photoStorage.resolvePhotoPath(segPath),
          });
        }
      }
      if (item.thumbnailImage != null && !addedPaths.contains(item.thumbnailImage!)) {
        addedPaths.add(item.thumbnailImage!);
        imagesToZip.add({
          'archive': item.thumbnailImage!,
          'abs': await _photoStorage.resolvePhotoPath(item.thumbnailImage!),
        });
      }
    }

    // Resolve output path (uses path_provider → main isolate only).
    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(tempDir.path, 'broom_export.zip');

    // Ship the heavy work to a background isolate.
    await Isolate.run(() => _buildZipInIsolate(
      manifestJson: manifestJson,
      images: imagesToZip,
      outputPath: outputPath,
    ));

    return File(outputPath);
  }

  /// Runs inside a background isolate. Reads image bytes, builds the archive,
  /// encodes the ZIP, writes it to [outputPath]. All arguments are primitives
  /// / plain collections so they can cross the isolate boundary.
  static Future<void> _buildZipInIsolate({
    required String manifestJson,
    required List<Map<String, String>> images,
    required String outputPath,
  }) async {
    final archive = Archive();

    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    for (final img in images) {
      final archivePath = img['archive']!;
      final absPath = img['abs']!;
      try {
        final file = File(absPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
        }
      } catch (_) {
        // Skip missing files silently — same behavior as before.
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(zipBytes);
  }

  String _segmentedPath(String originalPath) {
    final dir = p.dirname(originalPath);
    final stem = p.basenameWithoutExtension(originalPath);
    return p.join(dir, '${stem}_seg.png');
  }

  /// Imports data from a ZIP archive with images.
  ///
  /// The ZIP decoding and image extraction run on a background isolate.
  /// DB inserts must stay on the main isolate (sqlite connection lives there),
  /// so the isolate returns a plain data structure which the main isolate
  /// iterates over to create records.
  Future<ImportResult> importData(File importFile) async {
    // Resolve photos dir on main isolate (path_provider).
    final appDir = await getApplicationDocumentsDirectory();
    final photosDirPath = p.join(appDir.path, 'photos');
    final photosDir = Directory(photosDirPath);
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final zipPath = importFile.path;

    // Heavy work in isolate: decode zip, parse manifest, extract images.
    final parsed = await Isolate.run(() => _parseAndExtractInIsolate(
      zipPath: zipPath,
      photosDirPath: photosDirPath,
    ));

    if (parsed['error'] != null) {
      return ImportResult(error: parsed['error'] as String);
    }

    // Back on main isolate: insert categories and items.
    final categoryList = parsed['categories'] as List;
    final categoryNameToId = <String, String>{};
    int categoriesImported = 0;

    for (final catData in categoryList) {
      final name = catData['name'] as String?;
      if (name == null || name.isEmpty) continue;
      final emoji = catData['emoji'] as String?;

      final id = const Uuid().v4();
      final category = Category(categoryId: id, name: name, emoji: emoji);
      await _db.insertCategory(category);
      categoryNameToId[name] = id;
      categoriesImported++;
    }

    final itemList = parsed['items'] as List;
    int itemsImported = 0;
    final now = DateTime.now();

    for (final itemData in itemList) {
      final name = itemData['name'] as String? ?? '';
      final description = itemData['description'] as String? ?? '';
      final ranking = (itemData['ranking'] as num?)?.toDouble() ?? 5.0;
      final ratingCount = itemData['rating_count'] as int? ?? 0;
      final categoryNames = (itemData['categories'] as List?)?.cast<String>() ?? [];
      final newImages = (itemData['new_images'] as List?)?.cast<String>() ?? [];
      final newThumbnail = itemData['new_thumbnail'] as String?;

      DateTime createdAt;
      try { createdAt = DateTime.parse(itemData['created_at'] as String); }
      catch (_) { createdAt = now; }

      DateTime updatedAt;
      try { updatedAt = DateTime.parse(itemData['updated_at'] as String); }
      catch (_) { updatedAt = now; }

      final categoryIds = categoryNames
          .map((n) => categoryNameToId[n])
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final item = Item(
        itemId: const Uuid().v4(),
        name: name,
        description: description,
        ranking: ranking,
        ratingCount: ratingCount,
        categories: categoryIds,
        images: newImages,
        thumbnailImage: newThumbnail ?? (newImages.isNotEmpty ? newImages.first : null),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      await _db.insertItem(item);
      itemsImported++;
    }

    return ImportResult(
      itemsImported: itemsImported,
      categoriesImported: categoriesImported,
    );
  }

  /// Runs inside a background isolate. Opens the ZIP, parses the manifest,
  /// extracts every referenced image to [photosDirPath] with a fresh UUID
  /// filename, and returns the parsed manifest with old→new image paths
  /// already remapped. Returns `{'error': String}` on failure.
  static Future<Map<String, dynamic>> _parseAndExtractInIsolate({
    required String zipPath,
    required String photosDirPath,
  }) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return {'error': 'No manifest.json found in archive'};
      }
      final manifestContent = utf8.decode(manifestFile.content as List<int>);
      final data = jsonDecode(manifestContent) as Map<String, dynamic>;

      if (data['categories'] is! List || data['items'] is! List) {
        return {'error': 'Invalid manifest structure'};
      }

      // Extract images, building an old-path → new-relative-path mapping.
      final itemList = data['items'] as List;
      final processedItems = <Map<String, dynamic>>[];
      final pathCache = <String, String>{};

      Future<String?> extract(String archivePath) async {
        if (pathCache.containsKey(archivePath)) return pathCache[archivePath];
        final file = archive.findFile(archivePath);
        if (file == null) return null;
        final ext = p.extension(archivePath);
        final newFilename = '${const Uuid().v4()}$ext';
        final destPath = p.join(photosDirPath, newFilename);
        await File(destPath).writeAsBytes(file.content as List<int>);
        final newRelative = p.join('photos', newFilename);
        pathCache[archivePath] = newRelative;
        return newRelative;
      }

      String segmentedPath(String originalPath) {
        final dir = p.dirname(originalPath);
        final stem = p.basenameWithoutExtension(originalPath);
        return p.join(dir, '${stem}_seg.png');
      }

      for (final rawItem in itemList) {
        final itemData = Map<String, dynamic>.from(rawItem as Map);
        final oldImages = (itemData['images'] as List?)?.cast<String>() ?? [];
        final oldThumbnail = itemData['thumbnail_image'] as String?;

        final newImages = <String>[];
        for (final oldPath in oldImages) {
          final newPath = await extract(oldPath);
          if (newPath != null) newImages.add(newPath);
          // Also extract segmented sibling if present in archive.
          await extract(segmentedPath(oldPath));
        }

        String? newThumbnail;
        if (oldThumbnail != null) {
          newThumbnail = pathCache[oldThumbnail] ?? await extract(oldThumbnail);
        }

        itemData['new_images'] = newImages;
        itemData['new_thumbnail'] = newThumbnail;
        processedItems.add(itemData);
      }

      return {
        'categories': data['categories'],
        'items': processedItems,
      };
    } catch (e) {
      return {'error': 'Failed to import: ${e.toString()}'};
    }
  }
}
