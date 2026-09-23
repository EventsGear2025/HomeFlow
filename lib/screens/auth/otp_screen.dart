import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../utils/app_colors.dart';
import '../main_shell.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String? householdName;
  final String? homeownerInviteCode;

  const OtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    this.householdName,
    this.homeownerInviteCode,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 8;

  final TextEditingController _otpCtrl = TextEditingController();
  Timer? _cooldownTimer;

  bool _verifying = false;
  bool _resending = false;
  bool _codeExpired = false;
  int _resendCooldown = SupabaseAuthService.signupResendCooldownSeconds;

  bool get _isJoiningExistingHousehold =>
      widget.homeownerInviteCode?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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

    if (!_isJoiningExistingHousehold) {
      final householdName = widget.householdName?.trim() ?? '';
      if (householdName.isEmpty) {
        _showError('Your household details are incomplete. Go back and enter the household name again.');
        return;
      }
    }

    setState(() => _verifying = true);
    final normalizedEmail = widget.email.trim().toLowerCase();
    bool otpVerified = false;

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: normalizedEmail,
        token: otp,
        type: OtpType.signup,
      );
      otpVerified = true;

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      if (_isJoiningExistingHousehold) {
        await auth.completeAdditionalOwnerSetup(
          fullName: widget.fullName,
          email: normalizedEmail,
          inviteCode: widget.homeownerInviteCode!.trim(),
        );
      } else {
        await auth.completeOwnerSetup(
          fullName: widget.fullName,
          email: normalizedEmail,
          householdName: widget.householdName!.trim(),
        );
      }

      if (!mounted) return;

      if (!_isJoiningExistingHousehold) {
        final managerInviteCode = auth.managerInviteCode;
        final homeownerInviteCode = auth.homeownerInviteCode;
        if (managerInviteCode.isNotEmpty || homeownerInviteCode.isNotEmpty) {
          await _showInviteCodes(
            managerInviteCode: managerInviteCode,
            homeownerInviteCode: homeownerInviteCode,
          );
        }
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final code = e.code?.toLowerCase();
      final msg = e.message.toLowerCase();
      if (!otpVerified && (code == 'otp_expired' || msg.contains('expired'))) {
        _otpCtrl.clear();
        setState(() => _codeExpired = true);
        _showError('That code didn\'t work. It may be incorrect or expired — tap resend below for a new one.');
      } else if (!otpVerified && msg.contains('invalid')) {
        _otpCtrl.clear();
        setState(() => _codeExpired = false);
        _showError(
          'That code is no longer valid. Use the most recent email we sent or tap resend below.',
        );
      } else {
        _showError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('ClientException') ||
          msg.contains('TimeoutException') ||
          msg.contains('Network')) {
        _showError('No internet connection. Please check your network and try again.');
      } else {
        _showError(msg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);

    try {
      await SupabaseAuthService().resendOtp(
        email: widget.email.trim().toLowerCase(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We resent the confirmation email to your inbox.'),
        ),
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
      if (mounted) {
        setState(() => _resending = false);
      }
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
      setState(() => _resendCooldown -= 1);
    });
  }

  Future<void> _showInviteCodes({
    required String managerInviteCode,
    required String homeownerInviteCode,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Your household is ready',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Text(
                'Share each code with the right person during sign-up. You can always find them again later from Household access.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (managerInviteCode.isNotEmpty)
              _InviteCodeCard(
                label: 'Manager sign-up code',
                code: managerInviteCode,
                helper:
                    'Share this with the person joining as your house manager.',
                backgroundColor: AppColors.statusVeryLow,
                borderColor: AppColors.accentOrange.withValues(alpha: 0.22),
                labelColor: AppColors.accentOrange,
              ),
            if (managerInviteCode.isNotEmpty && homeownerInviteCode.isNotEmpty)
              const SizedBox(height: 12),
            if (homeownerInviteCode.isNotEmpty)
              _InviteCodeCard(
                label: 'Additional homeowner code',
                code: homeownerInviteCode,
                helper:
                    'Share this with another homeowner joining the same household.',
                backgroundColor: AppColors.surfaceLight,
                borderColor: AppColors.divider,
                labelColor: AppColors.textSecondary,
              ),
            const SizedBox(height: 8),
            const Text(
              'You can also copy the codes now and send them later when needed.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (managerInviteCode.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy manager code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: managerInviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Manager invite code copied.'),
                  ),
                );
              },
            ),
          if (homeownerInviteCode.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy homeowner code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: homeownerInviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Homeowner invite code copied.'),
                  ),
                );
              },
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
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
        title: Text(
          _isJoiningExistingHousehold
              ? 'Verify & Join Household'
              : 'Verify Your Email',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(
              icon: _isJoiningExistingHousehold
                  ? Icons.group_add_outlined
                  : Icons.mark_email_read_outlined,
              title: _isJoiningExistingHousehold
                  ? 'Verify your email and join the household'
                  : 'Verify your email to finish setup',
              subtitle: _isJoiningExistingHousehold
                  ? 'Enter the $_otpLength-digit code sent to $maskedEmail. Once verified, this account will join the household linked to your homeowner invite code.'
                  : 'Enter the $_otpLength-digit code sent to $maskedEmail. We will finish creating your household after verification.',
            ),
            const SizedBox(height: 18),
            _InlineStatusCard(
              title: _isJoiningExistingHousehold
                  ? 'Joining as an additional homeowner'
                  : 'Creating a new household',
              body: _isJoiningExistingHousehold
                  ? 'Invite code: ${widget.homeownerInviteCode ?? '—'}'
                  : 'Household: ${widget.householdName ?? '—'}',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: _otpLength,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_otpLength),
              ],
              onChanged: (value) {
                if (value.trim().length == _otpLength) {
                  _verify();
                }
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
                errorText: _codeExpired
                    ? 'That code didn\'t work. Send a new one below.'
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
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
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'That code didn\'t work. It may be incorrect or expired — request a new one below.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
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
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isJoiningExistingHousehold
                            ? 'Verify & Join Household'
                            : 'Verify & Finish Setup',
                      ),
              ),
            ),
            const SizedBox(height: 16),
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
                onPressed:
                    (_resending || _resendCooldown > 0) ? null : _resend,
                icon: _resending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryTeal,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: _resending
                    ? const Text('Resending email…')
                    : _resendCooldown > 0
                        ? Text(
                            'Resend email in ${_resendCooldown}s',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          )
                        : const Text('Resend email'),
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
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryTeal,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check your spam or junk folder if you do not see the email within a minute.',
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
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final String label;
  final String code;
  final String helper;
  final Color backgroundColor;
  final Color borderColor;
  final Color labelColor;

  const _InviteCodeCard({
    required this.label,
    required this.code,
    required this.helper,
    required this.backgroundColor,
    required this.borderColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryTeal, size: 28),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatusCard extends StatelessWidget {
  final String title;
  final String body;

  const _InlineStatusCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}