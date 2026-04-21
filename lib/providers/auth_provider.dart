import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/household_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_auth_service.dart';
import '../services/sync_service.dart';
import '../utils/app_constants.dart';

const String kBuildOwnerEmail = 'owner@homeflow.app';
const String kBuildManagerEmail = 'manager@homeflow.app';
const String kBuildPassword = 'home1234';
const String kBuildManagerInviteCode = 'HFOWNER1';
const String kBuildHouseholdId = 'build-household-homeflow';
const String kBuildOwnerId = 'build-owner-homeflow';
const String kBuildManagerId = 'build-manager-homeflow';

/// DEBUG ONLY — set to true to preview Home Pro features regardless of plan
const bool kDebugForceHomePro = true;

class AuthProvider extends ChangeNotifier {
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();
  UserModel? _currentUser;
  HouseholdModel? _household;
  List<UserModel> _householdMembers = [];
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  HouseholdModel? get household => _household;
  List<UserModel> get householdMembers => _householdMembers;
  List<UserModel> get managers =>
      _householdMembers.where((u) => u.role == UserRole.houseManager).toList();
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isHouseManager => _currentUser?.isHouseManager ?? false;
  PlanType get householdPlanType => _household?.planType ?? PlanType.free;
  bool get isHomePro => kDebugForceHomePro || (_household?.isHomePro ?? false);
  int get maxChildrenAllowed => isHomePro ? 9999 : AppConstants.freeMaxChildren;
  String get householdPlanLabel => _household?.planLabel ?? 'Free';

  // ── Phone helpers ────────────────────────────────────────────────────────
  static bool looksLikePhone(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    return RegExp(r'^(\+254|0)?[17]\d{8}$').hasMatch(cleaned);
  }

