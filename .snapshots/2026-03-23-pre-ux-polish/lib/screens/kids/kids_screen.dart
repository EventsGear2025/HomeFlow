import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/child_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_chips.dart';

class KidsScreen extends StatelessWidget {
  const KidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final childProvider = context.watch<ChildProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Kids & School'),
        actions: [
          // Only owner can add children
          if (auth.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Add child',
              onPressed: () => _showAddChildSheet(context),
            ),
        ],
      ),
      // FAB only for owner
      floatingActionButton: auth.isOwner
          ? FloatingActionButton.extended(
              heroTag: 'kids_fab',
              backgroundColor: AppColors.primaryTeal,
              onPressed: () => _showAddChildSheet(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Child',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: childProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : childProvider.children.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.child_care_outlined,
                  title: 'No children added yet',
                  subtitle: auth.isOwner
                      ? 'Add your children to track their daily school routine'
                      : 'The household owner has not added any children yet',
                  buttonLabel: auth.isOwner ? 'Add Child' : null,
                  onButton: auth.isOwner
                      ? () => _showAddChildSheet(context)
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...childProvider.children.map((child) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChildCard(child: child),
                        )),
                    const SizedBox(height: 80),
                  ],
                ),
    );
  }

  void _showAddChildSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddChildSheet(),
    );
  }
}

class _ChildCard extends StatefulWidget {
  final ChildModel child;
  const _ChildCard({required this.child});

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final childProvider = context.read<ChildProvider>();
    final auth = context.read<AuthProvider>();

    final today = DateTime.now();
    var log = childProvider.getTodaysLog(widget.child.id);

    if (log == null) {
      const uuid = Uuid();
      log = ChildRoutineLog(
        id: uuid.v4(),
        childId: widget.child.id,
        date: today,
        updatedByUserId: auth.currentUser?.id ?? '',
      );
    }

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.child.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTeal),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.child.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      if (widget.child.schoolName != null)
                        Text(widget.child.schoolName!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                ReadinessChip(
                  isReady: log.checkedCount >= 4,
                  label: log.checkedCount >= 4 ? 'Ready' : 'In Progress',
                ),
                const SizedBox(width: 4),
                Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textHint,
                    size: 20),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _CheckItem(
              label: 'Uniform Ready',
              icon: Icons.checkroom_outlined,
              value: log.uniformReady,
              onChanged: (v) {
                log!.uniformReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Shoes & Socks Ready',
              icon: Icons.directions_walk_outlined,
              value: log.shoesReady,
              onChanged: (v) {
                log!.shoesReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Lunch Packed',
              icon: Icons.lunch_dining_outlined,
              value: log.lunchPacked,
              onChanged: (v) {
                log!.lunchPacked = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            if (widget.child.snackRequired)
              _CheckItem(
                label: 'Snack Packed',
                icon: Icons.cookie_outlined,
                value: log.snackPacked,
                onChanged: (v) {
                  log!.snackPacked = v;
                  childProvider.updateRoutineLog(log, auth.household!.id);
                  setState(() {});
                },
              ),
            _CheckItem(
              label: 'Swimwear Ready',
              icon: Icons.pool_outlined,
              value: log.swimwearReady,
              onChanged: (v) {
                log!.swimwearReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            const Divider(height: 20),
            _CheckItem(
              label: 'Dropped at School',
              icon: Icons.directions_bus_outlined,
              value: log.droppedOff,
              onChanged: (v) {
                log!.droppedOff = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Picked Up',
              icon: Icons.home_outlined,
              value: log.pickedUp,
              onChanged: (v) {
                log!.pickedUp = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckItem({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: value
                    ? AppColors.primaryTeal
                    : AppColors.textHint),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: value
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  decoration:
                      value ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textHint,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primaryTeal
                    : AppColors.backgroundLight,
                shape: BoxShape.circle,
                border: Border.all(
                    color: value
                        ? AppColors.primaryTeal
                        : AppColors.divider),
              ),
              child: value
                  ? const Icon(Icons.check,
                      color: AppColors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _nameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  bool _snackRequired = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _classCtrl.dispose();
    _dropoffCtrl.dispose();
    _pickupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final childProvider = context.read<ChildProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Child',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Child\'s name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _schoolCtrl,
              decoration:
                  const InputDecoration(labelText: 'School name (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _classCtrl,
              decoration: const InputDecoration(
                  labelText: 'Class / Grade (optional)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dropoffCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Drop-off time'),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pickupCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Pick-up time'),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text('Requires school snack?',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ),
                Switch(
                  value: _snackRequired,
                  onChanged: (v) => setState(() => _snackRequired = v),
                  activeColor: AppColors.primaryTeal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                const uuid = Uuid();
                final child = ChildModel(
                  id: uuid.v4(),
                  householdId: auth.household!.id,
                  name: _nameCtrl.text.trim(),
                  schoolName: _schoolCtrl.text.trim().isEmpty
                      ? null
                      : _schoolCtrl.text.trim(),
                  className: _classCtrl.text.trim().isEmpty
                      ? null
                      : _classCtrl.text.trim(),
                  dropoffTime: _dropoffCtrl.text.trim().isEmpty
                      ? null
                      : _dropoffCtrl.text.trim(),
                  pickupTime: _pickupCtrl.text.trim().isEmpty
                      ? null
                      : _pickupCtrl.text.trim(),
                  snackRequired: _snackRequired,
                );
                childProvider.addChild(child, auth.household!.id);
                Navigator.pop(context);
              },
              child: const Text('Add Child'),
            ),
          ],
        ),
      ),
    );
  }
}
