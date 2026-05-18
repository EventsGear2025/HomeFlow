import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/retailer_quote.dart';
import '../../models/shopping_request.dart';
import '../../models/supply_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/price_compare_provider.dart';
import '../../providers/supply_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_chips.dart';
import 'basket_compare_screen.dart';
import '../../services/retailer_catalog_service.dart';
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
  String _compareSyncKey = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PriceCompareProvider>().loadCachedLiveTimestamp();
    });
  }

  void _syncComparePrices({
    required List<ShoppingRequest> requests,
    required List<SupplyItem> finished,
  }) {
    final signatures = [
      ...requests.map((r) => 'r:${r.id}:${r.itemName}'),
      ...finished.map((s) => 's:${s.id}:${s.name}:${s.preferredBrand ?? ''}'),
    ]..sort();

    final nextKey = signatures.join('|');
    if (nextKey == _compareSyncKey) return;
    _compareSyncKey = nextKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PriceCompareProvider>().fetchForShoppingItems(
        requests: requests,
        finishedSupplies: finished,
      );
    });
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

    final finished = supply.finishedSupplies(isOwner: isOwner);
    final pending = supply.pendingRequests;
    final approved = supply.approvedRequests;
    final ownerList = supply.ownerBuyList;
    final deferred = supply.deferredRequests;
    final history = supply.historyRequests;
    final directBuys = supply.unacknowledgedDirectBuys;
    final compareRequests = [
      ...approved,
      if (isOwner) ...ownerList,
    ];

    _syncComparePrices(
      requests: compareRequests,
      finished: finished,
    );

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'shopping_compare_fab',
          backgroundColor: const Color(0xFF2E7D32),
          mini: true,
          tooltip: 'Compare basket prices',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const BasketCompareScreen()),
          ),
          child: const Icon(Icons.price_check_rounded,
              color: Colors.white, size: 20),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
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
        ),
      ],
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

    final compareRequestIds = [
      ...approved.map((r) => r.id),
      if (isOwner) ...ownerList.map((r) => r.id),
    ];
    final allIds = [
      ...compareRequestIds,
      ...finished.map((s) => s.id),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Price comparison banner
        _CompareBasketBanner(itemIds: allIds),
        const SizedBox(height: 12),

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
                child: _DismissibleRequest(
                    key: ValueKey('direct_${r.id}'),
                    request: r,
                    child: _RequestCard(request: r, isOwner: isOwner)),
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
                child: _DismissibleRequest(
                    key: ValueKey('approved_${r.id}'),
                    request: r,
                    child: _RequestCard(request: r, isOwner: isOwner)),
              )),
          const SizedBox(height: 8),
        ],

        // Owner's personal buy list — private, not visible to manager
        if (isOwner && ownerList.isNotEmpty) ...[
          const _SectionLabel(label: 'MY LIST'),
          const SizedBox(height: 8),
          ...ownerList.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DismissibleRequest(
                    key: ValueKey('owner_${r.id}'),
                    request: r,
                    child: _OwnerListCard(request: r)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    onPressed: () => _showMarkBoughtSheet(context, supply, auth),
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
          const SizedBox(height: 8),
          _RetailerPriceChips(
            itemId: item.id,
            onTap: () => _showPriceDetail(context, item.id, item.name),
          ),
        ],
      ),
    );
  }

  void _showPriceDetail(
      BuildContext context, String itemId, String itemName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _ItemPriceDetailSheet(itemId: itemId, itemName: itemName),
    );
  }

  void _showMarkBoughtSheet(
    BuildContext context,
    SupplyProvider supply,
    AuthProvider auth,
  ) {
    _showQuickBoughtEntrySheet(
      context: context,
      itemName: item.name,
      detailLabel: '${item.category} · ${item.unitType}',
      onDone: (price) async {
        supply.markSupplyRestocked(item.id, auth.household!.id);
      },
      successMessage: '${item.name} marked as bought',
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
              child: _DismissibleRequest(
                  key: ValueKey('pending_${r.id}'),
                  request: r,
                  child: _RequestCard(request: r, isOwner: isOwner)),
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
    final missingPriceItems = items.where((item) => item.pricePaid == null).toList();

    if (items.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No history yet',
        subtitle: 'Purchased items will appear here',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (missingPriceItems.isNotEmpty) ...[
          _HistoryPriceReminderBanner(items: missingPriceItems),
          const SizedBox(height: 14),
        ],
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RequestCard(
                request: item,
                isOwner: false,
                isHistory: true,
              ),
            )),
      ],
    );
  }
}

