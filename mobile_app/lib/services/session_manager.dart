import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Manages user session persistence and auto-login
class SessionManager {
  static const String _sessionBoxName = 'session';
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  static const String _lastLoginKey = 'last_login';

  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_sessionBoxName)) {
      await Hive.openBox(_sessionBoxName);
    }
  }

  /// Save user session after successful login
  static Future<void> saveSession(User user, {String? token}) async {
    final box = Hive.box(_sessionBoxName);
    await box.put(_userKey, user);
    if (token != null) {
      await box.put(_tokenKey, token);
    }
    await box.put(_lastLoginKey, DateTime.now().toIso8601String());
  }

  /// Restore user from local session
  static User? getStoredUser() {
    try {
      final box = Hive.box(_sessionBoxName);
      return box.get(_userKey) as User?;
    } catch (e) {
      print('Error retrieving user: $e');
      return null;
    }
  }

  /// Check if user has active session
  static bool hasActiveSession() {
    return getStoredUser() != null;
  }

  /// Get stored auth token
  static String? getStoredToken() {
    try {
      final box = Hive.box(_sessionBoxName);
      return box.get(_tokenKey) as String?;
    } catch (e) {
      return null;
    }
  }

  /// Clear session on logout
  static Future<void> clearSession() async {
    final box = Hive.box(_sessionBoxName);
    await box.delete(_userKey);
    await box.delete(_tokenKey);
    await box.delete(_lastLoginKey);
  }

  /// Get last login timestamp
  static DateTime? getLastLogin() {
    try {
      final box = Hive.box(_sessionBoxName);
      final dateStr = box.get(_lastLoginKey) as String?;
      if (dateStr != null) {
        return DateTime.parse(dateStr);
      }
    } catch (e) {
      print('Error getting last login: $e');
    }
    return null;
  }
}
