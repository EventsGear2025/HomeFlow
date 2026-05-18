import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'login_screen.dart';
import 'manager_otp_screen.dart';
import 'otp_screen.dart';
import '../main_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Create Account',
            style: TextStyle(color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Container(
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
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _OwnerSignUpForm(),
          _ManagerSignUpForm(),
        ],
      ),
    );
  }
}

// ── Owner Sign-Up ──────────────────────────────────────────────────────────────

class _OwnerSignUpForm extends StatefulWidget {
  const _OwnerSignUpForm();

  @override
  State<_OwnerSignUpForm> createState() => _OwnerSignUpFormState();
}

class _OwnerSignUpFormState extends State<_OwnerSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _householdCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _deliveryAddressCtrl = TextEditingController();
  final _deliveryPhoneCtrl = TextEditingController();
  bool _obscure = true;
  bool _joiningExistingHousehold = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _householdCtrl.dispose();
    _inviteCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _deliveryPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim().toLowerCase();
    final fullName = _nameCtrl.text.trim();
    final householdName = _householdCtrl.text.trim();
    final inviteCode = _inviteCtrl.text.trim().toUpperCase();
    final deliveryAddress = _deliveryAddressCtrl.text.trim();
    final deliveryPhone = _deliveryPhoneCtrl.text.trim();
    bool needsEmailConfirmation;
    try {
      if (_joiningExistingHousehold) {
        needsEmailConfirmation =
            await auth.signUpAdditionalHomeownerPreStep(
          fullName: fullName,
          email: email,
          password: _passwordCtrl.text,
        );
      } else {
        needsEmailConfirmation = await auth.signUpOwner(
          fullName: fullName,
          email: email,
          password: _passwordCtrl.text,
          householdName: householdName,
          deliveryAddress: deliveryAddress,
          deliveryPhone: deliveryPhone,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    if (!mounted) return;

    if (!needsEmailConfirmation) {
      try {
        if (_joiningExistingHousehold) {
          await auth.completeAdditionalOwnerSetup(
            fullName: fullName,
            email: email,
            inviteCode: inviteCode,
          );
        } else {
          await auth.completeOwnerSetup(
            fullName: fullName,
            email: email,
            householdName: householdName,
            deliveryAddress: deliveryAddress,
            deliveryPhone: deliveryPhone,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
      return;
    }

    setState(() => _loading = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: email,
          fullName: fullName,
          householdName:
              _joiningExistingHousehold ? null : householdName,
          homeownerInviteCode:
              _joiningExistingHousehold ? inviteCode : null,
          deliveryAddress:
              _joiningExistingHousehold ? null : deliveryAddress,
          deliveryPhone:
              _joiningExistingHousehold ? null : deliveryPhone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _InfoBanner(
              icon: Icons.verified_user_outlined,
              text: _joiningExistingHousehold
                  ? 'Use the homeowner invite code from an existing household. You\'ll verify your email first, then join that household as an additional homeowner.'
                  : 'Create your household account. Add the exact delivery address now, then share separate invite codes with house managers and additional homeowners.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _HouseholdModeTile(
                    selected: !_joiningExistingHousehold,
                    title: 'Create a new household',
                    subtitle:
                        'Set up the household, delivery address, and invite codes.',
                    onTap: () => setState(() => _joiningExistingHousehold = false),
                  ),
                  const Divider(height: 8),
                  _HouseholdModeTile(
                    selected: _joiningExistingHousehold,
                    title: 'Join an existing household',
                    subtitle:
                        'Use the homeowner invite code from another homeowner.',
                    onTap: () => setState(() => _joiningExistingHousehold = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
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
                  v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),
            if (_joiningExistingHousehold) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _inviteCtrl,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Homeowner invite code',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                  hintText: 'e.g. A1B2C3D4',
                  counterText: '',
                ),
                validator: (v) => v == null || v.trim().length != 8
                    ? 'Enter the 8-character homeowner invite code'
                    : null,
              ),
            ] else ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _householdCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Household name (e.g. The Kamau Home)',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the household name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _deliveryAddressCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                  hintText: 'Estate, house number, landmark, and delivery notes',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the delivery address'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _deliveryPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Delivery contact phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || auth.isLoading) ? null : _submit,
                child: (_loading || auth.isLoading)
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_joiningExistingHousehold
                        ? 'Join Household & Verify Email'
                        : 'Create Household & Verify Email'),
              ),
            ),
            const SizedBox(height: 16),
            _SignInLink(),
          ],
        ),
      ),
    );
  }
}

// ── Manager Sign-Up ────────────────────────────────────────────────────────────

class _ManagerSignUpForm extends StatefulWidget {
  const _ManagerSignUpForm();

  @override
  State<_ManagerSignUpForm> createState() => _ManagerSignUpFormState();
}

class _ManagerSignUpFormState extends State<_ManagerSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim().toLowerCase();
    final fullName = _nameCtrl.text.trim();
    bool needsEmailConfirmation;
    try {
      needsEmailConfirmation = await auth.signUpManagerPreStep(
        fullName: fullName,
        email: email,
        password: _passwordCtrl.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    if (!mounted) return;

    if (!needsEmailConfirmation) {
      // Session available immediately — complete setup and go to the app.
      try {
        await auth.completeManagerSetup(
          fullName: fullName,
          email: email,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
      return;
    }

    // Email confirmation required.
    // Navigate to OTP screen so the manager can enter the code from their email.
    // Household join is deferred until OTP verification succeeds.
    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerOtpScreen(
          email: email,
          fullName: fullName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _InfoBanner(
              icon: Icons.mail_outline,
              text:
                  'Create your manager account first. After you verify your email and enter the app, open the left menu to join a household with the homeowner\'s 8-character invite code.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
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
                  v == null || v.length < 6 ? 'Min 6 characters' : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || auth.isLoading) ? null : _submit,
                child: (_loading || auth.isLoading)
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create Manager Account'),
              ),
            ),
            const SizedBox(height: 16),
            _SignInLink(),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _HouseholdModeTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HouseholdModeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? AppColors.primaryTeal
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryTeal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        child: const Text('Already have an account? Sign In'),
      ),
    );
  }
}
