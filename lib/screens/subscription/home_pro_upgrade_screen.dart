import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';

class HomeProUpgradeScreen extends StatefulWidget {
  final String? source;

  const HomeProUpgradeScreen({super.key, this.source});

  static Future<void> open(BuildContext context, {String? source}) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HomeProUpgradeScreen(source: source)),
    );
  }

  @override
  State<HomeProUpgradeScreen> createState() => _HomeProUpgradeScreenState();
}

class _HomeProUpgradeScreenState extends State<HomeProUpgradeScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final household = auth.household;
    final isOwner = auth.isOwner;
    final source = widget.source;
    final sourceLabel = source == null || source.trim().isEmpty
        ? null
        : _formatSource(source);
    final canSubmitUpgrade = isOwner && !auth.isHomePro && household != null;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(title: const Text('Home Pro')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryTeal, AppColors.secondaryTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: HomePlanBadge(
                        label: 'Home Pro',
                        isPro: true,
                        compact: false,
                        useLightText: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  auth.isHomePro
                      ? 'Your household is already on Home Pro.'
                      : 'Run the home with sharper visibility, cleaner coordination, and analytics that actually help you act.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  household?.householdName?.isNotEmpty == true
                      ? '${household!.householdName} is on ${auth.householdPlanLabel}. Home Pro adds premium analytics, advanced household coordination, and fewer limits.'
                      : 'Your current plan is ${auth.householdPlanLabel}. Home Pro adds premium analytics, advanced household coordination, and fewer limits.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _HeroPill(label: 'Supplies analytics'),
                    _HeroPill(label: 'Utilities analytics'),
                    _HeroPill(label: 'Meal trends'),
                    _HeroPill(label: 'Staff scheduling'),
                  ],
                ),
                if (sourceLabel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'Opened from: $sourceLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          HomeFlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why households upgrade',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                const _BenefitRow(
                  title: 'See pressure before things break',
                  subtitle:
                      'Spot low stock, bill risk, and repeat household patterns before they become friction.',
                  icon: Icons.visibility_outlined,
                ),
                const SizedBox(height: 12),
                const _BenefitRow(
                  title: 'Coordinate more people without chaos',
                  subtitle:
                      'Manage children, staff schedules, and day-to-day running with fewer manual follow-ups.',
                  icon: Icons.groups_2_outlined,
                ),
                const SizedBox(height: 12),
                const _BenefitRow(
                  title: 'Move from records to decisions',
                  subtitle:
                      'Use analytics surfaces that tell you what needs attention now, not just what was entered.',
                  icon: Icons.auto_graph_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HomeFlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What Home Pro unlocks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _FeatureBullet(
                  icon: Icons.groups_2_outlined,
                  title: 'Unlimited children',
                  subtitle:
                      'Free households can track up to ${AppConstants.freeMaxChildren} children. Home Pro removes that cap.',
                ),
                const SizedBox(height: 12),
                const _FeatureBullet(
                  icon: Icons.restaurant_outlined,
                  title: 'Meal analytics',
                  subtitle:
                      'See nutrition trends, top foods, and patterns across your household.',
                ),
                const SizedBox(height: 12),
                const _FeatureBullet(
                  icon: Icons.local_laundry_service_outlined,
                  title: 'Laundry analytics',
                  subtitle:
                      'Track load trends, bedroom breakdowns, and completion patterns.',
                ),
                const SizedBox(height: 12),
                const _FeatureBullet(
                  icon: Icons.badge_outlined,
                  title: 'Staff scheduling',
                  subtitle:
                      'Manage schedules, availability, leave windows, and replacements from one place.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          HomeFlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plan overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _StatusRow(label: 'Plan', value: auth.householdPlanLabel),
                const SizedBox(height: 10),
                _StatusRow(
                  label: 'Status',
                  value: household?.planStatusLabel ?? 'Active',
                ),
                const SizedBox(height: 10),
                _StatusRow(
                  label: 'Expires',
                  value: household?.planExpiresAt != null
                      ? _formatDate(household!.planExpiresAt!)
                      : 'No expiry set',
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: auth.isHomePro
                        ? AppColors.statusEnough
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryTeal.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    auth.isHomePro
                        ? 'Home Pro is active for this household. Keep using the premium analytics and coordination tools across the app.'
                        : isOwner
                        ? 'Requesting Home Pro marks this household for upgrade and prepares the checkout handoff. The payment connection is the next step, but this is now the single upgrade surface.'
                        : 'Only the homeowner can submit the upgrade request. You can still review what Home Pro includes and coordinate with them from here.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting || auth.isHomePro
                  ? null
                  : () => _handlePrimaryAction(
                      context,
                      isOwner: isOwner,
                      canSubmitUpgrade: canSubmitUpgrade,
                    ),
              icon: Icon(
                isOwner ? Icons.phone_android_outlined : Icons.info_outline,
              ),
              label: Text(
                auth.isHomePro
                    ? 'Home Pro is active'
                    : _isSubmitting
                    ? 'Submitting request...'
                    : isOwner
                    ? 'Request Home Pro Access'
                    : 'Ask Homeowner to Upgrade',
              ),
            ),
          ),
          if (!auth.isHomePro) ...[
            const SizedBox(height: 10),
            Text(
              isOwner
                  ? 'You are requesting the upgrade for this household. Payment activation will plug into this same flow.'
                  : 'The homeowner needs to submit the request from this screen.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!auth.isHomePro)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _handlePrimaryAction(
    BuildContext context, {
    required bool isOwner,
    required bool canSubmitUpgrade,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!isOwner) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Only the homeowner can start the Home Pro upgrade. Ask them to open this screen and submit the request.',
          ),
        ),
      );
      return;
    }
    if (!canSubmitUpgrade) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This household is not ready for an upgrade request yet.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final householdId = context.read<AuthProvider>().household!.id;
    final ok = await SyncService.submitUpgradeRequest(
      householdId: householdId,
      requestedPlanCode: 'home_pro',
      source: widget.source,
      notes:
          'Submitted from the Home Pro upgrade screen while M-Pesa checkout is pending integration.',
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Upgrade request submitted. Next: connect this flow to M-Pesa checkout and plan activation.'
              : 'Could not submit the upgrade request. Confirm the new app schema has been applied in Supabase.',
        ),
      ),
    );
  }

  String _formatSource(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }
}

class _FeatureBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;

  const _HeroPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _BenefitRow({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