class _HistoryPriceReminderBanner extends StatelessWidget {
  final List<ShoppingRequest> items;

  const _HistoryPriceReminderBanner({required this.items});

  @override
  Widget build(BuildContext context) {
    final preview = items.take(3).map((item) => item.itemName).toList();
    final count = items.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tipAlertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tipAlert.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tipAlert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 16,
                  color: AppColors.tipAlert,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 purchased item still needs a price'
                          : '$count purchased items still need prices',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use the Add price buttons below to keep your spend history and Home Pro analytics accurate.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in preview)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.tipAlert.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                if (items.length > preview.length)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.tipAlert.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      '+${items.length - preview.length} more',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showQuickBoughtEntrySheet({
  required BuildContext context,
  required String itemName,
  required String detailLabel,
  required Future<void> Function(double? price) onDone,
  required String successMessage,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _QuickBoughtEntrySheet(
      itemName: itemName,
      detailLabel: detailLabel,
      onDone: (price) async {
        await onDone(price);
        if (!sheetContext.mounted) return;
        Navigator.pop(sheetContext);
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
      },
    ),
  );
}

class _QuickBoughtEntrySheet extends StatefulWidget {
  final String itemName;
  final String detailLabel;
  final Future<void> Function(double? price) onDone;

  const _QuickBoughtEntrySheet({
    required this.itemName,
    required this.detailLabel,
    required this.onDone,
  });

  @override
  State<_QuickBoughtEntrySheet> createState() => _QuickBoughtEntrySheetState();
}

class _QuickBoughtEntrySheetState extends State<_QuickBoughtEntrySheet> {
  late final TextEditingController _priceCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final rawValue = _priceCtrl.text.trim().replaceAll(',', '');
    final parsed = rawValue.isEmpty ? null : double.tryParse(rawValue);

