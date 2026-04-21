import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../main_shell.dart';

class ManagerOtpScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String inviteCode;

  const ManagerOtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    required this.inviteCode,
  });

  @override
  State<ManagerOtpScreen> createState() => _ManagerOtpScreenState();
}

class _ManagerOtpScreenState extends State<ManagerOtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Enter the verification code from your email.');
      return;
    }
    setState(() => _verifying = true);
    final normalizedEmail = widget.email.trim().toLowerCase();
    try {
      debugPrint('[ManagerOTP] Verifying token "$otp" for $normalizedEmail');

      await Supabase.instance.client.auth.verifyOTP(
        email: normalizedEmail,
        token: otp,
        type: OtpType.signup,
      );
      debugPrint('[ManagerOTP] Verified successfully');

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      debugPrint('[ManagerOTP] Starting completeManagerSetup...');
      await auth.completeManagerSetup(
        fullName: widget.fullName,
        email: normalizedEmail,
        inviteCode: widget.inviteCode,
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
      _showError(e.message);
    } catch (e) {
      debugPrint('[ManagerOTP] Error: $e');
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    setState(() => _resending = true);
    try {
      final normalizedEmail = widget.email.trim().toLowerCase();
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: normalizedEmail,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent to your email.')),
      );
      setState(() => _resendCooldown = 60);
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      _showError('Could not resend the code. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() async {
    while (_resendCooldown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _resendCooldown--);
    }
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
      body: Padding(
        padding: const EdgeInsets.all(28),
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
                      text: '. Enter it below to confirm your account and join the household.'),
                ],
              ),
            ),
            const SizedBox(height: 36),
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 8,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 12,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                hintStyle: TextStyle(
                  fontSize: 24,
                  letterSpacing: 10,
                  color: AppColors.textSecondary.withAlpha(100),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 32),
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
                    : const Text('Verify & Join Household'),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: (_resendCooldown > 0 || _resending) ? null : _resend,
                child: _resending
                    ? const Text('Sending…')
                    : _resendCooldown > 0
                        ? Text('Resend code in ${_resendCooldown}s',
                            style:
                                const TextStyle(color: AppColors.textSecondary))
                        : const Text('Didn\'t receive it? Resend code'),
              ),
            ),
            const Spacer(),
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
                      'Check your spam folder if you don\'t see the email within a minute.',
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
