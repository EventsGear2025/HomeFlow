import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shopping_request.dart';
import '../../models/supply_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supply_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_chips.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHOPPING SCREEN — 4-tab hybrid model
//   Tab 0 · Buy Now   : finished supplies + approved requests to buy
//   Tab 1 · Requests  : pending manager requests awaiting owner approval
//   Tab 2 · Deferred  : postponed items — revisit when ready
//   Tab 3 · History   : purchased / direct-buys log
// ─────────────────────────────────────────────────────────────────────────────

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supply = context.watch<SupplyProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.isOwner;

    final finished = supply.finishedSupplies;
    final pending = supply.pendingRequests;
    final approved = supply.approvedRequests;
    final ownerList = supply.ownerBuyList;
    final deferred = supply.deferredRequests;
    final history = supply.historyRequests;
    final directBuys = supply.unacknowledgedDirectBuys;

    // "Buy Now" = finished supplies + approved requests + owner's own list (owner only)
    final buyNowCount = finished.length + approved.length +
        (isOwner ? ownerList.length : 0);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Shopping'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: [
            Tab(text: 'Buy Now ($buyNowCount)'),
            Tab(text: 'Requests (${pending.length})'),
            Tab(text: 'On Hold (${deferred.length})'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(context, isOwner),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BuyNowTab(
            finished: finished,
            approved: approved,
            ownerList: ownerList,
            directBuys: directBuys,
            isOwner: isOwner,
          ),
          _RequestsTab(
            pending: pending,
            isOwner: isOwner,
          ),
          _DeferredTab(items: deferred),
          _HistoryTab(items: history),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context, bool isOwner) {
    return FloatingActionButton.extended(
      heroTag: 'shopping_fab',
      backgroundColor:
          isOwner ? AppColors.primaryTeal : AppColors.accentOrange,
      onPressed: () => isOwner
          ? _showOwnerAddSheet(context)
          : _showManagerRequestSheet(context),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        isOwner ? 'Add to My List' : 'Request Item',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showManagerRequestSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _ManagerRequestSheet(),
    );
  }

  void _showOwnerAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _OwnerAddSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — BUY NOW
// Shows: finished supplies (with Mark Bought / Defer) + approved requests
//        + owner's personal list
// ─────────────────────────────────────────────────────────────────────────────

class _BuyNowTab extends StatelessWidget {
  final List<SupplyItem> finished;
  final List<ShoppingRequest> approved;
  final List<ShoppingRequest> ownerList;
  final List<ShoppingRequest> directBuys;
  final bool isOwner;

  const _BuyNowTab({
    required this.finished,
    required this.approved,
    required this.ownerList,
    required this.directBuys,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    if (finished.isEmpty && approved.isEmpty && directBuys.isEmpty &&
        (ownerList.isEmpty || !isOwner)) {
      return const EmptyStateWidget(
        icon: Icons.shopping_cart_outlined,
        title: 'Nothing to buy right now',
        subtitle:
            'Items marked as Finished in Supplies will appear here automatically',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Direct-buy alert banner
        if (directBuys.isNotEmpty) ...[
          _SectionBanner(
            icon: Icons.flash_on_rounded,
            label:
                '${directBuys.length} item${directBuys.length > 1 ? 's' : ''} bought without approval — review',
            color: AppColors.accentOrange,
          ),
          const SizedBox(height: 10),
          ...directBuys.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestCard(request: r, isOwner: isOwner),
              )),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
        ],

        // Finished supplies — auto shopping list
        if (finished.isNotEmpty) ...[
          const _SectionLabel(label: 'FINISHED — NEEDS RESTOCKING'),
          const SizedBox(height: 8),
          ...finished.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FinishedSupplyCard(item: s),
              )),
          const SizedBox(height: 8),
        ],

        // Approved requests ready to buy
        if (approved.isNotEmpty) ...[
          const _SectionLabel(label: 'APPROVED — READY TO BUY'),
          const SizedBox(height: 8),
          ...approved.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestCard(request: r, isOwner: isOwner),
              )),
          const SizedBox(height: 8),
        ],

        // Owner's personal buy list — private, not visible to manager
        if (isOwner && ownerList.isNotEmpty) ...[
          const _SectionLabel(label: 'MY LIST'),
          const SizedBox(height: 8),
          ...ownerList.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OwnerListCard(request: r),
              )),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FINISHED SUPPLY CARD — auto-generated from supply status
// ─────────────────────────────────────────────────────────────────────────────

class _FinishedSupplyCard extends StatelessWidget {
  final SupplyItem item;
  const _FinishedSupplyCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final supply = context.read<SupplyProvider>();
    final auth = context.read<AuthProvider>();

