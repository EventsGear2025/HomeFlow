import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Thin helper that wraps Supabase CRUD for all feature providers.
///
/// All write methods (upsertAll / upsertOne / deleteOne) are **fire-and-forget** —
/// errors are swallowed so they never block the UI.
///
/// All read methods return `null` on failure so callers fall back to the local
/// SharedPreferences cache transparently.
///
/// Sync strategy
/// ─────────────
/// • loadData in every provider: Supabase → cache (SharedPreferences).
///   Falls back to cache on network error.
/// • Every write: SharedPreferences immediately + Supabase async push.
/// • In-flight offline writes are missed on the Supabase side but will be
///   overwritten when the next online write pushes the full list again.
class SyncService {
  static SupabaseClient get _db => SupabaseService.client;

  /// True when the Supabase client has an authenticated user.
  static bool get isAvailable {
    try {
      return _db.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  // ─── Household management ──────────────────────────────────────────────────

  /// Create a new household in Supabase.
  /// Returns the UUID household id (as String) on success, null on failure.
  static Future<String?> createHousehold({
    required String name,
    required String inviteCode,
  }) async {
    if (!isAvailable) return null;
    try {
      final resp = await _db
          .from('app_households')
          .insert({
            'household_name': name,
            'invite_code': inviteCode,
            'owner_user_id': _db.auth.currentUser!.id,
            'plan_code': 'free',
            'plan_status': 'active',
          })
          .select('id')
          .single();
      return (resp['id'] as Object?)?.toString();
    } catch (e) {
      debugPrint('[SyncService] createHousehold error: $e');
      return null;
    }
  }

  /// Load household data by id. Returns the row as a raw map, or null.
  static Future<Map<String, dynamic>?> loadHousehold(String householdId) async {
    if (!isAvailable) return null;
    try {
      final resp = await _db
          .from('app_households')
          .select()
          .eq('id', householdId)
          .single();
      return Map<String, dynamic>.from(resp as Map);
    } catch (e) {
      debugPrint('[SyncService] loadHousehold error: $e');
      return null;
    }
  }

  /// Join a household via invite code (calls the `join_household_by_invite` RPC).
  /// [userId] should be passed explicitly right after signUp when no session
  /// is established yet (Supabase email-confirm flow). Falls back to auth.uid()
  /// when called from an already-authenticated session.
  /// Returns the household_id on success, null on failure.
  static Future<String?> joinHouseholdByInviteCode(
    String inviteCode, {
    String? userId,
  }) async {
    // When userId is supplied we can call the RPC even without an active session
    // (the SECURITY DEFINER function receives the id directly). Only gate on
    // isAvailable when we have no explicit userId to pass.
    if (userId == null && !isAvailable) return null;
    try {
      final params = <String, dynamic>{'invite': inviteCode};
      if (userId != null) params['p_user_id'] = userId;
      debugPrint('[SyncService] joinHouseholdByInviteCode invite=$inviteCode userId=$userId');
      final result = await _db.rpc(
        'join_household_by_invite',
        params: params,
      );
      debugPrint('[SyncService] joinHouseholdByInviteCode result=$result');
      return result as String?;
    } catch (e) {
      debugPrint('[SyncService] joinHouseholdByInviteCode error: $e');
      // Propagate "invalid invite code" so callers can show the right message;
      // swallow all other errors (network, auth) and let callers handle null.
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid invite code')) {
        rethrow;
      }
      return null;
    }
  }

  /// Remove a specific user from a household's member list in Supabase.
  /// Called by the owner when removing a manager, or by the manager on leave.
  static Future<void> removeHouseholdMember({
    required String householdId,
    required String userId,
  }) async {
    if (!isAvailable) return;
    try {
      await _db
          .from('app_household_members')
          .delete()
          .eq('household_id', householdId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[SyncService] removeHouseholdMember error: $e');
    }
  }

  /// Ensure the current auth user has a row in app_household_members.
  /// Also stores [fullName] and [displayEmail] so other household members
  /// can display them without needing access to auth.users metadata.
  static Future<void> ensureHouseholdMember(
    String householdId,
    String role, {
    String? fullName,
    String? displayEmail,
  }) async {
    if (!isAvailable) return;
    try {
      await _db.from('app_household_members').upsert({
        'household_id': householdId,
        'user_id': _db.auth.currentUser!.id,
        'role': role,
        if (fullName != null) 'full_name': fullName,
        if (displayEmail != null) 'display_email': displayEmail,
      }, onConflict: 'household_id,user_id');
    } catch (e) {
      debugPrint('[SyncService] ensureHouseholdMember error: $e');
    }
  }

  /// Fetch all members of a household from Supabase.
  /// Returns null on any error so callers can fall back to local cache.
  static Future<List<Map<String, dynamic>>?> fetchHouseholdMembers(
    String householdId,
  ) async {
    if (!isAvailable) return null;
    try {
      final rows = await _db
          .from('app_household_members')
          .select('user_id, role, full_name, display_email, household_id')
          .eq('household_id', householdId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('[SyncService] fetchHouseholdMembers error: $e');
      return null;
    }
  }

  /// Submit an upgrade intent for the current household.
  /// Returns true when the request row is created successfully.
  static Future<bool> submitUpgradeRequest({
    required String householdId,
    required String requestedPlanCode,
    String? source,
    String? notes,
  }) async {
    if (!isAvailable) return false;
    try {
      await _db.from('app_upgrade_requests').insert({
        'household_id': householdId,
        'requested_by_user_id': _db.auth.currentUser!.id,
        'requested_plan_code': requestedPlanCode,
        'source': source,
        'notes': notes,
      });
      return true;
    } catch (e) {
      debugPrint('[SyncService] submitUpgradeRequest error: $e');
      return false;
    }
  }

  // ─── Feature data CRUD ────────────────────────────────────────────────────

  /// Fetch all records for [householdId] from [table].
  /// Each row has a `data` JSONB column holding the full model JSON.
  /// Returns null on any error so callers fall back to SharedPreferences.
  static Future<List<T>?> fetchAll<T>(
    String table,
    String householdId,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (!isAvailable) return null;
    try {
      final rows = await _db
          .from(table)
          .select('data')
          .eq('household_id', householdId);
      return (rows as List)
          .map((r) => fromJson(Map<String, dynamic>.from(r['data'] as Map)))
          .toList();
    } catch (e) {
      debugPrint('[SyncService] fetchAll($table) error: $e');
      return null;
    }
  }

  /// Upsert [records] into [table]. Fire-and-forget.
  static void upsertAll(
    String table,
    String householdId,
    List<Map<String, dynamic>> records,
  ) {
    if (!isAvailable || records.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final rows = records
        .map(
          (r) => {
            'id': r['id'] as String,
            'household_id': householdId,
            'data': r,
            'updated_at': now,
          },
        )
        .toList();
    _db.from(table).upsert(rows, onConflict: 'id').then((_) {}).catchError((e) {
      debugPrint('[SyncService] upsertAll($table) error: $e');
    });
  }

  /// Upsert a single record. Fire-and-forget.
  static void upsertOne(
    String table,
    String householdId,
    Map<String, dynamic> record,
  ) => upsertAll(table, householdId, [record]);

  /// Delete the record with [id] from [table]. Fire-and-forget.
  static void deleteOne(String table, String id) {
    if (!isAvailable) return;
    _db.from(table).delete().eq('id', id).then((_) {}).catchError((e) {
      debugPrint('[SyncService] deleteOne($table, $id) error: $e');
    });
  }
}
