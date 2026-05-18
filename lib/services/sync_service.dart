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
    String? homeownerInviteCode,
    String? deliveryAddress,
    String? deliveryContactName,
    String? deliveryPhone,
    String? deliverySmsNotes,
    String? supermarketDeliveryNotes,
  }) async {
    if (!isAvailable) return null;
    try {
      final resp = await _db
          .from('app_households')
          .insert({
            'household_name': name,
            'invite_code': inviteCode,
            'homeowner_invite_code': homeownerInviteCode,
            'owner_user_id': _db.auth.currentUser!.id,
            'plan_code': 'free',
            'plan_status': 'active',
            'delivery_address': deliveryAddress,
            'delivery_contact_name': deliveryContactName,
            'delivery_phone': deliveryPhone,
            'delivery_sms_notes': deliverySmsNotes,
            'supermarket_delivery_notes': supermarketDeliveryNotes,
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
    String role = 'house_manager',
  }) async {
    // When userId is supplied we can call the RPC even without an active session
    // (the SECURITY DEFINER function receives the id directly). Only gate on
    // isAvailable when we have no explicit userId to pass.
    if (userId == null && !isAvailable) return null;
    try {
      final params = <String, dynamic>{
        'invite': inviteCode,
        'p_role': role,
      };
      if (userId != null) params['p_user_id'] = userId;
      debugPrint(
        '[SyncService] joinHouseholdByInviteCode invite=$inviteCode userId=$userId role=$role',
      );
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

  /// Fetch a specific membership row for [userId]. When [householdId] is
  /// provided, limits the lookup to that household.
  static Future<Map<String, dynamic>?> fetchMembership(
    String userId, {
    String? householdId,
  }) async {
    if (!isAvailable) return null;
    try {
      dynamic query = _db
          .from('app_household_members')
          .select('*')
          .eq('user_id', userId);
      if (householdId != null && householdId.isNotEmpty) {
        query = query.eq('household_id', householdId);
      }
      final rows = await query.limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      debugPrint('[SyncService] fetchMembership error: $e');
      return null;
    }
  }

  /// Remove a specific user from a household's member list in Supabase.
  /// Called by the owner when removing a manager, or by the manager on leave.
  static Future<void> removeHouseholdMember({
    required String householdId,
    required String userId,
  }) async {
    if (!isAvailable) {
      throw Exception('Supabase sync is not available right now.');
    }
    try {
      await _db
          .from('app_household_members')
          .delete()
          .eq('household_id', householdId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[SyncService] removeHouseholdMember error: $e');
      throw Exception('Could not update household access. Please try again.');
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
      // Use select('*') so the query succeeds even if optional columns
      // (full_name, display_email) have not been added to the table yet.
      final rows = await _db
          .from('app_household_members')
          .select('*')
          .eq('household_id', householdId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('[SyncService] fetchHouseholdMembers error: $e');
      return null;
    }
  }

  /// Look up whether [userId] has a house_manager membership in any household.
  /// Returns the first matching {household_id, full_name} map, or null.
  static Future<Map<String, dynamic>?> fetchManagerMembership(
    String userId,
  ) async {
    if (!isAvailable) return null;
    try {
      final rows = await _db
          .from('app_household_members')
          .select('household_id, full_name')
          .eq('user_id', userId)
          .eq('role', 'house_manager')
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      return list.isNotEmpty ? list.first : null;
    } catch (e) {
      debugPrint('[SyncService] fetchManagerMembership error: $e');
      return null;
    }
  }

  /// Update editable household fields. Owners and co-owners are expected to
  /// call this through app-side role checks plus RLS.
  static Future<void> updateHouseholdDetails({
    required String householdId,
    String? householdName,
    String? managerInviteCode,
    String? homeownerInviteCode,
    String? deliveryAddress,
    String? deliveryContactName,
    String? deliveryPhone,
    String? deliverySmsNotes,
    String? supermarketDeliveryNotes,
  }) async {
    if (!isAvailable) return;
    final updates = <String, dynamic>{
      if (householdName != null) 'household_name': householdName,
      if (managerInviteCode != null) 'invite_code': managerInviteCode,
      if (homeownerInviteCode != null)
        'homeowner_invite_code': homeownerInviteCode,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryContactName != null)
        'delivery_contact_name': deliveryContactName,
      if (deliveryPhone != null) 'delivery_phone': deliveryPhone,
      if (deliverySmsNotes != null) 'delivery_sms_notes': deliverySmsNotes,
      if (supermarketDeliveryNotes != null)
        'supermarket_delivery_notes': supermarketDeliveryNotes,
    };
    if (updates.isEmpty) return;
    try {
      await _db.from('app_households').update(updates).eq('id', householdId);
    } catch (e) {
      debugPrint('[SyncService] updateHouseholdDetails error: $e');
    }
  }

  /// Update manager profile fields (ID number, start date, leave, notes).
  /// Only the household owner should call this.
  static Future<void> updateManagerProfile({
    required String householdId,
    required String userId,
    String? idNumber,
    DateTime? startDate,
    int? leaveDaysTotal,
    int? leaveDaysTaken,
    String? managerNotes,
  }) async {
    if (!isAvailable) return;
    try {
      await _db.from('app_household_members').update({
        if (idNumber != null) 'id_number': idNumber,
        if (startDate != null) 'start_date': startDate.toIso8601String().substring(0, 10),
        if (leaveDaysTotal != null) 'leave_days_total': leaveDaysTotal,
        if (leaveDaysTaken != null) 'leave_days_taken': leaveDaysTaken,
        if (managerNotes != null) 'manager_notes': managerNotes,
      })
          .eq('household_id', householdId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('[SyncService] updateManagerProfile error: $e');
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
