import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'save_data.dart';

class SaveManager {
  static const String _saveDir = 'saves';
  static const int maxSlots = 10;

  Future<Directory> _getSaveDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_saveDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// List all saved games sorted by timestamp (newest first).
  Future<List<SaveMetadata>> listSaves() async {
    final dir = await _getSaveDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    final metas = <SaveMetadata>[];
    for (final file in files) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        metas.add(SaveMetadata.fromJson(json));
      } catch (_) {
        // Skip corrupted saves
      }
    }
    metas.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return metas;
  }

  /// Save a game. Overwrites if same ID exists.
  Future<void> save(SaveData data) async {
    final dir = await _getSaveDir();
    final file = File('${dir.path}/save_${data.id}.json');
    final json = jsonEncode(data.toJson());
    await file.writeAsString(json);
  }

  /// Load a complete SaveData from a save ID.
  Future<SaveData?> load(String saveId) async {
    final dir = await _getSaveDir();
    final file = File('${dir.path}/save_$saveId.json');
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return SaveData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Delete a save.
  Future<void> delete(String saveId) async {
    final dir = await _getSaveDir();
    final file = File('${dir.path}/save_$saveId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Check if any saves exist.
  Future<bool> hasSaves() async {
    final dir = await _getSaveDir();
    if (!await dir.exists()) return false;
    return dir
        .listSync()
        .whereType<File>()
        .any((f) => f.path.endsWith('.json'));
  }
}
