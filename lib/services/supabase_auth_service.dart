import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class SupabaseAuthService {
  static String? _cachedAdminAccessUserId;
  static bool? _cachedAdminAccess;

  Session? get currentSession {
    try {
      return SupabaseService.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  bool get isReady {
    try {
      return SupabaseService.client.auth.currentSession != null || true;
    } catch (_) {
      return false;
    }
  }

  User? get currentSupabaseUser {
    try {
      return SupabaseService.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get hasActiveSession => currentSupabaseUser != null;

  Map<String, dynamic>? get currentAccessTokenClaims {
    final token = currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) return Map<String, dynamic>.from(json);
    } catch (error) {
      debugPrint('Supabase access token decode error: $error');
    }

    return null;
  }

  String? get currentAppRole => currentAccessTokenClaims?['app_role']?.toString();

  bool get hasAdminAppRole => currentAppRole == 'admin';

  bool get hasCachedAdminAccess {
    final userId = currentSupabaseUser?.id;
    return userId != null &&
        _cachedAdminAccessUserId == userId &&
        (_cachedAdminAccess ?? false);
  }

  Future<bool> hasAdminAccess({bool refresh = false}) async {
    final session = currentSession;
    if (session == null) {
      _clearAdminAccessCache();
      return false;
    }

    if (hasAdminAppRole) {
      _cacheAdminAccess(session.user.id, true);
      return true;
    }

    final user = currentSupabaseUser;
    if (user == null) {
      _clearAdminAccessCache();
      return false;
    }

    if (!refresh &&
        _cachedAdminAccessUserId == user.id &&
        _cachedAdminAccess != null) {
      return _cachedAdminAccess!;
    }

    final hasFallbackAccess = await _hasActiveAdminUser(user);
    _cacheAdminAccess(user.id, hasFallbackAccess);
    return hasFallbackAccess;
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return SupabaseService.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<void> signOut() async {
    _clearAdminAccessCache();
    try {
      await SupabaseService.auth.signOut();
    } catch (error) {
      debugPrint('Supabase signOut skipped: $error');
    }
  }

  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      await SupabaseService.auth.updateUser(UserAttributes(data: data));
    } catch (error) {
      debugPrint('Supabase updateUserMetadata error: $error');
    }
  }

  UserRole inferRoleValue(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'house_manager':
      case 'housemanager':
      case 'manager':
        return UserRole.houseManager;
      default:
        return UserRole.owner;
    }
  }

  UserRole inferRoleFromMetadata(User user) {
    return inferRoleValue(user.userMetadata?['role']?.toString());
  }

  Future<void> signInWithGoogle() async {
    await SupabaseService.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.example.myapp://login-callback/',
    );
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) {
    return SupabaseService.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<void> resendOtp({required String email}) async {
    await SupabaseService.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  Future<bool> _hasActiveAdminUser(User user) async {
    try {
      final profileMatches = await SupabaseService.client
          .from('admin_users')
          .select('status')
          .eq('profile_id', user.id)
          .limit(1);
      final profileStatus = _extractAdminStatus(profileMatches);
      if (profileStatus != null) {
        return profileStatus != 'disabled';
      }

      final email = user.email?.trim();
      if (email != null && email.isNotEmpty) {
        final emailMatches = await SupabaseService.client
            .from('admin_users')
            .select('status')
            .ilike('email', email)
            .limit(1);
        final emailStatus = _extractAdminStatus(emailMatches);
        if (emailStatus != null) {
          return emailStatus != 'disabled';
        }
      }
    } catch (error) {
      debugPrint('Supabase admin access lookup error: $error');
    }

    return false;
  }

  String? _extractAdminStatus(dynamic rows) {
    if (rows is! List || rows.isEmpty) return null;

    final first = rows.first;
    if (first is! Map) return null;

    final normalized = Map<String, dynamic>.from(first);
    return normalized['status']?.toString().toLowerCase();
  }

  void _cacheAdminAccess(String userId, bool value) {
    _cachedAdminAccessUserId = userId;
    _cachedAdminAccess = value;
  }

  void _clearAdminAccessCache() {
    _cachedAdminAccessUserId = null;
    _cachedAdminAccess = null;
  }
}
