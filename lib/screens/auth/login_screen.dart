import 'dart:async';

import 'package:flutter/material.dart';
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

class _LoginScreenState extends State<LoginScreen> {
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
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _handleOAuthSignIn();
      }
    });
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
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
    if (auth.isLoggedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect email or password.')),
      );
    }
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
    if (hasHousehold) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      // First-time Google user – ask for household name
      _showHouseholdSetupSheet(auth);
    }
  }

  void _showHouseholdSetupSheet(AuthProvider auth) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('One more step',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Give your household a name to get started.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Household name (e.g. The Kamau Home)',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx);
                  await auth.completeOwnerSetup(
                    fullName: auth.currentUser?.fullName ?? 'Owner',
                    email: auth.currentUser?.email ?? '',
                    householdName: name,
                  );
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (_) => false,
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
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
                const SizedBox(height: 32),

                // Email / Phone field
                TextFormField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.text,
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
                const SizedBox(height: 28),

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
