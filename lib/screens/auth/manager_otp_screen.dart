import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/app_colors.dart';
import '../main_shell.dart';

class ManagerOtpScreen extends StatefulWidget {
  final String email;
  final String fullName;

  const ManagerOtpScreen({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  State<ManagerOtpScreen> createState() => _ManagerOtpScreenState();
}

class _ManagerOtpScreenState extends State<ManagerOtpScreen> {
  static const int _otpLength = 8;

  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _resendCooldown = 0;
  bool _codeExpired = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _resendCooldown = SupabaseAuthService.signupResendCooldownSeconds;
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final otp = _otpCtrl.text.trim();
    if (otp.length < _otpLength) {
      _showError('Enter the $_otpLength-digit verification code from your email.');
      return;
    }
    setState(() => _verifying = true);
    final normalizedEmail = widget.email.trim().toLowerCase();
    bool otpVerified = false;
    try {
      debugPrint('[ManagerOTP] Verifying token "$otp" for $normalizedEmail');

      await Supabase.instance.client.auth.verifyOTP(
        email: normalizedEmail,
        token: otp,
        type: OtpType.signup,
      );
      otpVerified = true;
      debugPrint('[ManagerOTP] Verified successfully');

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      debugPrint('[ManagerOTP] Starting completeManagerSetup...');
      await auth.completeManagerSetup(
        fullName: widget.fullName,
        email: normalizedEmail,
      );
      debugPrint('[ManagerOTP] completeManagerSetup done');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on AuthException catch (e) {
      debugPrint('[ManagerOTP] AuthException: ${e.statusCode} ${e.message}');
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (!otpVerified && (msg.contains('expired') || msg.contains('invalid'))) {
        _otpCtrl.clear();
        setState(() => _codeExpired = true);
        _showError('That code has expired — tap “Send a new code” below.');
      } else {
        _showError(e.message);
      }
    } catch (e) {
      debugPrint('[ManagerOTP] Error: $e');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('ClientException') ||
          msg.contains('TimeoutException') || msg.contains('Network')) {
        _showError('No internet connection. Please check your network and try again.');
      } else {
        _showError(msg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final normalizedEmail = widget.email.trim().toLowerCase();
      await SupabaseAuthService().resendOtp(email: normalizedEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
      setState(() {
        _codeExpired = false;
        _resendCooldown = SupabaseAuthService.signupResendCooldownSeconds;
      });
      _startCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (SupabaseAuthService.isRateLimitError(e)) {
        setState(
          () => _resendCooldown =
              SupabaseAuthService.signupResendCooldownSeconds,
        );
        _startCooldown();
        _showError(SupabaseAuthService.resendRateLimitMessage);
      } else {
        _showError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      if (SupabaseAuthService.isRateLimitError(e)) {
        setState(
          () => _resendCooldown =
              SupabaseAuthService.signupResendCooldownSeconds,
        );
        _startCooldown();
        _showError(SupabaseAuthService.resendRateLimitMessage);
      } else {
        _showError('Could not resend the code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }

      setState(() => _resendCooldown--);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = _maskEmail(widget.email);
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Verify Email',
            style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Check your inbox',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary, height: 1.5),
                children: [
                  const TextSpan(text: 'We sent a verification code to '),
                  TextSpan(
                    text: maskedEmail,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const TextSpan(
                      text: '. Enter it below to confirm your account and continue into the app.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: _otpLength,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                if (v.trim().length == _otpLength) _verify();
              },
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 12,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • • • •',
                hintStyle: TextStyle(
                  fontSize: 24,
                  letterSpacing: 10,
                  color: AppColors.textSecondary.withAlpha(100),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Code valid for 60 minutes',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_codeExpired) ...[   
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your code has expired. Request a new one below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifying ? null : _verify,
                child: _verifying
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Verify & Continue'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: BorderSide(
                    color: (_resendCooldown > 0 || _resending)
                        ? AppColors.textHint
                        : AppColors.primaryTeal,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_resendCooldown > 0 || _resending) ? null : _resend,
                icon: _resending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primaryTeal),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: _resending
                    ? const Text('Sending new code…')
                    : _resendCooldown > 0
                        ? Text('Resend in ${_resendCooldown}s',
                            style: const TextStyle(
                                color: AppColors.textSecondary))
                        : const Text('Send a new code'),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.primaryTeal, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check your spam folder if you don\'t see the email within a minute. After verification, open the left menu in the app to enter the homeowner\'s invite code.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryTeal.withAlpha(220),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked = name.length <= 2
        ? name
        : '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}';
    return '$masked@${parts[1]}';
  }
}
