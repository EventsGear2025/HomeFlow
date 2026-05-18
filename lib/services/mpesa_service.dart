import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'mpesa_config.dart';

/// Result of an STK push attempt.
class MpesaStkResult {
  const MpesaStkResult._({
    required this.success,
    this.checkoutRequestId,
    this.errorMessage,
  });

  factory MpesaStkResult.ok(String checkoutRequestId) => MpesaStkResult._(
        success: true,
        checkoutRequestId: checkoutRequestId,
      );

  factory MpesaStkResult.err(String message) => MpesaStkResult._(
        success: false,
        errorMessage: message,
      );

  final bool success;
  final String? checkoutRequestId;
  final String? errorMessage;
}

class MpesaService {
  // ─── OAuth token ───────────────────────────────────────────────────────────

  static Future<String?> _getAccessToken() async {
    try {
      final credentials = base64Encode(
        utf8.encode('${MpesaConfig.consumerKey}:${MpesaConfig.consumerSecret}'),
      );
      final response = await http.get(
        Uri.parse(MpesaConfig.tokenUrl),
        headers: {'Authorization': 'Basic $credentials'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['access_token'] as String?;
      }
      debugPrint('[MpesaService] token error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('[MpesaService] token exception: $e');
      return null;
    }
  }

  // ─── STK push ─────────────────────────────────────────────────────────────

  /// Triggers an M-Pesa STK push to [phone] for [amount] KES.
  ///
  /// [phone] must be in the format 254XXXXXXXXX (no +, no leading 0).
  /// Returns [MpesaStkResult.ok] on success or [MpesaStkResult.err] on failure.
  static Future<MpesaStkResult> stkPush({
    required String phone,
    required double amount,
  }) async {
    // 1. Normalise phone
    final normalised = _normalizePhone(phone);
    if (normalised == null) {
      return MpesaStkResult.err(
          'Invalid phone number. Use format 07XXXXXXXX or 254XXXXXXXXX.');
    }

    // 2. Get token
    final token = await _getAccessToken();
    if (token == null) {
      return MpesaStkResult.err(
          'Could not connect to M-Pesa. Check your internet and try again.');
    }

    // 3. Build password + timestamp
    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final password = base64Encode(
      utf8.encode(
          '${MpesaConfig.businessShortCode}${MpesaConfig.passkey}$timestamp'),
    );

    // 4. Send STK push
    try {
      final response = await http.post(
        Uri.parse(MpesaConfig.stkPushUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'BusinessShortCode': MpesaConfig.businessShortCode,
          'Password': password,
          'Timestamp': timestamp,
          'TransactionType': 'CustomerPayBillOnline',
          'Amount': amount.round().toString(),
          'PartyA': normalised,
          'PartyB': MpesaConfig.businessShortCode,
          'PhoneNumber': normalised,
          'CallBackURL': MpesaConfig.callbackUrl,
          'AccountReference': MpesaConfig.accountReference,
          'TransactionDesc': MpesaConfig.transactionDesc,
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('[MpesaService] STK response: $body');

      if (response.statusCode == 200 &&
          body['ResponseCode']?.toString() == '0') {
        return MpesaStkResult.ok(
            body['CheckoutRequestID']?.toString() ?? '');
      }

      final errMsg = body['errorMessage'] ??
          body['ResponseDescription'] ??
          'Payment request failed';
      return MpesaStkResult.err(errMsg.toString());
    } catch (e) {
      debugPrint('[MpesaService] stkPush exception: $e');
      return MpesaStkResult.err('Network error. Please try again.');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String? _normalizePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0') && p.length == 10) p = '254${p.substring(1)}';
    if (RegExp(r'^254[17]\d{8}$').hasMatch(p)) return p;
    return null;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
