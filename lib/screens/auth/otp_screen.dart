import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../main_shell.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final String? householdName;
  final String? homeownerInviteCode;
  final String? deliveryAddress;
  final String? deliveryPhone;

  const OtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    this.householdName,
    this.homeownerInviteCode,
    this.deliveryAddress,
    this.deliveryPhone,
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
  int _resendCooldown = 30;

  bool get _isJoiningExistingHousehold =>
      widget.homeownerInviteCode?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
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

    if (!_isJoiningExistingHousehold) {
      final householdName = widget.householdName?.trim() ?? '';
      final deliveryAddress = widget.deliveryAddress?.trim() ?? '';
      if (householdName.isEmpty || deliveryAddress.isEmpty) {
        _showError('Your household details are incomplete. Go back and enter the household name and delivery address again.');
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
          deliveryAddress: widget.deliveryAddress!.trim(),
          deliveryPhone: widget.deliveryPhone?.trim(),
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
      final msg = e.message.toLowerCase();
      if (!otpVerified && (msg.contains('expired') || msg.contains('invalid'))) {
        _otpCtrl.clear();
        setState(() => _codeExpired = true);
        _showError('That code has expired. Tap Send a new code below.');
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
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email.trim().toLowerCase(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent to your email.'),
        ),
      );
      setState(() {
        _codeExpired = false;
        _resendCooldown = 30;
      });
      _startCooldown();
    } catch (_) {
      if (!mounted) return;
      _showError('Could not resend the code. Please try again.');
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
        title: const Text('Your household is ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share these codes with the right people when they sign up.',
            ),
            const SizedBox(height: 16),
            if (managerInviteCode.isNotEmpty)
              _InviteCodeCard(
                label: 'House manager code',
                code: managerInviteCode,
                helper: 'Use this for house managers joining the household.',
              ),
            if (managerInviteCode.isNotEmpty && homeownerInviteCode.isNotEmpty)
              const SizedBox(height: 12),
            if (homeownerInviteCode.isNotEmpty)
              _InviteCodeCard(
                label: 'Additional homeowner code',
                code: homeownerInviteCode,
                helper: 'Use this for other homeowners joining the same household.',
              ),
            const SizedBox(height: 8),
            const Text(
              'You can find both codes later from the account drawer under household access.',
              style: TextStyle(fontSize: 12),
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
                  : 'Household: ${widget.householdName ?? '—'}\nDelivery address: ${widget.deliveryAddress ?? '—'}',
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
                    ? 'This code has expired. Send a new one below.'
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
                        'Your code has expired. Request a new one below.',
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _resendCooldown > 0
                        ? 'Send a new code in ${_resendCooldown}s'
                        : 'Didn\'t get the code?',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
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
                      ? const Text('Sending new code…')
                      : _resendCooldown > 0
                          ? Text(
                              'Resend in ${_resendCooldown}s',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            )
                          : const Text('Send a new code'),
                ),
              ],
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

  const _InviteCodeCard({
    required this.label,
    required this.code,
    required this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            style: const TextStyle(fontSize: 12),
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