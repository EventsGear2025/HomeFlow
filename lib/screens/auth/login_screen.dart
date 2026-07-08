import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../main_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // email or phone
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Triple-tap demo access
  int _tapCount = 0;
  DateTime? _firstTap;

  // Google OAuth listener
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        // Only handle OAuth (Google, etc.) sign-ins here.
        // Email/OTP verifications also fire signedIn but are handled by
        // OtpScreen directly — letting them through would show the
        // "One more step" sheet prematurely.
        final provider =
            data.session?.user.appMetadata['provider']?.toString();
        if (provider != null && provider != 'email') {
          _handleOAuthSignIn();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _identifierCtrl.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool sending = false;
        bool sent = false;
        return StatefulBuilder(
          builder: (ctx, setLS) => AlertDialog(
            title: const Text('Reset password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!sent) ...[
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.statusEnoughText, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reset link sent to ${emailCtrl.text.trim()}. Check your inbox (and spam folder).',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: sent
                ? [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: sending
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid email address'),
                                  ),
                                );
                                return;
                              }
                              setLS(() => sending = true);
                              try {
                                await context
                                    .read<AuthProvider>()
                                    .sendPasswordReset(email);
                                setLS(() {
                                  sending = false;
                                  sent = true;
                                });
                              } catch (e) {
                                setLS(() => sending = false);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text(e
                                      .toString()
                                      .replaceFirst('Exception: ', '')),
                                  backgroundColor: Colors.red.shade700,
                                ));
                              }
                            },
                      child: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Send reset link'),
                    ),
                  ],
          ),
        );
      },
    );
    emailCtrl.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final isManagerTab = _tabCtrl.index == 1;
    try {
      await auth.login(
        email: _identifierCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect email or password.')),
      );
      return;
    }

    // If the user chose the Manager tab, try to load their manager profile.
    if (isManagerTab) {
      final switched = await auth.switchToManagerProfile();
      if (!mounted) return;
      if (!switched && !auth.isHouseManager) {
        // No manager account found — inform the user and stay on login.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No house manager account found for this email. '
              'If you\'re a homeowner, please use the Homeowner tab.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        // Also sign out so state is clean.
        await auth.logout();
        return;
      }
      if (!switched && auth.isHouseManager) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in successfully. Join a household from the left menu to continue.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _googleSignIn() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.signInWithGoogle();
      // Deep link callback handled in _handleOAuthSignIn via stream
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _handleOAuthSignIn() async {
    final auth = context.read<AuthProvider>();
    final hasHousehold = await auth.loadAfterOAuth();
    if (!mounted) return;
    if (!hasHousehold) {
      // First-time Google user — create household with a default name.
      // The owner will be nudged to complete details from the left panel.
      final firstName = (auth.currentUser?.fullName ?? '').split(' ').first;
      final defaultName =
          firstName.isNotEmpty ? "$firstName's Home" : 'My Home';
      await auth.completeOwnerSetup(
        fullName: auth.currentUser?.fullName ?? 'Owner',
        email: auth.currentUser?.email ?? '',
        householdName: defaultName,
      );
      if (!mounted) return;
      final managerCode = auth.managerInviteCode;
      final homeownerCode = auth.homeownerInviteCode;
      if (managerCode.isNotEmpty || homeownerCode.isNotEmpty) {
        await _showInviteCodes(
          managerInviteCode: managerCode,
          homeownerInviteCode: homeownerCode,
        );
      }
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                helper: 'Share this with the person joining as your house manager.',
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
                helper: 'Share this with another homeowner joining the same household.',
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
                  const SnackBar(content: Text('Manager invite code copied.')),
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
                  const SnackBar(content: Text('Homeowner invite code copied.')),
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

  void _onLogoTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > const Duration(seconds: 2)) {
      _firstTap = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    if (_tapCount >= 5) {
      _tapCount = 0;
      _firstTap = null;
      setState(() {
        _identifierCtrl.text = kBuildOwnerEmail;
        _passwordCtrl.text = kBuildPassword;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo credentials loaded.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Logo with secret 5-tap demo access
                GestureDetector(
                  onTap: _onLogoTap,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.home_rounded,
                            color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'homeFlow',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text('Welcome back',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text('Sign in to your homeFlow account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        )),
                const SizedBox(height: 24),

                // Role selector tabs (mirrors Sign Up screen)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      color: AppColors.primaryTeal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [
                      Tab(text: 'I\'m a Homeowner'),
                      Tab(text: 'I\'m a Manager'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Email / Phone field
                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone number',
                    prefixIcon: Icon(Icons.person_outline),
                    hintText: 'you@example.com or +254700000000',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your email or phone number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sign In button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 20),

                // Google Sign In button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: auth.isLoading ? null : _googleSignIn,
                    icon: _GoogleIcon(),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign Up link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    ),
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw colored arcs to approximate the Google 'G' logo
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    final angles = [
      [0.0, 0.5],
      [0.5, 0.25],
      [0.75, 0.125],
      [0.875, 0.25],
    ];

    for (var i = 0; i < 4; i++) {
      arcPaint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.8),
        angles[i][0] * 3.14159 * 2 - 3.14159 / 2,
        angles[i][1] * 3.14159 * 2,
        false,
        arcPaint,
      );
    }
    // Blue horizontal bar (the cross of the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + r * 0.75, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
