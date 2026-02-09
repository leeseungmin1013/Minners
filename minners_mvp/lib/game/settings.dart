import 'package:shared_preferences/shared_preferences.dart';

class GameSettings {
  static final GameSettings _instance = GameSettings._();
  factory GameSettings() => _instance;
  GameSettings._();

  double musicVolume = 1.0;
  double sfxVolume = 1.0;
  bool autoSaveEnabled = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    musicVolume = prefs.getDouble('musicVolume') ?? 1.0;
    sfxVolume = prefs.getDouble('sfxVolume') ?? 1.0;
    autoSaveEnabled = prefs.getBool('autoSave') ?? true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', musicVolume);
    await prefs.setDouble('sfxVolume', sfxVolume);
    await prefs.setBool('autoSave', autoSaveEnabled);
  }
}