    if (rawValue.isNotEmpty && (parsed == null || parsed <= 0)) {
      messenger.showSnackBar(
        SnackBar(content: Text('Enter a valid amount for ${widget.itemName}.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onDone(parsed);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.statusEnough.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.statusEnoughText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mark as bought',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.itemName} • ${widget.detailLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
            ),
            child: const Text(
              'If you know the amount, enter it now. Home Pro gives better shopping and spend analytics when bought items have prices logged.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _priceCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Amount paid (KES)',
              hintText: 'e.g. 350',
              prefixText: 'KES ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: const Text('Skip price'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Done',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISMISSIBLE WRAPPER — swipe-left to delete any shopping request
// ─────────────────────────────────────────────────────────────────────────────

class _DismissibleRequest extends StatelessWidget {
  final ShoppingRequest request;
  final Widget child;

  const _DismissibleRequest({
    required super.key,
    required this.request,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final supply = context.read<SupplyProvider>();
    final auth = context.read<AuthProvider>();

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        // Briefly show undo option before committing delete
        bool confirmed = true;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${request.itemName}" removed'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () => confirmed = false,
              ),
            ),
          );
        // Wait for snackbar so user can undo
        await Future.delayed(const Duration(seconds: 4));
        return confirmed;
      },
      onDismissed: (_) {
        supply.deleteShoppingRequest(request.id, auth.household!.id);
      },
      child: child,
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
              if (!isHistory)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textHint,
                  tooltip: 'Edit item',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => _showEditSheet(context, request, supply, auth),
                ),
              const SizedBox(width: 4),
              _urgencyChip(request.urgency),
            ],
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.notes!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (isHistory && request.pricePaid != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 14, color: AppColors.statusEnoughText),
                const SizedBox(width: 4),
                Text(
                  'Paid: KES ${request.pricePaid!.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusEnoughText,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          // Buy Anyway banner
          if (isHistory && request.pricePaid == null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.tipAlertBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.tipAlert.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: AppColors.tipAlert,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Price not logged yet',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tipAlert,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: AppColors.tipAlert,
                    ),
                    onPressed: () => _showLogPriceDialog(context, request, supply),
                    child: const Text('Add price'),
                  ),
                ],
              ),
            ),
          ],
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
                    onPressed: () => _showMarkBoughtDialog(
                        context, request, supply, auth),
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
          if (!isHistory) ...[
            const SizedBox(height: 8),
            _RetailerPriceChips(
              itemId: request.id,
              onTap: () => _showPriceDetail(context, request.id, request.itemName),
            ),
          ],
        ],
      ),
    );
  }

  void _showPriceDetail(
      BuildContext context, String itemId, String itemName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _ItemPriceDetailSheet(itemId: itemId, itemName: itemName),
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

  void _showMarkBoughtDialog(BuildContext context, ShoppingRequest request,
      SupplyProvider supply, AuthProvider auth) {
    _showQuickBoughtEntrySheet(
      context: context,
      itemName: request.itemName,
      detailLabel: request.quantity,
      onDone: (price) async {
        await supply.replaceRequest(
          request.copyWith(
            status: ShoppingStatus.purchased,
            pricePaid: price,
          ),
          auth.household!.id,
        );
        if (request.supplyItemId != null) {
          await supply.markSupplyRestocked(
            request.supplyItemId!,
            auth.household!.id,
          );
        }
      },
      successMessage: '${request.itemName} marked as bought',
    );
  }

  void _showEditSheet(BuildContext context, ShoppingRequest request,
      SupplyProvider supply, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditRequestSheet(
        request: request,
        onSave: (updated) =>
            supply.replaceRequest(updated, auth.household!.id),
      ),
    );
  }

  void _showLogPriceDialog(
    BuildContext context,
    ShoppingRequest request,
    SupplyProvider supply,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.tipAlertBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.tipAlert,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Log price'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add the amount paid for "${request.itemName}" to keep your shopping history accurate.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: priceCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price paid (KES)',
                hintText: 'e.g. 350',
                prefixText: 'KES ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tipAlert,
            ),
            onPressed: () {
              final price = double.tryParse(priceCtrl.text.trim().replaceAll(',', ''));
              if (price == null || price <= 0) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Enter a valid price for ${request.itemName}.')),
                );
                return;
              }

              Navigator.pop(ctx);
              supply.replaceRequest(
                request.copyWith(pricePaid: price),
                request.householdId,
              );
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Saved price for ${request.itemName}.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).whenComplete(priceCtrl.dispose);
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
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textHint,
            tooltip: 'Edit',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _EditRequestSheet(
                request: request,
                onSave: (updated) =>
                    supply.replaceRequest(updated, auth.household!.id),
              ),
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
                onPressed: () => _showMarkBoughtDialog(context, supply, auth),
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

  void _showMarkBoughtDialog(
      BuildContext context, SupplyProvider supply, AuthProvider auth) {
    _showQuickBoughtEntrySheet(
      context: context,
      itemName: request.itemName,
      detailLabel: request.quantity,
      onDone: (price) async {
        await supply.replaceRequest(
          request.copyWith(
            status: ShoppingStatus.purchased,
            pricePaid: price,
          ),
          auth.household!.id,
        );
        if (request.supplyItemId != null) {
          await supply.markSupplyRestocked(
            request.supplyItemId!,
            auth.household!.id,
          );
        }
      },
      successMessage: '${request.itemName} marked as bought',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT REQUEST SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _EditRequestSheet extends StatefulWidget {
  final ShoppingRequest request;
  final void Function(ShoppingRequest updated) onSave;

  const _EditRequestSheet({required this.request, required this.onSave});

  @override
  State<_EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends State<_EditRequestSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.request.itemName);
    _qtyCtrl = TextEditingController(text: widget.request.quantity);
    _notesCtrl = TextEditingController(text: widget.request.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Edit Item',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Item name *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Quantity *',
                hintText: 'e.g. 2 litres, 1 pack',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Brand preference, extra details…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      final qty = _qtyCtrl.text.trim();
                      if (name.isEmpty || qty.isEmpty) return;
                      widget.onSave(widget.request.copyWith(
                        itemName: name,
                        quantity: qty,
                        notes: _notesCtrl.text.trim().isEmpty
                            ? null
                            : _notesCtrl.text.trim(),
                      ));
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
  List<Map<String, dynamic>> _itemSuggestions = [];
  List<({String productName, String? brand, String? sizeLabel})> _catalogSuggestions = [];
  String? _catalogProductName;
  String? _catalogBrand;
  String? _catalogSizeLabel;

  void _onItemChanged(String val) {
    final q = val.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() {
        _itemSuggestions = [];
        _catalogSuggestions = [];
      });
      return;
    }
    final starter = AppConstants.starterSupplies
        .where((item) =>
            (item['name'] as String).toLowerCase().contains(q) ||
            (item['category'] as String).toLowerCase().contains(q))
        .take(8)
        .toList();
    final catalog = <({String productName, String? brand, String? sizeLabel})>[];
    if (q.length >= 3) {
      final seen = <String>{};
      for (final m in RetailerCatalogService.allMatchesForItem(val)) {
        final name = m.quote.productName ?? '';
        if (name.isNotEmpty && seen.add(name) && catalog.length < 3) {
          catalog.add((
            productName: name,
            brand: m.quote.brand,
            sizeLabel: m.quote.sizeLabel,
          ));
        }
      }
    }
    setState(() {
      _itemSuggestions = starter;
      _catalogSuggestions = catalog;
    });
  }

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
              decoration: InputDecoration(
                labelText: 'Item name',
                hintText: 'Start typing to see suggestions…',
                suffixIcon: _itemCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear',
                        onPressed: () {
                          _itemCtrl.clear();
                          setState(() {
                            _itemSuggestions = [];
                            _catalogSuggestions = [];
                          });
                        },
                      )
                    : null,
              ),
              autofocus: true,
              onChanged: _onItemChanged,
            ),
            if (_itemSuggestions.isNotEmpty) ..._buildSuggestionChips(
              _itemSuggestions,
              onSelect: (s) {
                _itemCtrl.text = s['name'] as String;
                _itemCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _itemCtrl.text.length));
                final cat = s['category'] as String;
                setState(() {
                  _itemSuggestions = [];
                  _catalogSuggestions = [];
                  _catalogProductName = null;
                  _catalogBrand = null;
                  _catalogSizeLabel = null;
                  if (AppConstants.supplyCategories.contains(cat)) {
                    _category = cat;
                  }
                });
              },
            ),
            if (_catalogSuggestions.isNotEmpty) ..._buildCatalogChips(
              _catalogSuggestions,
              onSelect: (c) {
                _itemCtrl.text = c.productName;
                _itemCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _itemCtrl.text.length));
                setState(() {
                  _itemSuggestions = [];
                  _catalogSuggestions = [];
                  _catalogProductName = c.productName;
                  _catalogBrand = c.brand;
                  _catalogSizeLabel = c.sizeLabel;
                });
              },
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
                    catalogProductName: _catalogProductName,
                    catalogBrand: _catalogBrand,
                    catalogSizeLabel: _catalogSizeLabel,
                  );

                  void doSubmit() {
                    supply.addShoppingRequest(req, auth.household!.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Request submitted — waiting for owner approval')),
                    );
                  }

                  if (DateTime.now().hour >= 16) {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        title: Row(
                          children: [
                            Icon(Icons.schedule_outlined,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text('Past 4:00 PM'),
                          ],
                        ),
                        content: const Text(
                          'Supply requests should be logged before 4:00 PM to allow enough time to buy before dusk.\n\nDo you still want to submit this request?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Submit Anyway'),
                          ),
                        ],
                      ),
                    ).then((confirmed) {
                      if (confirmed == true) doSubmit();
                    });
                  } else {
                    doSubmit();
                  }
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
  List<Map<String, dynamic>> _itemSuggestions = [];
  List<({String productName, String? brand, String? sizeLabel})> _catalogSuggestions = [];
  String? _catalogProductName;
  String? _catalogBrand;
  String? _catalogSizeLabel;

  void _onItemChanged(String val) {
    final q = val.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() {
        _itemSuggestions = [];
        _catalogSuggestions = [];
      });
      return;
    }
    final starter = AppConstants.starterSupplies
        .where((item) =>
            (item['name'] as String).toLowerCase().contains(q) ||
            (item['category'] as String).toLowerCase().contains(q))
        .take(8)
        .toList();
    final catalog = <({String productName, String? brand, String? sizeLabel})>[];
    if (q.length >= 3) {
      final seen = <String>{};
      for (final m in RetailerCatalogService.allMatchesForItem(val)) {
        final name = m.quote.productName ?? '';
        if (name.isNotEmpty && seen.add(name) && catalog.length < 3) {
          catalog.add((
            productName: name,
            brand: m.quote.brand,
            sizeLabel: m.quote.sizeLabel,
          ));
        }
      }
    }
    setState(() {
      _itemSuggestions = starter;
      _catalogSuggestions = catalog;
    });
  }

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
              decoration: InputDecoration(
                labelText: 'Item name',
                hintText: 'Start typing to see suggestions…',
                suffixIcon: _itemCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear',
                        onPressed: () {
                          _itemCtrl.clear();
                          setState(() {
                            _itemSuggestions = [];
                            _catalogSuggestions = [];
                          });
                        },
                      )
                    : null,
              ),
              autofocus: true,
              onChanged: _onItemChanged,
            ),
            if (_itemSuggestions.isNotEmpty) ..._buildSuggestionChips(
              _itemSuggestions,
              onSelect: (s) {
                _itemCtrl.text = s['name'] as String;
                _itemCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _itemCtrl.text.length));
                final cat = s['category'] as String;
                setState(() {
                  _itemSuggestions = [];
                  _catalogSuggestions = [];
                  _catalogProductName = null;
                  _catalogBrand = null;
                  _catalogSizeLabel = null;
                  if (AppConstants.supplyCategories.contains(cat)) {
                    _category = cat;
                  }
                });
              },
            ),
            if (_catalogSuggestions.isNotEmpty) ..._buildCatalogChips(
              _catalogSuggestions,
              onSelect: (c) {
                _itemCtrl.text = c.productName;
                _itemCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _itemCtrl.text.length));
                setState(() {
                  _itemSuggestions = [];
                  _catalogSuggestions = [];
                  _catalogProductName = c.productName;
                  _catalogBrand = c.brand;
                  _catalogSizeLabel = c.sizeLabel;
                });
              },
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
                    catalogProductName: _catalogProductName,
                    catalogBrand: _catalogBrand,
                    catalogSizeLabel: _catalogSizeLabel,
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