    return HomeFlowCard(
      borderColor: AppColors.statusFinishedText.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.statusFinished,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.remove_shopping_cart_outlined,
                color: AppColors.statusFinishedText, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${item.category} · ${item.unitType}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Text('Finished',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.statusFinishedText,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: AppColors.statusEnoughText,
                    foregroundColor: Colors.white),
                onPressed: () {
                  supply.markSupplyRestocked(item.id, auth.household!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} marked as restocked'),
                      backgroundColor: AppColors.statusEnoughText,
                    ),
                  );
                },
                child: const Text('Mark Bought',
                    style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 6),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider)),
                onPressed: () =>
                    _showDeferDialog(context, item, supply, auth),
                child: const Text('Defer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeferDialog(BuildContext context, SupplyItem item,
      SupplyProvider supply, AuthProvider auth) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: AppColors.textSecondary, size: 20),
            SizedBox(width: 8),
            Text('Defer this item?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Put "${item.name}" on hold. '
              'You can revisit it anytime from the On Hold tab.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Not urgent right now',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Create a deferred shopping request for this supply
              const uuid = Uuid();
              final req = ShoppingRequest(
                id: uuid.v4(),
                householdId: auth.household!.id,
                supplyItemId: item.id,
                itemName: item.name,
                quantity: '1 ${item.unitType}',
                category: item.category,
                urgency: ShoppingUrgency.neededSoon,
                notes: reasonCtrl.text.trim().isEmpty
                    ? null
                    : reasonCtrl.text.trim(),
                status: ShoppingStatus.deferred,
                purchaseType: PurchaseType.managerRequest,
                requestedByUserId: auth.currentUser!.id,
                requestedByName: auth.currentUser!.fullName,
                requestedAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              supply.addShoppingRequest(req, auth.household!.id);
              // Keep supply as finished — will resurface if restocked
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Put On Hold — revisit anytime'),
                ),
              );
            },
            child: const Text('Defer'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — REQUESTS (manager-submitted, awaiting owner approval)
// ─────────────────────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final List<ShoppingRequest> pending;
  final bool isOwner;

  const _RequestsTab({required this.pending, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.inbox_outlined,
        title: 'No pending requests',
        subtitle: isOwner
            ? "Your manager's item requests will appear here"
            : 'Tap "Request Item" to flag something running low',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel(label: 'AWAITING YOUR APPROVAL'),
        const SizedBox(height: 8),
        ...pending.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(request: r, isOwner: isOwner),
            )),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — DEFERRED
// ─────────────────────────────────────────────────────────────────────────────

class _DeferredTab extends StatelessWidget {
  final List<ShoppingRequest> items;
  const _DeferredTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.schedule_outlined,
        title: 'Nothing on hold',
        subtitle:
            'Items you postpone will appear here — revisit them when ready',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.textHint, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These items were postponed. Tap "Revisit" to move them back to the active list.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DeferredCard(request: r),
            )),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _DeferredCard extends StatelessWidget {
  final ShoppingRequest request;
  const _DeferredCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final supply = context.read<SupplyProvider>();
    final auth = context.read<AuthProvider>();

    return HomeFlowCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.schedule_outlined,
                color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${request.quantity} · ${request.category}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (request.notes != null && request.notes!.isNotEmpty)
                  Text(request.notes!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white),
                onPressed: () {
                  supply.revisitRequest(request.id, auth.household!.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('${request.itemName} moved back to Requests'),
                      backgroundColor: AppColors.primaryTeal,
                    ),
                  );
                },
                child:
                    const Text('Revisit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — HISTORY
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List<ShoppingRequest> items;
  const _HistoryTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No history yet',
        subtitle: 'Purchased items will appear here',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RequestCard(
            request: items[i], isOwner: false, isHistory: true),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final ShoppingRequest request;
  final bool isOwner;
  final bool isHistory;

  const _RequestCard({
    required this.request,
    required this.isOwner,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final supply = context.read<SupplyProvider>();
    final auth = context.read<AuthProvider>();
    final isBuyAnyway = request.wasBuyAnyway;

    return HomeFlowCard(
      borderColor: isBuyAnyway
          ? AppColors.accentOrange.withValues(alpha: 0.5)
          : request.urgency == ShoppingUrgency.critical
              ? AppColors.danger.withValues(alpha: 0.3)
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${request.quantity} · ${request.category}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text('By ${request.requestedByName}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              _urgencyChip(request.urgency),
            ],
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.notes!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          // Buy Anyway banner
          if (isBuyAnyway) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.accentOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded,
                      color: AppColors.accentOrange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bought without approval: ${request.buyAnywayReason}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Auto-approved note
          if (request.autoApproved && request.autoApproveReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.statusEnough,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.statusEnoughText, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(request.autoApproveReason!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.statusEnoughText,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _statusBadge(request.status),
              const Spacer(),
              if (!isHistory) ...[
                // Owner: approve / defer pending requests
                if (isOwner && request.needsApproval) ...[
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 36)),
                    onPressed: () => supply.updateRequestStatus(
                        request.id,
                        ShoppingStatus.deferred,
                        auth.household!.id),
                    child: const Text('Defer'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: () => supply.updateRequestStatus(
                        request.id,
                        ShoppingStatus.approved,
                        auth.household!.id,
                        approvedByUserId: auth.currentUser!.id),
                    child: const Text('Approve'),
                  ),
                ],
                // Mark bought when approved or buy-anyway
                if (request.status == ShoppingStatus.approved ||
                    isBuyAnyway)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: AppColors.statusEnoughText),
                    onPressed: () {
                      supply.updateRequestStatus(
                          request.id,
                          ShoppingStatus.purchased,
                          auth.household!.id);
                      // If linked to a supply item, restock it too
                      if (request.supplyItemId != null) {
                        supply.markSupplyRestocked(
                            request.supplyItemId!, auth.household!.id);
                      }
                    },
                    child: const Text('Mark Bought'),
                  ),
                // Buy Anyway — manager only, urgent stuck items
                if (!isOwner &&
                    request.purchaseType == PurchaseType.managerRequest &&
                    (request.urgency == ShoppingUrgency.critical ||
                        request.urgency == ShoppingUrgency.neededToday) &&
                    request.needsApproval)
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentOrange,
                        minimumSize: const Size(0, 36)),
                    onPressed: () => _showBuyAnywayDialog(
                        context, request, supply, auth),
                    child: const Text('Buy Anyway'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showBuyAnywayDialog(BuildContext context, ShoppingRequest request,
      SupplyProvider supply, AuthProvider auth) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.flash_on_rounded,
                  color: AppColors.accentOrange, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Buy Anyway?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner has not approved "${request.itemName}" yet. '
              'You can proceed if urgent — it will be flagged for the owner.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Why is this urgent? *',
                hintText: 'e.g. Kids have no food for lunch',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              final updated = ShoppingRequest(
                id: request.id,
                householdId: request.householdId,
                supplyItemId: request.supplyItemId,
                itemName: request.itemName,
                quantity: request.quantity,
                category: request.category,
                urgency: request.urgency,
                notes: request.notes,
                status: ShoppingStatus.approved,
                purchaseType: PurchaseType.managerDirectBuy,
                buyAnywayReason: reasonCtrl.text.trim(),
                requestedByUserId: request.requestedByUserId,
                requestedByName: request.requestedByName,
                requestedAt: request.requestedAt,
                updatedAt: DateTime.now(),
              );
              supply.replaceRequest(updated, auth.household!.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Logged as direct buy — owner will see this in history'),
                  backgroundColor: AppColors.accentOrange,
                ),
              );
            },
            child: const Text('Confirm Buy',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _urgencyChip(ShoppingUrgency u) {
    switch (u) {
      case ShoppingUrgency.critical:
        return UrgencyChip(label: 'Critical', isOrange: true);
      case ShoppingUrgency.neededToday:
        return UrgencyChip(label: 'Needed Today', isOrange: true);
      case ShoppingUrgency.neededSoon:
        return UrgencyChip(label: 'Needed Soon');
    }
  }

  Widget _statusBadge(ShoppingStatus s) {
    final labels = {
      ShoppingStatus.requested: 'Requested',
      ShoppingStatus.seen: 'Seen',
      ShoppingStatus.approved: 'Approved',
      ShoppingStatus.purchased: 'Purchased',
      ShoppingStatus.deferred: 'On Hold',
    };
    final colors = {
      ShoppingStatus.requested: AppColors.statusLow,
      ShoppingStatus.seen: AppColors.statusLow,
      ShoppingStatus.approved: AppColors.statusEnough,
      ShoppingStatus.purchased: AppColors.statusEnough,
      ShoppingStatus.deferred: AppColors.surfaceLight,
    };
    final textColors = {
      ShoppingStatus.requested: AppColors.statusLowText,
      ShoppingStatus.seen: AppColors.statusLowText,
      ShoppingStatus.approved: AppColors.statusEnoughText,
      ShoppingStatus.purchased: AppColors.statusEnoughText,
      ShoppingStatus.deferred: AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: colors[s], borderRadius: BorderRadius.circular(20)),
      child: Text(labels[s]!,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColors[s])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER LIST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerListCard extends StatelessWidget {
  final ShoppingRequest request;
  const _OwnerListCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final supply = context.read<SupplyProvider>();
    final auth = context.read<AuthProvider>();

    return HomeFlowCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_bag_outlined,
                color: AppColors.primaryTeal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${request.quantity} · ${request.category}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if (request.notes != null && request.notes!.isNotEmpty)
                  Text(request.notes!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: AppColors.statusEnoughText),
                onPressed: () {
                  supply.updateRequestStatus(
                      request.id,
                      ShoppingStatus.purchased,
                      auth.household!.id);
                  if (request.supplyItemId != null) {
                    supply.markSupplyRestocked(
                        request.supplyItemId!, auth.household!.id);
                  }
                },
                child: const Text('Bought',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: AppColors.textSecondary),
                onPressed: () => supply.updateRequestStatus(
                    request.id,
                    ShoppingStatus.deferred,
                    auth.household!.id),
                child:
                    const Text('Defer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5));
}

class _SectionBanner extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionBanner(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGER REQUEST SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ManagerRequestSheet extends StatefulWidget {
  const _ManagerRequestSheet();

  @override
  State<_ManagerRequestSheet> createState() => _ManagerRequestSheetState();
}

class _ManagerRequestSheetState extends State<_ManagerRequestSheet> {
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = AppConstants.supplyCategories.first;
  ShoppingUrgency _urgency = ShoppingUrgency.neededSoon;

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request an Item',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text('Owner will review and approve',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Quantity (e.g. 2 packets)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: AppConstants.supplyCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            Text('How urgent?',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ShoppingUrgency.values.map((u) {
                final selected = _urgency == u;
                final label = u == ShoppingUrgency.neededSoon
                    ? 'Needed Soon'
                    : u == ShoppingUrgency.neededToday
                        ? 'Needed Today'
                        : 'Critical';
                return GestureDetector(
                  onTap: () => setState(() => _urgency = u),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.accentOrange
                              .withValues(alpha: 0.12)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? AppColors.accentOrange
                              : AppColors.divider),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? AppColors.accentOrange
                                : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Brand preference or reason'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_itemCtrl.text.trim().isEmpty) return;
                  const uuid = Uuid();
                  final req = ShoppingRequest(
                    id: uuid.v4(),
                    householdId: auth.household!.id,
                    itemName: _itemCtrl.text.trim(),
                    quantity: _qtyCtrl.text.trim().isEmpty
                        ? '1'
                        : _qtyCtrl.text.trim(),
                    category: _category,
                    urgency: _urgency,
                    notes: _notesCtrl.text.trim().isEmpty
                        ? null
                        : _notesCtrl.text.trim(),
                    purchaseType: PurchaseType.managerRequest,
                    requestedByUserId: auth.currentUser!.id,
                    requestedByName: auth.currentUser!.fullName,
                    requestedAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  supply.addShoppingRequest(req, auth.household!.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Request submitted — waiting for owner approval')),
                  );
                },
                child: const Text('Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER ADD SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerAddSheet extends StatefulWidget {
  const _OwnerAddSheet();

  @override
  State<_OwnerAddSheet> createState() => _OwnerAddSheetState();
}

class _OwnerAddSheetState extends State<_OwnerAddSheet> {
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = AppConstants.supplyCategories.first;

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add to My List',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text('Items you will buy personally',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Item name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _qtyCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Quantity (e.g. 2 packets)'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: AppConstants.supplyCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Preferred brand or when buying'),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal),
                onPressed: () {
                  if (_itemCtrl.text.trim().isEmpty) return;
                  const uuid = Uuid();
                  final req = ShoppingRequest(
                    id: uuid.v4(),
                    householdId: auth.household!.id,
                    itemName: _itemCtrl.text.trim(),
                    quantity: _qtyCtrl.text.trim().isEmpty
                        ? '1'
                        : _qtyCtrl.text.trim(),
                    category: _category,
                    urgency: ShoppingUrgency.neededSoon,
                    notes: _notesCtrl.text.trim().isEmpty
                        ? null
                        : _notesCtrl.text.trim(),
                    purchaseType: PurchaseType.ownerPurchase,
                    status: ShoppingStatus.approved,
                    requestedByUserId: auth.currentUser!.id,
                    requestedByName: auth.currentUser!.fullName,
                    approvedByUserId: auth.currentUser!.id,
                    requestedAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  supply.addShoppingRequest(req, auth.household!.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Added to your buy list')),
                  );
                },
                child: const Text('Add to List',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
