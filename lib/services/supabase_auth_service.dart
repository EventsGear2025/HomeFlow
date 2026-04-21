import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class SupabaseAuthService {
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

  UserRole inferRoleFromMetadata(User user) {
    final role = user.userMetadata?['role']?.toString();
    return role == UserRole.houseManager.name
        ? UserRole.houseManager
        : UserRole.owner;
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
}
