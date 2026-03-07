import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

/// Manages user identity (CallGuard ID).
class UserService {
  static const String _key = 'callguard_user_id';

  /// Returns the stored user ID, or generates and persists a new one.
  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null) {
      id = _generateId();
      await prefs.setString(_key, id);
    }
    return id;
  }

  /// Generates a random 6-digit numeric ID.
  static String _generateId() {
    final random = Random();
    return List.generate(
      AppConfig.idLength,
      (_) => random.nextInt(10).toString(),
    ).join();
  }
}