// ─────────────────────────────────────────────────────────────────────────────
// SUGGESTION CHIPS HELPER
// Shared by _ManagerRequestSheet and _OwnerAddSheet.
// Returns a list of widgets: a spacing gap + a horizontally-scrolling row of
// tappable chips driven by AppConstants.starterSupplies.
// ─────────────────────────────────────────────────────────────────────────────

List<Widget> _buildSuggestionChips(
  List<Map<String, dynamic>> suggestions, {
  required void Function(Map<String, dynamic>) onSelect,
}) {
  return [
    const SizedBox(height: 8),
    SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = suggestions[i];
          return GestureDetector(
            onTap: () => onSelect(s),
            child: Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AppColors.primaryTeal.withValues(alpha: 0.35)),
              ),
              child: Text(
                s['name'] as String,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w500),
              ),
            ),
          );
        },
      ),
    ),
    const SizedBox(height: 4),
  ];
}

List<Widget> _buildCatalogChips(
  List<({String productName, String? brand, String? sizeLabel})> suggestions, {
  required void Function(({String productName, String? brand, String? sizeLabel})) onSelect,
}) {
  return [
    const SizedBox(height: 6),
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.storefront_rounded,
            size: 12, color: AppColors.primaryTeal),
        const SizedBox(width: 4),
        const Text(
          'PRODUCTS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTeal,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
    const SizedBox(height: 4),
    SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = suggestions[i];
          final sub = [s.brand, s.sizeLabel].whereType<String>().join(' · ');
          return GestureDetector(
            onTap: () => onSelect(s),
            child: Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primaryTeal.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.productName,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w600),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    const SizedBox(height: 4),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPARE BASKET BANNER — shown at top of Buy Now tab
// ─────────────────────────────────────────────────────────────────────────────

class _CompareBasketBanner extends StatelessWidget {
  final List<String> itemIds;
  const _CompareBasketBanner({required this.itemIds});

  @override
  Widget build(BuildContext context) {
    final compare = context.watch<PriceCompareProvider>();
    final summary = compare.computeBasketSummary(itemIds);

    if (itemIds.isEmpty) return const SizedBox.shrink();

    final loading = compare.isLoading;
    final hasPrices = compare.hasAnyQuotes;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BasketCompareScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.price_check_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: loading
                  ? const Text('Loading prices…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500))
                  : hasPrices && summary.bestSavings != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Save up to KES ${summary.bestSavings!.toStringAsFixed(0)} on this basket',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const Text(
                              'Tap to compare Carrefour & Naivas prices',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        )
                      : const Text(
                          'Compare prices — Carrefour & Naivas',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RETAILER PRICE CHIPS — compact chips shown on each item card
// ─────────────────────────────────────────────────────────────────────────────

class _RetailerPriceChips extends StatelessWidget {
  final String itemId;
  final VoidCallback? onTap;
  const _RetailerPriceChips({required this.itemId, this.onTap});

  @override
  Widget build(BuildContext context) {
    final compare = context.watch<PriceCompareProvider>();

    if (compare.isLoading && !compare.hasAnyQuotes) {
      return Row(
        children: [
          _shimmerChip(),
          const SizedBox(width: 6),
          _shimmerChip(),
        ],
      );
    }

    final result = compare.quoteFor(itemId);
    if (result == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: RetailerCode.values.map((code) {
          final quote = result.quoteFor(code);
          if (quote == null) return const SizedBox.shrink();
          final info = RetailerInfo.forCode(code);
          final isCheapest = result.cheapestRetailer == code;
          return _PriceChip(
              quote: quote, info: info, isCheapest: isCheapest);
        }).toList(),
      ),
    );
  }

  Widget _shimmerChip() {
    return Container(
      width: 90,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final RetailerQuote quote;
  final RetailerInfo info;
  final bool isCheapest;

  const _PriceChip({
    required this.quote,
    required this.info,
    required this.isCheapest,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = quote.hasPrice;
    final color = hasPrice ? info.brandColor : AppColors.textHint;
    final bg = hasPrice ? info.brandColorLight : AppColors.surfaceLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '${info.name} ${quote.shortPriceLabel}',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight:
                  isCheapest ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (isCheapest && hasPrice) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_downward_rounded,
                size: 9, color: Color(0xFF2E7D32)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM PRICE DETAIL SHEET — shown when tapping a chip
// ─────────────────────────────────────────────────────────────────────────────

class _ItemPriceDetailSheet extends StatelessWidget {
  final String itemId;
  final String itemName;

  const _ItemPriceDetailSheet({
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context) {
    final compare = context.watch<PriceCompareProvider>();
    final result = compare.quoteFor(itemId);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(itemName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Price comparison across stores',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),

              const SizedBox(height: 20),

              if (result == null || !result.hasAnyPrice)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No prices found for this item.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else ...[
                // Retailer rows
                ...RetailerCode.values.map((code) {
                  final quote = result.quoteFor(code);
                  if (quote == null) return const SizedBox.shrink();
                  final info = RetailerInfo.forCode(code);
                  final isCheapest = result.cheapestRetailer == code;
                  return _DetailQuoteRow(
                    quote: quote,
                    info: info,
                    isCheapest: isCheapest,
                  );
                }),

                const SizedBox(height: 16),

                // Recommendation
                if (result.cheapestRetailer != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: Color(0xFF2E7D32), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cheapest option: ${RetailerInfo.forCode(result.cheapestRetailer!).name} '
                            'at KES ${result.lowestPrice!.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1B5E20),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action: Go to compare screen
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const BasketCompareScreen()));
                    },
                    icon: const Icon(Icons.shopping_basket_outlined,
                        size: 16),
                    label: const Text('View full basket comparison'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailQuoteRow extends StatelessWidget {
  final RetailerQuote quote;
  final RetailerInfo info;
  final bool isCheapest;

  const _DetailQuoteRow({
    required this.quote,
    required this.info,
    required this.isCheapest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCheapest ? info.brandColorLight : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCheapest
              ? info.brandColor.withValues(alpha: 0.4)
              : AppColors.divider,
          width: isCheapest ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Retailer dot + name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: info.brandColor,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(info.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: info.brandColor)),
                ],
              ),
              if (quote.productName != null) ...[
                const SizedBox(height: 4),
                Text(quote.productName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
              if (quote.brand != null || quote.sizeLabel != null)
                Text(
                  [quote.brand, quote.sizeLabel]
                      .whereType<String>()
                      .join(' · '),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              const SizedBox(height: 4),
              _MatchBadge(matchType: quote.matchType),
            ],
          ),
          const Spacer(),
          // Price + cheapest tag
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote.fullPriceLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isCheapest ? info.brandColor : AppColors.textPrimary,
                ),
              ),
              if (isCheapest) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('CHEAPEST',
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchBadge extends StatelessWidget {
  final MatchType matchType;
  const _MatchBadge({required this.matchType});

  @override
  Widget build(BuildContext context) {
    if (matchType == MatchType.exact) return const SizedBox.shrink();
    final (label, color) = switch (matchType) {
      MatchType.nearMatch => ('Similar size', AppColors.warningAmber),
      MatchType.categoryAlternative =>
        ('Alternative brand', AppColors.uiBlue),
      MatchType.notFound => ('Not found', AppColors.textHint),
      MatchType.exact => ('', Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500)),
    );
  }
}
