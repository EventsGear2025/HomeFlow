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
    List<UserModel> get homeowners =>
      _householdMembers.where((u) => u.role == UserRole.owner).toList();
    List<UserModel> get additionalHomeowners => homeowners
      .where((u) => u.id != _household?.createdBy)
      .toList();
  bool get isLoading => _isLoading;

  /// Re-fetches household members from Supabase (and falls back to local cache).
  /// Call this when the owner opens a screen that lists members, so newly
  /// joined managers are visible without requiring an app restart.
  Future<void> refreshHouseholdMembers() async {
    if (_household == null) return;
    final prefs = await SharedPreferences.getInstance();
    await _loadHouseholdMembers(prefs);
    notifyListeners();
  }

  Future<bool> refreshCurrentHouseholdAccess() async {
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    final householdId =
        _household?.id ?? _currentUser?.householdId ?? '';
    if (supabaseUser == null || householdId.isEmpty) return false;

    final membership = await SyncService.fetchMembership(
      supabaseUser.id,
      householdId: householdId,
    );
    if (membership != null) {
      final membershipRole = _supabaseAuthService
          .inferRoleValue(membership['role']?.toString());
      final membershipName = membership['full_name']?.toString().trim();
      final membershipEmail = membership['display_email']?.toString().trim();
      final nextUser = (_currentUser ??
              UserModel(
                id: supabaseUser.id,
                fullName: membershipName?.isNotEmpty == true
                    ? membershipName!
                    : (supabaseUser.userMetadata?['full_name']?.toString() ??
                        supabaseUser.email?.split('@').first ??
                        'HomeFlow User'),
                email: membershipEmail?.isNotEmpty == true
                    ? membershipEmail!
                    : (supabaseUser.email ?? ''),
                role: membershipRole,
                householdId: householdId,
              ))
          .copyWith(
        fullName: membershipName?.isNotEmpty == true
            ? membershipName
            : _currentUser?.fullName,
        email: membershipEmail?.isNotEmpty == true
            ? membershipEmail
            : _currentUser?.email,
        role: membershipRole,
        householdId: householdId,
      );
      final changed = _currentUser == null ||
          _currentUser!.role != nextUser.role ||
          _currentUser!.householdId != nextUser.householdId ||
          _currentUser!.fullName != nextUser.fullName ||
          _currentUser!.email != nextUser.email;
      _currentUser = nextUser;
      if (changed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'current_user', jsonEncode(_currentUser!.toJson()));
        await _saveMember(_currentUser!, prefs);
      }
      return false;
    }

    final row = await SyncService.loadHousehold(householdId);
    final isPrimaryOwner =
        row?['owner_user_id']?.toString() == supabaseUser.id;
    if (isPrimaryOwner) {
      final fullName = _currentUser?.fullName.isNotEmpty == true
          ? _currentUser!.fullName
          : (supabaseUser.userMetadata?['full_name']?.toString().trim() ??
              supabaseUser.email?.split('@').first ??
              'Owner');
      final displayEmail = _currentUser?.email.isNotEmpty == true
          ? _currentUser!.email
          : (supabaseUser.email ?? '');
      try {
        await SyncService.ensureHouseholdMember(
          householdId,
          'owner',
          fullName: fullName,
          displayEmail: displayEmail,
        );
      } catch (_) {}

      _currentUser = (_currentUser ??
              UserModel(
                id: supabaseUser.id,
                fullName: fullName,
                email: displayEmail,
                role: UserRole.owner,
                householdId: householdId,
              ))
          .copyWith(role: UserRole.owner, householdId: householdId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await _saveMember(_currentUser!, prefs);
      return false;
    }

    await _handleHouseholdAccessRevoked(householdId);
    return true;
  }

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
      await _hydrateSupabaseSession(supabaseUser);
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
    }
    // New users (no stored session) are left unauthenticated so the splash
    // routes them to the Sign Up screen.

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
              managerInviteCode: inviteCode,
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
                    managerInviteCode: inviteCode,
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
        managerInviteCode: inviteCode,
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
        await _hydrateSupabaseSession(
          supabaseUser,
          fallbackEmail: loginEmail,
        );
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

  /// After a successful [login], call this to switch the active profile to the
  /// house-manager role if the signed-in Supabase user also has a
  /// house_manager row in app_household_members.
  /// Returns true when the switch succeeded, false when no manager entry was
  /// found (caller should show an error / revert to owner profile).
  Future<bool> switchToManagerProfile() async {
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (supabaseUser == null) return false;

    final membership =
        await SyncService.fetchManagerMembership(supabaseUser.id);
    if (membership == null) return false;

    final householdId = membership['household_id']?.toString() ?? '';
    final fullName =
        membership['full_name']?.toString().trim().isNotEmpty == true
            ? membership['full_name'].toString().trim()
            : _currentUser?.fullName ?? supabaseUser.email?.split('@').first ?? 'Home Manager';

    if (householdId.isEmpty) return false;

    final row = await SyncService.loadHousehold(householdId);
    _household = row != null
        ? HouseholdModel.fromSupabaseRow(row)
        : null;

    _currentUser = UserModel(
      id: supabaseUser.id,
      fullName: fullName,
      email: supabaseUser.email ?? '',
      role: UserRole.houseManager,
      householdId: householdId,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
    if (_household != null) {
      final hJson = jsonEncode(_household!.toJson());
      await prefs.setString('household', hJson);
      await prefs.setString('household_${_household!.id}', hJson);
    }
    await _loadHouseholdMembers(prefs);
    notifyListeners();
    return true;
  }

  /// Update the current user's display name and (if owner) household name.
  Future<void> updateProfile({
    required String fullName,
    String? householdName,
    String? deliveryAddress,
    String? deliveryContactName,
    String? deliveryPhone,
    String? deliverySmsNotes,
    String? supermarketDeliveryNotes,
  }) async {
    if (_currentUser == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final trimmedName = fullName.trim();
      final prefs = await SharedPreferences.getInstance();

      // Update Supabase user metadata (display name).
      await _supabaseAuthService.updateUserMetadata({'full_name': trimmedName});

      // Update household details in Supabase if owner/co-owner and values changed.
      if (isOwner && _household != null) {
        final trimmedHousehold = householdName?.trim();
        final normalizedAddress = deliveryAddress?.trim();
        final normalizedContactName = deliveryContactName?.trim();
        final normalizedPhone = deliveryPhone?.trim();
        final normalizedSmsNotes = deliverySmsNotes?.trim();
        final normalizedSupermarketNotes = supermarketDeliveryNotes?.trim();

        final hasHouseholdUpdate =
            (trimmedHousehold != null &&
                trimmedHousehold.isNotEmpty &&
                trimmedHousehold != _household!.householdName) ||
            normalizedAddress != null ||
            normalizedContactName != null ||
            normalizedPhone != null ||
            normalizedSmsNotes != null ||
            normalizedSupermarketNotes != null;

        if (hasHouseholdUpdate) {
          try {
            await SyncService.updateHouseholdDetails(
              householdId: _household!.id,
              householdName: trimmedHousehold != null &&
                      trimmedHousehold.isNotEmpty &&
                      trimmedHousehold != _household!.householdName
                  ? trimmedHousehold
                  : null,
              deliveryAddress: normalizedAddress,
              deliveryContactName: normalizedContactName,
              deliveryPhone: normalizedPhone,
              deliverySmsNotes: normalizedSmsNotes,
              supermarketDeliveryNotes: normalizedSupermarketNotes,
            );
            _household = _household!.copyWith(
              householdName: trimmedHousehold != null &&
                      trimmedHousehold.isNotEmpty
                  ? trimmedHousehold
                  : null,
              deliveryAddress: normalizedAddress?.isNotEmpty == true
                  ? normalizedAddress
                  : null,
              deliveryContactName:
                  normalizedContactName?.isNotEmpty == true
                      ? normalizedContactName
                      : null,
              deliveryPhone:
                  normalizedPhone?.isNotEmpty == true ? normalizedPhone : null,
              deliverySmsNotes: normalizedSmsNotes?.isNotEmpty == true
                  ? normalizedSmsNotes
                  : null,
              supermarketDeliveryNotes:
                  normalizedSupermarketNotes?.isNotEmpty == true
                      ? normalizedSupermarketNotes
                      : null,
              clearDeliveryAddress: normalizedAddress != null &&
                  normalizedAddress.isEmpty,
              clearDeliveryContactName:
                  normalizedContactName != null && normalizedContactName.isEmpty,
              clearDeliveryPhone:
                  normalizedPhone != null && normalizedPhone.isEmpty,
              clearDeliverySmsNotes:
                  normalizedSmsNotes != null && normalizedSmsNotes.isEmpty,
              clearSupermarketDeliveryNotes: normalizedSupermarketNotes != null &&
                  normalizedSupermarketNotes.isEmpty,
            );
            await prefs.setString('household', jsonEncode(_household!.toJson()));
            await prefs.setString(
                'household_${_household!.id}', jsonEncode(_household!.toJson()));
          } catch (e) {
            debugPrint('[AuthProvider] updateHouseholdDetails error: $e');
          }
        }
      }

      // Update local user model and persist.
      _currentUser = _currentUser!.copyWith(fullName: trimmedName);
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await _saveMember(_currentUser!, prefs);
    } catch (e) {
      debugPrint('[AuthProvider] updateProfile error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  /// Update editable profile fields for a house manager (owner-only).
  Future<void> updateManagerProfile({
    required String userId,
    String? idNumber,
    DateTime? startDate,
    int? leaveDaysTotal,
    int? leaveDaysTaken,
    String? managerNotes,
  }) async {
    if (_household == null) return;
    await SyncService.updateManagerProfile(
      householdId: _household!.id,
      userId: userId,
      idNumber: idNumber,
      startDate: startDate,
      leaveDaysTotal: leaveDaysTotal,
      leaveDaysTaken: leaveDaysTaken,
      managerNotes: managerNotes,
    );
    final prefs = await SharedPreferences.getInstance();
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
  String get managerInviteCode => _household?.managerInviteCode ?? '';
  String get homeownerInviteCode => _household?.homeownerInviteCode ?? '';

  /// Send a password-reset email via Supabase. Shows no error to the caller
  /// if the email doesn't exist (security best practice).
  Future<void> sendPasswordReset(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('Enter a valid email address.');
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(normalizedEmail);
    } catch (e) {
      debugPrint('[AuthProvider] sendPasswordReset error: $e');
      throw Exception(_friendlyAuthError(e));
    }
  }

  // ── Owner signup: step 1 – register only, no household yet ───────────────
  Future<bool> signUpOwner({
    required String fullName,
    required String email,
    required String password,
    required String householdName,
    required String deliveryAddress,
    String? deliveryPhone,
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
          'pending_delivery_address': deliveryAddress,
          if (deliveryPhone?.trim().isNotEmpty == true)
            'pending_delivery_phone': deliveryPhone!.trim(),
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.session != null) {
        debugPrint('[signUpOwner] Immediate session - no email confirmation needed');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Supabase returns empty identities when the email is already registered
      // but unconfirmed. In that case, resend the OTP so the user can proceed.
      final identities = resp.user?.identities;
      if (identities != null && identities.isEmpty) {
        debugPrint('[signUpOwner] User already exists, resending OTP');
        try {
          await _supabaseAuthService
              .resendOtp(email: normalizedEmail)
              .timeout(const Duration(seconds: 10));
        } catch (error) {
          if (!SupabaseAuthService.isRateLimitError(error)) {
            rethrow;
          }
          debugPrint(
            '[signUpOwner] Resend rate-limited, continuing to OTP screen',
          );
        }
      }
    } catch (e) {
      debugPrint('[signUpOwner] error: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> signUpAdditionalHomeownerPreStep({
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
      debugPrint('[signUpAdditionalHomeownerPreStep] Signing up $normalizedEmail');
      final resp = await _supabaseAuthService.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'owner',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.session != null) {
        debugPrint('[signUpAdditionalHomeownerPreStep] Immediate session');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final identities = resp.user?.identities;
      if (identities != null && identities.isEmpty) {
        debugPrint('[signUpAdditionalHomeownerPreStep] User already exists, resending OTP');
        try {
          await _supabaseAuthService
              .resendOtp(email: normalizedEmail)
              .timeout(const Duration(seconds: 10));
        } catch (error) {
          if (!SupabaseAuthService.isRateLimitError(error)) {
            rethrow;
          }
          debugPrint(
            '[signUpAdditionalHomeownerPreStep] Resend rate-limited, continuing to OTP screen',
          );
        }
      }
    } catch (e) {
      debugPrint('[signUpAdditionalHomeownerPreStep] error: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
    return true;
  }

  // ── Owner signup: step 2 – called after OTP verified ─────────────────────
  Future<void> completeOwnerSetup({
    required String fullName,
    required String email,
    required String householdName,
    required String deliveryAddress,
    String? deliveryPhone,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final supabaseUser = _supabaseAuthService.currentSupabaseUser;
      if (supabaseUser == null) throw Exception('Session not found. Please sign in again.');

      final managerCode = _generateInviteCode();
      var homeownerCode = _generateInviteCode();
      while (homeownerCode == managerCode) {
        homeownerCode = _generateInviteCode();
      }
      final createdId = await SyncService.createHousehold(
        name: householdName,
        inviteCode: managerCode,
        homeownerInviteCode: homeownerCode,
        deliveryAddress: deliveryAddress.trim(),
        deliveryContactName: fullName,
        deliveryPhone: deliveryPhone?.trim(),
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
        managerInviteCode: managerCode,
        homeownerInviteCode: homeownerCode,
        deliveryAddress: deliveryAddress.trim(),
        deliveryContactName: fullName,
        deliveryPhone: deliveryPhone?.trim().isNotEmpty == true
            ? deliveryPhone!.trim()
            : null,
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

  Future<void> completeAdditionalOwnerSetup({
    required String fullName,
    required String email,
    required String inviteCode,
  }) async {
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (supabaseUser == null) {
      throw Exception('Session not found. Please sign in again.');
    }

    final code = inviteCode.trim().toUpperCase();
    if (code.length != 8) {
      throw Exception('Invite codes are 8 characters — check with the homeowner.');
    }

    _isLoading = true;
    notifyListeners();
    try {
      final joinedId = await SyncService.joinHouseholdByInviteCode(
        code,
        userId: supabaseUser.id,
        role: 'owner',
      );
      if (joinedId == null) {
        throw Exception('Could not join household. Please check your connection and try again.');
      }

      await _supabaseAuthService.updateUserMetadata({
        'household_id': joinedId,
        'role': 'owner',
        'full_name': fullName,
      });
      await SyncService.ensureHouseholdMember(
        joinedId,
        'owner',
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
              managerInviteCode: '',
              homeownerInviteCode: code,
              createdAt: DateTime.now(),
            );
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: email.trim().toLowerCase(),
        role: UserRole.owner,
        householdId: joinedId,
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

  // ── Manager signup: step 1 – create account, then verify by OTP if needed.
  // Returns false when Supabase gives us a session immediately.
  // Returns true when email verification is still required.
  Future<bool> signUpManagerPreStep({
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
      debugPrint('[signUpManagerPreStep] Signing up $normalizedEmail');
      final resp = await _supabaseAuthService.signUp(
        email: normalizedEmail,
        password: password,
        data: {
          'full_name': fullName,
          'role': 'house_manager',
        },
      ).timeout(const Duration(seconds: 10));

      // If Supabase gave us a session immediately (email confirmation off),
      // we're done — no further steps needed.
      if (resp.session != null) {
        debugPrint('[signUpManagerPreStep] Immediate session — no email confirmation needed');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Supabase returns empty identities when the email already exists but
      // is still unconfirmed. In that case, force a fresh OTP just like the
      // owner flow does, instead of relying on any earlier email.
      final identities = resp.user?.identities;
      if (identities != null && identities.isEmpty) {
        debugPrint('[signUpManagerPreStep] User already exists, resending OTP');
        try {
          await _supabaseAuthService
              .resendOtp(email: normalizedEmail)
              .timeout(const Duration(seconds: 10));
        } catch (error) {
          if (!SupabaseAuthService.isRateLimitError(error)) {
            rethrow;
          }
          debugPrint(
            '[signUpManagerPreStep] Resend rate-limited, continuing to OTP screen',
          );
        }
      }

      // Do not join the household until OTP verification succeeds.
      // This keeps the manager flow aligned with the working owner flow and
      // avoids any extra side effects before the email token is verified.
    } catch (e) {
      debugPrint('[signUpManagerPreStep] error: $e');
      _isLoading = false;
      notifyListeners();
      throw Exception(_friendlyAuthError(e));
    }
    _isLoading = false;
    notifyListeners();
    // OTP email sent — caller navigates to ManagerOtpScreen.
    return true;
  }

  // ── Manager signup: step 2 – called after OTP verified ──────────────────
  Future<void> completeManagerSetup({
    required String fullName,
    required String email,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final supabaseUser = _supabaseAuthService.currentSupabaseUser;
      if (supabaseUser == null) throw Exception('Session not found. Please sign in again.');
      await _supabaseAuthService.updateUserMetadata({
        'role': 'house_manager',
        'full_name': fullName,
      });
      _household = null;
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: email.trim().toLowerCase(),
        role: UserRole.houseManager,
        householdId: '',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(_currentUser!.toJson()));
      await prefs.remove('household');
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

  Future<void> joinHouseholdAsManager({required String inviteCode}) async {
    final supabaseUser = _supabaseAuthService.currentSupabaseUser;
    if (supabaseUser == null) {
      throw Exception('Session not found. Please sign in again.');
    }

    final code = inviteCode.trim().toUpperCase();
    if (code.length != 8) {
      throw Exception('Invite codes are 8 characters — check with the homeowner.');
    }

    _isLoading = true;
    notifyListeners();
    try {
      final joinedId = await SyncService.joinHouseholdByInviteCode(
        code,
        userId: supabaseUser.id,
        role: 'house_manager',
      );
      if (joinedId == null) {
        throw Exception('Could not join household. Please check your connection and try again.');
      }

      final fullName = _currentUser?.fullName ??
          supabaseUser.userMetadata?['full_name']?.toString().trim() ??
          supabaseUser.email?.split('@').first ??
          'House Manager';
      final displayEmail = _currentUser?.email.isNotEmpty == true
          ? _currentUser!.email
          : (supabaseUser.email ?? '');

      await _supabaseAuthService.updateUserMetadata({
        'household_id': joinedId,
        'role': 'house_manager',
        'full_name': fullName,
      });
      await SyncService.ensureHouseholdMember(
        joinedId,
        'house_manager',
        fullName: fullName,
        displayEmail: displayEmail,
      );

      final row = await SyncService.loadHousehold(joinedId);
      _household = row != null
          ? HouseholdModel.fromSupabaseRow(row)
          : HouseholdModel(
              id: joinedId,
              householdName: 'Household',
              createdBy: '',
              managerInviteCode: code,
              createdAt: DateTime.now(),
            );
      _currentUser = UserModel(
        id: supabaseUser.id,
        fullName: fullName,
        email: displayEmail,
        role: UserRole.houseManager,
        householdId: joinedId,
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
        role: 'house_manager',
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
      // Store name + phone in the members table so the owner can see them in
      // the Staff section. The RPC creates the row without display fields, so
      // we upsert here with the full details.
      await SyncService.ensureHouseholdMember(
        joinedId,
        'house_manager',
        fullName: fullName,
        displayEmail: normalizedPhone,
      );

      final row = await SyncService.loadHousehold(joinedId);
      _household = row != null
          ? HouseholdModel.fromSupabaseRow(row)
          : HouseholdModel(
              id: joinedId,
              householdName: 'Household',
              createdBy: '',
              managerInviteCode: code,
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
    await _hydrateSupabaseSession(supabaseUser);

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
    if (SupabaseAuthService.isRateLimitError(e)) {
      return SupabaseAuthService.resendRateLimitMessage;
    }
    // Fallback — strip the "Exception:" prefix Flutter adds
    return msg.replaceFirst('Exception: ', '');
  }

  Future<void> _ensureBuildDemoAccounts(SharedPreferences prefs) async {
    final household = HouseholdModel(
      id: kBuildHouseholdId,
      householdName: 'HomeFlow Demo Home',
      createdBy: kBuildOwnerId,
      managerInviteCode: kBuildManagerInviteCode,
      homeownerInviteCode: 'HFHOME01',
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

  Future<void> _hydrateSupabaseSession(
    User supabaseUser, {
    String? fallbackEmail,
  }) async {
    var householdId =
        supabaseUser.userMetadata?['household_id']?.toString() ?? '';
    var role = _supabaseAuthService.inferRoleFromMetadata(supabaseUser);
    var fullName =
        (supabaseUser.userMetadata?['full_name']?.toString().trim().isNotEmpty ??
                false)
            ? supabaseUser.userMetadata!['full_name'].toString().trim()
            : (supabaseUser.email?.split('@').first ?? 'HomeFlow User');
    var displayEmail = supabaseUser.email ?? fallbackEmail ?? '';

    if (householdId.isEmpty) {
      final membership = await SyncService.fetchMembership(supabaseUser.id);
      if (membership != null) {
        final recoveredHouseholdId =
            membership['household_id']?.toString() ?? '';
        if (recoveredHouseholdId.isNotEmpty) {
          householdId = recoveredHouseholdId;
          role = _supabaseAuthService
              .inferRoleValue(membership['role']?.toString());
          final recoveredName = membership['full_name']?.toString().trim();
          final recoveredEmail =
              membership['display_email']?.toString().trim();
          if (recoveredName?.isNotEmpty == true) {
            fullName = recoveredName!;
          }
          if (recoveredEmail?.isNotEmpty == true) {
            displayEmail = recoveredEmail!;
          }
          try {
            await _supabaseAuthService.updateUserMetadata({
              'household_id': householdId,
              'role': _roleValue(role),
              'full_name': fullName,
            });
          } catch (_) {}
        }
      }
    }

    _currentUser = UserModel(
      id: supabaseUser.id,
      fullName: fullName,
      email: displayEmail,
      role: role,
      householdId: householdId,
    );
    _household = null;

    if (householdId.isNotEmpty) {
      final row = await SyncService.loadHousehold(householdId);
      _household = row != null ? HouseholdModel.fromSupabaseRow(row) : null;
      try {
        await SyncService.ensureHouseholdMember(
          householdId,
          _roleValue(role),
          fullName: fullName,
          displayEmail: displayEmail,
        );
      } catch (_) {}
      await _ensureHomeownerInviteCode();
    }
  }

  Future<void> _ensureHomeownerInviteCode() async {
    if (!isOwner || _household == null) return;
    if (_household!.homeownerInviteCode.trim().isNotEmpty) return;

    var code = _generateInviteCode();
    while (code == _household!.managerInviteCode) {
      code = _generateInviteCode();
    }

    if (SyncService.isAvailable) {
      try {
        await SyncService.updateHouseholdDetails(
          householdId: _household!.id,
          homeownerInviteCode: code,
        );
      } catch (e) {
        debugPrint('[AuthProvider] homeowner invite backfill failed: $e');
      }
    }

    _household = _household!.copyWith(homeownerInviteCode: code);
    final prefs = await SharedPreferences.getInstance();
    final householdJson = jsonEncode(_household!.toJson());
    await prefs.setString('household', householdJson);
    await prefs.setString('household_${_household!.id}', householdJson);
  }

  String _roleValue(UserRole role) =>
      role == UserRole.owner ? 'owner' : 'house_manager';

  Future<void> _handleHouseholdAccessRevoked(String householdId) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeHouseholdCache(prefs, householdId);
    try {
      await _supabaseAuthService.updateUserMetadata({'household_id': null});
    } catch (_) {}
    await _supabaseAuthService.signOut();
    _currentUser = null;
    _household = null;
    _householdMembers = [];
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _purgeHouseholdCache(
    SharedPreferences prefs,
    String householdId,
  ) async {
    final keysToRemove = prefs.getKeys().where((key) {
      if (key == 'household') return true;
      if (key == 'household_$householdId') return true;
      if (key.startsWith('household_member_${householdId}_')) return true;
      return key.endsWith('_$householdId');
    }).toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
    await prefs.remove('current_user');
  }

  Future<void> _loadHouseholdMembers(SharedPreferences prefs) async {
    if (_household == null) {
      _householdMembers = [];
      return;
    }

    final allKeys = prefs.getKeys();
    final prefix = 'household_member_${_household!.id}_';
    final cachedMembers = allKeys
        .where((k) => k.startsWith(prefix))
        .map((k) => prefs.getString(k))
        .whereType<String>()
        .map((json) => UserModel.fromJson(jsonDecode(json)))
        .toList();

    Map<String, UserModel> mergeMembers(Iterable<UserModel> members) {
      final byId = <String, UserModel>{};
      for (final member in members) {
        byId[member.id] = member;
      }
      return byId;
    }

    // Try Supabase first — this is the source of truth and ensures the owner
    // sees managers who joined on other devices (and vice versa).
    final rows = await SyncService.fetchHouseholdMembers(_household!.id);
    if (rows != null && rows.isNotEmpty) {
      final remoteMembers = rows.map((row) {
        final roleStr = row['role'] as String? ?? 'owner';
        DateTime? startDate;
        final sdRaw = row['start_date'];
        if (sdRaw != null) {
          try { startDate = DateTime.parse(sdRaw.toString()); } catch (_) {}
        }
        return UserModel(
          id: (row['user_id'] as Object).toString(),
          fullName: row['full_name'] as String? ?? '',
          email: row['display_email'] as String? ?? '',
          role: roleStr == 'owner' ? UserRole.owner : UserRole.houseManager,
          householdId: (row['household_id'] as Object).toString(),
          idNumber: row['id_number'] as String?,
          startDate: startDate,
          leaveDaysTotal: row['leave_days_total'] as int? ?? 21,
          leaveDaysTaken: row['leave_days_taken'] as int? ?? 0,
          managerNotes: row['manager_notes'] as String?,
        );
      }).toList();

      final merged = mergeMembers(cachedMembers);
      for (final member in remoteMembers) {
        merged[member.id] = member;
      }

      _householdMembers = merged.values.toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));

      // Persist to local cache for offline use.
      for (final m in _householdMembers) {
        await _saveMember(m, prefs);
      }
      return;
    }

    // Fall back to local SharedPreferences when Supabase is unavailable.
    _householdMembers = cachedMembers
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<HouseholdModel?> _findHouseholdByInviteCode(
      SharedPreferences prefs, String? inviteCode) async {
    if (inviteCode == null || inviteCode.isEmpty) return null;
    final normalizedCode = inviteCode.trim().toUpperCase();
    final keys = prefs.getKeys();
    for (final key in keys.where((k) => k.startsWith('household_'))) {
      final json = prefs.getString(key);
      if (json == null) continue;
      final household = HouseholdModel.fromJson(jsonDecode(json));
      if (household.ownerInviteCode.toUpperCase() == normalizedCode ||
          household.homeownerInviteCode.toUpperCase() == normalizedCode) {
        return household;
      }
    }
    final current = prefs.getString('household');
    if (current != null) {
      final household = HouseholdModel.fromJson(jsonDecode(current));
      if (household.ownerInviteCode.toUpperCase() == normalizedCode ||
          household.homeownerInviteCode.toUpperCase() == normalizedCode) {
        return household;
      }
    }
    return null;
  }
}