  static String normalizePhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('+254')) return p;
    if (p.startsWith('0') && p.length == 10) return '+254${p.substring(1)}';
    if (p.length == 9) return '+254$p';
    return p;
  }

  static String phoneToEmail(String phone) {
    final normalized = normalizePhone(phone);
    return '${normalized.replaceAll('+', '')}@homeflow.mgr';
  }

  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (supabaseUser != null) {
      final householdId = supabaseUser.userMetadata?['household_id']?.toString() ?? '';
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: (supabaseUser.userMetadata?['full_name']?.toString().trim().isNotEmpty ?? false)
            ? supabaseUser.userMetadata!['full_name'].toString().trim()
            : (supabaseUser.email?.split('@').first ?? 'HomeFlow User'),
        email: supabaseUser.email ?? '',
        role: _supabaseAuthService.inferRoleFromMetadata(supabaseUser),
        householdId: householdId,
      );
      if (householdId.isNotEmpty) {
        final row = await SyncService.loadHousehold(householdId);
        _household = row != null ? HouseholdModel.fromSupabaseRow(row) : null;
      } else {
        _household = null;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      if (_household != null) {
        final householdJson = jsonEncode(_household!.toJson());
        await prefs.setString('household', householdJson);
        await prefs.setString('household_${_household!.id}', householdJson);
        await _saveMember(_currentUser!, prefs);
      }
      await _loadHouseholdMembers(prefs);
      _isLoading = false;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await _ensureBuildDemoAccounts(prefs);
    final userJson = prefs.getString('current_user');
    final householdJson = prefs.getString('household');

    if (userJson != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userJson));
    } else {
      // Auto-login as demo owner on fresh install so all features are
      // immediately visible without a manual login step.
      final ownerJson = prefs.getString(
          'household_member_${kBuildHouseholdId}_$kBuildOwnerId');
      if (ownerJson != null) {
        _currentUser = UserModel.fromJson(jsonDecode(ownerJson));
        await prefs.setString('current_user', ownerJson);
      }
    }

    if (householdJson != null) {
      _household = HouseholdModel.fromJson(jsonDecode(householdJson));
    } else if (_currentUser != null) {
      final hJson = prefs.getString('household_${_currentUser!.householdId}');
      if (hJson != null) {
        _household = HouseholdModel.fromJson(jsonDecode(hJson));
        await prefs.setString('household', hJson);
      }
    }
    await _loadHouseholdMembers(prefs);

    _isLoading = false;
    notifyListeners();
  }

  // ── Legacy signUp() — replaced by the two-step signUpOwner/signUpManagerPreStep
  // flows that require email OTP verification before any household is created.
  // Kept stub here so call sites outside SignUpScreen get a clear error.
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? householdName,
    String? householdId,
  }) async {
    throw UnimplementedError(
      'Use signUpOwner + completeOwnerSetup (owner) or '
      'signUpManagerPreStep + completeManagerSetup (manager) instead.',
    );
  }

  // ignore: unused_element
  Future<void> _signUpLegacy({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? householdName,
    String? householdId,
  }) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await _ensureBuildDemoAccounts(prefs);
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == kBuildOwnerEmail || normalizedEmail == kBuildManagerEmail) {
      _isLoading = false;
      notifyListeners();
      throw Exception('This demo account is reserved for build testing. Please sign in with the shared credentials instead.');
    }

    // ── Try Supabase sign-up first ─────────────────────────────────────────
    if (SyncService.isAvailable || true) { // always try if Supabase is configured
      try {
        final authResp = await _supabaseAuthService.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName, 'role': role.name},
        );
        final supabaseUser = authResp.user;
        if (supabaseUser != null) {
          String hId;
          String inviteCode;

          if (role == UserRole.owner) {
            inviteCode = _generateInviteCode();
            final hhName = householdName ?? "${fullName.split(' ').first}'s Home";
            final createdId = await SyncService.createHousehold(
              name: hhName,
              inviteCode: inviteCode,
            );
            if (createdId == null) {
              throw Exception('Supabase household creation failed');
            }
            hId = createdId;
            // Register owner as household member
            await SyncService.ensureHouseholdMember(hId, 'owner');
            // Store household_id in user metadata
            await _supabaseAuthService.updateUserMetadata({
              'household_id': hId,
              'role': 'owner',
              'full_name': fullName,
            });
            _household = HouseholdModel(
              id: hId,
              householdName: hhName,
              createdBy: supabaseUser.id,
              ownerInviteCode: inviteCode,
              createdAt: DateTime.now(),
            );
          } else {
            // Manager: join via invite code
            // Pass supabaseUser.id explicitly — signUp may not establish a
            // session yet if email confirmation is enabled.
            final code = householdId?.trim().toUpperCase() ?? '';
            final joinedId = await SyncService.joinHouseholdByInviteCode(
              code,
              userId: supabaseUser.id,
            );
            if (joinedId == null) {
              throw Exception('Could not join household. Please check your connection and try again.');
            }
            hId = joinedId;
            await _supabaseAuthService.updateUserMetadata({
              'household_id': hId,
              'role': 'house_manager',
              'full_name': fullName,
            });
            final row = await SyncService.loadHousehold(hId);
            inviteCode = row?['invite_code']?.toString() ?? '';
            _household = row != null
                ? HouseholdModel.fromSupabaseRow(row)
                : HouseholdModel(
                    id: hId,
                    householdName: 'Household',
                    createdBy: '',
                    ownerInviteCode: inviteCode,
                    createdAt: DateTime.now(),
                  );
          }

          _currentUser = UserModel(
            id: supabaseUser.id,
            fullName: fullName,
            email: email.trim(),
            role: role,
            householdId: hId,
          );

          // Cache locally for offline resilience
          await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
          await prefs.setString('household', jsonEncode(_household!.toJson()));
          await prefs.setString('household_${_household!.id}', jsonEncode(_household!.toJson()));
          await _saveMember(_currentUser!, prefs);
          await _loadHouseholdMembers(prefs);

          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Supabase signUp failed, falling back to local: $e');
        // Rethrow invite-code and join errors so the UI can show the right message
        if (e.toString().contains('Invalid sign-up code') ||
            e.toString().contains('Invalid invite code') ||
            e.toString().contains('Could not join household')) {
          _isLoading = false;
          notifyListeners();
          rethrow;
        }
        // Otherwise fall through to local sign-up
      }
    }

    // ── Local-only fallback (demo / offline) ───────────────────────────────
    const uuid = Uuid();
    final userId = uuid.v4();
    String hId;

    if (role == UserRole.owner) {
      hId = uuid.v4();
      final inviteCode = _generateInviteCode();
      _household = HouseholdModel(
        id: hId,
        householdName: householdName ?? "${fullName.split(' ').first}'s Home",
        createdBy: userId,
        ownerInviteCode: inviteCode,
        createdAt: DateTime.now(),
      );
      await prefs.setString('household', jsonEncode(_household!.toJson()));
      await prefs.setString('household_$hId', jsonEncode(_household!.toJson()));
    } else {
      final inviteCode = householdId?.trim().toUpperCase();
      final linkedHousehold = await _findHouseholdByInviteCode(prefs, inviteCode);
      if (linkedHousehold == null) {
        _isLoading = false;
        notifyListeners();
        throw Exception('Invalid sign-up code. Please confirm the code from the homeowner.');
      }
      hId = linkedHousehold.id;
      _household = linkedHousehold;
      await prefs.setString('household', jsonEncode(_household!.toJson()));
    }

    _currentUser = UserModel(
      id: userId,
      fullName: fullName,
      email: email,
      role: role,
      householdId: hId,
    );

    await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
    await _saveMember(_currentUser!, prefs);
    await _loadHouseholdMembers(prefs);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Detect phone number and convert to synthetic email
    final loginEmail = looksLikePhone(email.trim())
        ? phoneToEmail(email.trim())
        : email.trim();

    try {
      await _supabaseAuthService.signInWithPassword(
        email: loginEmail,
        password: password,
      ).timeout(const Duration(seconds: 6));
      final supabaseUser = _supabaseAuthService.currentSupabaseUser;
      if (supabaseUser != null) {
        final hId = supabaseUser.userMetadata?['household_id']?.toString() ?? '';
        _currentUser = UserModel(
          id: supabaseUser.id,
          fullName: (supabaseUser.userMetadata?['full_name']?.toString().trim().isNotEmpty ?? false)
              ? supabaseUser.userMetadata!['full_name'].toString().trim()
              : (supabaseUser.email?.split('@').first ?? 'HomeFlow User'),
          email: supabaseUser.email ?? loginEmail,
          role: _supabaseAuthService.inferRoleFromMetadata(supabaseUser),
          householdId: hId,
        );
        if (hId.isNotEmpty) {
          final row = await SyncService.loadHousehold(hId);
          if (row != null) _household = HouseholdModel.fromSupabaseRow(row);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
        if (_household != null) {
          final hJson = jsonEncode(_household!.toJson());
          await prefs.setString('household', hJson);
          await prefs.setString('household_${_household!.id}', hJson);
          await _saveMember(_currentUser!, prefs);
        }
        await _loadHouseholdMembers(prefs);
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      // Any Supabase/network error → fall through to offline demo auth.
      debugPrint('[AuthProvider.login] Supabase error: $e');
    }

    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    await _ensureBuildDemoAccounts(prefs);
    if (password != kBuildPassword) {
      _currentUser = null;
      _household = null;
      _householdMembers = [];
      _isLoading = false;
      notifyListeners();
      return;
    }
    final normalizedEmail = email.trim().toLowerCase();
    final userJson = await _findUserJsonByEmail(prefs, normalizedEmail);
    if (userJson != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userJson));
      final householdJson = await _findHouseholdJsonById(
        prefs,
        _currentUser!.householdId,
      );
      if (householdJson != null) {
        _household = HouseholdModel.fromJson(jsonDecode(householdJson));
        await prefs.setString('household', householdJson);
      }
      await prefs.setString('current_user', userJson);
      await _loadHouseholdMembers(prefs);
    } else {
      _currentUser = null;
      _household = null;
      _householdMembers = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    await _supabaseAuthService.signOut();
    _currentUser = null;
    _household = null;
    _householdMembers = [];
    notifyListeners();
  }

  Future<void> addHouseManager({
    required String fullName,
    required String email,
  }) async {
    if (_household == null) return;
    final prefs = await SharedPreferences.getInstance();
    const uuid = Uuid();
    final manager = UserModel(
      id: uuid.v4(),
      fullName: fullName,
      email: email,
      role: UserRole.houseManager,
      householdId: _household!.id,
    );
    await _saveMember(manager, prefs);
    await _loadHouseholdMembers(prefs);
    notifyListeners();
  }

  Future<void> removeHouseManager(String userId) async {
    if (_household == null) return;
    // Delete from Supabase first (revokes RLS access immediately)
    await SyncService.removeHouseholdMember(
      householdId: _household!.id,
      userId: userId,
    );
    // Then clean up local cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('household_member_${_household!.id}_$userId');
    await _loadHouseholdMembers(prefs);
    notifyListeners();
  }

  /// Called when the manager chooses to leave the household.
  /// Revokes Supabase membership, clears local state, then signs out.
  Future<void> leaveHousehold() async {
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (_household != null && supabaseUser != null) {
      await SyncService.removeHouseholdMember(
        householdId: _household!.id,
        userId: supabaseUser.id,
      );
      // Clear household_id from auth metadata so on next login they land
      // in an unlinked state and can join a new household.
      try {
        await _supabaseAuthService.updateUserMetadata({'household_id': null});
      } catch (_) {}
    }
    // Clear all local state and sign out
    await logout();
  }

  String get ownerInviteCode => _household?.ownerInviteCode ?? '';

  // ── Owner signup: step 1 – register only, no household yet ───────────────
  Future<void> signUpOwner({
    required String fullName,
    required String email,
    required String password,
    required String householdName,
  }) async {
    _isLoading = true;
    notifyListeners();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == kBuildOwnerEmail || normalizedEmail == kBuildManagerEmail) {
      _isLoading = false;
      notifyListeners();
      throw Exception('This email is reserved. Please use a different email address.');
    }
    try {
      debugPrint('[signUpOwner] Signing up with email: $normalizedEmail');
      final resp = await _supabaseAuthService.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'owner',
          'pending_household': householdName,
        },
      ).timeout(const Duration(seconds: 10));

      // Supabase returns empty identities when the email is already registered
      // but unconfirmed. In that case, resend the OTP so the user can proceed.
      final identities = resp.user?.identities;
      if (identities != null && identities.isEmpty) {
        debugPrint('[signUpOwner] User already exists, resending OTP');
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: normalizedEmail,
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('[signUpOwner] error: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Owner signup: step 2 – called after OTP verified ─────────────────────
  Future<void> completeOwnerSetup({
    required String fullName,
    required String email,
    required String householdName,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final supabaseUser = _supabaseAuthService.currentSupabaseUser;
      if (supabaseUser == null) throw Exception('Session not found. Please sign in again.');

      final inviteCode = _generateInviteCode();
      final createdId = await SyncService.createHousehold(
        name: householdName,
        inviteCode: inviteCode,
      );
      if (createdId == null) throw Exception('Household creation failed. Please try again.');

      await SyncService.ensureHouseholdMember(
        createdId,
        'owner',
        fullName: fullName,
        displayEmail: email,
      );
      await _supabaseAuthService.updateUserMetadata({
        'household_id': createdId,
        'role': 'owner',
        'full_name': fullName,
      });

      _household = HouseholdModel(
        id: createdId,
        householdName: householdName,
        createdBy: supabaseUser.id,
        ownerInviteCode: inviteCode,
        createdAt: DateTime.now(),
      );
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: email,
        role: UserRole.owner,
        householdId: createdId,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await prefs.setString('household', jsonEncode(_household!.toJson()));
      await prefs.setString('household_${_household!.id}', jsonEncode(_household!.toJson()));
      await _saveMember(_currentUser!, prefs);
      await _loadHouseholdMembers(prefs);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Manager signup: step 1 – register email, send OTP (no household join yet)
  Future<void> signUpManagerPreStep({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == kBuildOwnerEmail || normalizedEmail == kBuildManagerEmail) {
      _isLoading = false;
      notifyListeners();
      throw Exception('This email is reserved. Please use a different email address.');
    }
    try {
      debugPrint('[signUpManagerPreStep] Signing up with email: $normalizedEmail');
      final resp = await _supabaseAuthService.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'house_manager',
        },
      ).timeout(const Duration(seconds: 10));

      final identities = resp.user?.identities;
      if (identities != null && identities.isEmpty) {
        debugPrint('[signUpManagerPreStep] User already exists, resending OTP');
        await Supabase.instance.client.auth.resend(
          type: OtpType.signup,
          email: normalizedEmail,
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('[signUpManagerPreStep] error: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Manager signup: step 2 – called after OTP verified, joins household ──
  Future<void> completeManagerSetup({
    required String fullName,
    required String email,
    required String inviteCode,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final supabaseUser = _supabaseAuthService.currentSupabaseUser;
      if (supabaseUser == null) throw Exception('Session not found. Please sign in again.');

      final code = inviteCode.trim().toUpperCase();
      final joinedId = await SyncService.joinHouseholdByInviteCode(
        code,
        userId: supabaseUser.id,
      );
      if (joinedId == null) {
        throw Exception('Could not join household. Please check your connection and try again.');
      }

      await _supabaseAuthService.updateUserMetadata({
        'household_id': joinedId,
        'role': 'house_manager',
        'full_name': fullName,
      });
      // Store name+email in the members table so the owner can see them.
      await SyncService.ensureHouseholdMember(
        joinedId,
        'house_manager',
        fullName: fullName,
        displayEmail: email.trim().toLowerCase(),
      );

      final row = await SyncService.loadHousehold(joinedId);
      _household = row != null
          ? HouseholdModel.fromSupabaseRow(row)
          : HouseholdModel(
              id: joinedId,
              householdName: 'Household',
              createdBy: '',
              ownerInviteCode: code,
              createdAt: DateTime.now(),
            );
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: email.trim().toLowerCase(),
        role: UserRole.houseManager,
        householdId: joinedId,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await prefs.setString('household', jsonEncode(_household!.toJson()));
      await _saveMember(_currentUser!, prefs);
      await _loadHouseholdMembers(prefs);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Manager signup – phone-based, invite code as verification ────────────
  Future<void> signUpManager({
    required String fullName,
    required String phone,
    required String password,
    required String inviteCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final email = phoneToEmail(phone);
    final normalizedPhone = normalizePhone(phone);

    try {
      final authResp = await _supabaseAuthService.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'house_manager',
          'phone': normalizedPhone,
        },
      );
      final supabaseUser = authResp.user;
      if (supabaseUser == null) throw Exception('Account creation failed. Please try again.');

      final code = inviteCode.trim().toUpperCase();
      // Pass supabaseUser.id explicitly — signUp may not establish a
      // session yet (email-confirmation flow), so auth.uid() inside the
      // RPC would be null without this.
      final joinedId = await SyncService.joinHouseholdByInviteCode(
        code,
        userId: supabaseUser.id,
      );
      if (joinedId == null) {
        throw Exception('Could not join household. Please check your connection and try again.');
      }


      await _supabaseAuthService.updateUserMetadata({
        'household_id': joinedId,
        'role': 'house_manager',
        'full_name': fullName,
        'phone': normalizedPhone,
      });

      final row = await SyncService.loadHousehold(joinedId);
      _household = row != null
          ? HouseholdModel.fromSupabaseRow(row)
          : HouseholdModel(
              id: joinedId,
              householdName: 'Household',
              createdBy: '',
              ownerInviteCode: code,
              createdAt: DateTime.now(),
            );
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: normalizedPhone, // display the phone, not synthetic email
        role: UserRole.houseManager,
        householdId: joinedId,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await prefs.setString('household', jsonEncode(_household!.toJson()));
      await _saveMember(_currentUser!, prefs);
      await _loadHouseholdMembers(prefs);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabaseAuthService.signInWithGoogle();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
    // Session is set asynchronously via deep link; caller listens to auth stream
    _isLoading = false;
    notifyListeners();
  }

  // ── Called after Google OAuth deep-link returns ───────────────────────────
  // Returns true if the user already has a household set up.
  Future<bool> loadAfterOAuth() async {
    _isLoading = true;
    notifyListeners();
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (supabaseUser == null) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
    final hId = supabaseUser.userMetadata?['household_id']?.toString() ?? '';
    final fullName = (supabaseUser.userMetadata?['full_name']?.toString().trim().isNotEmpty ?? false)
        ? supabaseUser.userMetadata!['full_name'].toString().trim()
        : (supabaseUser.email?.split('@').first ?? 'Owner');

    _currentUser = UserModel(
      id: supabaseUser.id,
      fullName: fullName,
      email: supabaseUser.email ?? '',
      role: UserRole.owner,
      householdId: hId,
    );
    _household = null;

    if (hId.isNotEmpty) {
      final row = await SyncService.loadHousehold(hId);
      if (row != null) _household = HouseholdModel.fromSupabaseRow(row);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
    if (_household != null) {
      await prefs.setString('household', jsonEncode(_household!.toJson()));
      await prefs.setString('household_${_household!.id}', jsonEncode(_household!.toJson()));
    }
    _isLoading = false;
    notifyListeners();
    return _household != null;
  }

  String _generateInviteCode() {
    const uuid = Uuid();
    return uuid.v4().substring(0, 8).toUpperCase();
  }

  /// Converts raw Supabase / dart:io exceptions into short, user-readable strings.
  String _friendlyAuthError(Object e) {
    final msg = e.toString();
    // Already a friendly message from this provider
    if (e is Exception &&
        (msg.contains('Invalid invite code') ||
            msg.contains('Invalid sign-up code') ||
            msg.contains('Could not join household') ||
            msg.contains('Session not found') ||
            msg.contains('Household creation failed') ||
            msg.contains('Account creation failed') ||
            msg.contains('reserved'))) {
      return msg.replaceFirst('Exception: ', '');
    }
    // Network / DNS failures
    if (msg.contains('SocketException') ||
        msg.contains('SocketFailed') ||
        msg.contains('Failed host lookup') ||
        msg.contains('No address associated') ||
        msg.contains('ClientException') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Connection refused') ||
        msg.contains('TimeoutException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    // Supabase auth errors
    if (msg.contains('User already registered') ||
        msg.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    if (msg.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    }
    // Fallback — strip the "Exception:" prefix Flutter adds
    return msg.replaceFirst('Exception: ', '');
  }

  Future<void> _ensureBuildDemoAccounts(SharedPreferences prefs) async {
    final household = HouseholdModel(
      id: kBuildHouseholdId,
      householdName: 'HomeFlow Demo Home',
      createdBy: kBuildOwnerId,
      ownerInviteCode: kBuildManagerInviteCode,
      createdAt: DateTime(2026, 3, 23),
    );
    final owner = UserModel(
      id: kBuildOwnerId,
      fullName: 'Demo Home Owner',
      email: kBuildOwnerEmail,
      role: UserRole.owner,
      householdId: kBuildHouseholdId,
      createdAt: DateTime(2026, 3, 23),
    );
    final manager = UserModel(
      id: kBuildManagerId,
      fullName: 'Demo House Manager',
      email: kBuildManagerEmail,
      role: UserRole.houseManager,
      householdId: kBuildHouseholdId,
      createdAt: DateTime(2026, 3, 23),
    );

    await prefs.setString(
      'household_$kBuildHouseholdId',
      jsonEncode(household.toJson()),
    );
    await prefs.setString(
      'household_member_${owner.householdId}_${owner.id}',
      jsonEncode(owner.toJson()),
    );
    await prefs.setString(
      'household_member_${manager.householdId}_${manager.id}',
      jsonEncode(manager.toJson()),
    );
  }

  Future<String?> _findUserJsonByEmail(
    SharedPreferences prefs,
    String email,
  ) async {
    if (email == kBuildOwnerEmail) {
      return prefs.getString('household_member_${kBuildHouseholdId}_$kBuildOwnerId');
    }
    if (email == kBuildManagerEmail) {
      return prefs.getString('household_member_${kBuildHouseholdId}_$kBuildManagerId');
    }
    final keys = prefs.getKeys();
    for (final key in keys.where((k) => k.startsWith('household_member_'))) {
      final json = prefs.getString(key);
      if (json == null) continue;
      final user = UserModel.fromJson(jsonDecode(json));
      if (user.email.toLowerCase() == email) {
        return json;
      }
    }
    return null;
  }

  Future<String?> _findHouseholdJsonById(
    SharedPreferences prefs,
    String householdId,
  ) async {
    return prefs.getString('household_$householdId') ?? prefs.getString('household');
  }

  Future<void> _saveMember(UserModel user, SharedPreferences prefs) async {
    await prefs.setString(
      'household_member_${user.householdId}_${user.id}',
      jsonEncode(user.toJson()),
    );
  }

  Future<void> _loadHouseholdMembers(SharedPreferences prefs) async {
    if (_household == null) {
      _householdMembers = [];
      return;
    }

    // Try Supabase first — this is the source of truth and ensures the owner
    // sees managers who joined on other devices (and vice versa).
    final rows = await SyncService.fetchHouseholdMembers(_household!.id);
    if (rows != null && rows.isNotEmpty) {
      _householdMembers = rows.map((row) {
        final roleStr = row['role'] as String? ?? 'owner';
        return UserModel(
          id: (row['user_id'] as Object).toString(),
          fullName: row['full_name'] as String? ?? '',
          email: row['display_email'] as String? ?? '',
          role: roleStr == 'owner' ? UserRole.owner : UserRole.houseManager,
          householdId: (row['household_id'] as Object).toString(),
        );
      }).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      // Persist to local cache for offline use.
      for (final m in _householdMembers) {
        await _saveMember(m, prefs);
      }
      return;
    }

    // Fall back to local SharedPreferences when Supabase is unavailable.
    final allKeys = prefs.getKeys();
    final prefix = 'household_member_${_household!.id}_';
    _householdMembers = allKeys
        .where((k) => k.startsWith(prefix))
        .map((k) => prefs.getString(k))
        .whereType<String>()
        .map((json) => UserModel.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<HouseholdModel?> _findHouseholdByInviteCode(
      SharedPreferences prefs, String? inviteCode) async {
    if (inviteCode == null || inviteCode.isEmpty) return null;
    final keys = prefs.getKeys();
    for (final key in keys.where((k) => k.startsWith('household_'))) {
      final json = prefs.getString(key);
      if (json == null) continue;
      final household = HouseholdModel.fromJson(jsonDecode(json));
      if (household.ownerInviteCode.toUpperCase() == inviteCode) {
        return household;
      }
    }
    final current = prefs.getString('household');
    if (current != null) {
      final household = HouseholdModel.fromJson(jsonDecode(current));
      if (household.ownerInviteCode.toUpperCase() == inviteCode) {
        return household;
      }
    }
    return null;
  }
}
