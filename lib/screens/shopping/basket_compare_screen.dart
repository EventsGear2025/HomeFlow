import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/retailer_quote.dart';
import '../../models/shopping_request.dart';
import '../../models/supply_item.dart';
import '../../providers/price_compare_provider.dart';
import '../../providers/supply_provider.dart';
import '../../services/retailer_catalog_service.dart';
import '../../services/mpesa_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import 'checkout_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BASKET COMPARE SCREEN
// Shows Carrefour / Naivas / Best Mix totals and lets users pick a store
// per item, with instant total recalculation.
// ─────────────────────────────────────────────────────────────────────────────

class BasketCompareScreen extends StatefulWidget {
  const BasketCompareScreen({super.key});

  @override
  State<BasketCompareScreen> createState() => _BasketCompareScreenState();
}

class _BasketCompareScreenState extends State<BasketCompareScreen> {
  CompareMode _mode = CompareMode.bestMix;

  @override
  Widget build(BuildContext context) {
    final supply = context.watch<SupplyProvider>();
    final compare = context.watch<PriceCompareProvider>();
    final auth = context.watch<AuthProvider>();

    // Collect all current shopping items
    final requests = [
      ...supply.approvedRequests,
      if (auth.isOwner) ...supply.ownerBuyList,
    ];
    final finished = supply.finishedSupplies(isOwner: auth.isOwner);

    final allIds = [
      ...requests.map((r) => r.id),
      ...finished.map((s) => s.id),
    ];

    final summary = compare.computeBasketSummary(allIds);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Basket Compare'),
        actions: [
          // Live-price status chip
          if (compare.hasLivePrices && !compare.isRefreshingLive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Tooltip(
                  message:
                      '${compare.liveProductCount} live prices\n'
                      'Updated ${_ago(compare.livePricesUpdatedAt)}',
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Spinner while live-refresh or static-fetch is in progress
          if (compare.isLoading || compare.isRefreshingLive)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          // Refresh button — pulls live prices then re-loads quotes
          if (!compare.isLoading && !compare.isRefreshingLive)
            IconButton(
              icon: const Icon(Icons.cloud_download_rounded),
              tooltip: 'Pull live prices from Carrefour & Naivas',
              onPressed: () => compare.refreshLivePrices(
                requests: [
                  ...supply.approvedRequests,
                  if (auth.isOwner) ...supply.ownerBuyList,
                ],
                finishedSupplies: supply.finishedSupplies(isOwner: auth.isOwner),
              ),
            ),
        ],
      ),
      bottomNavigationBar:
          (allIds.isNotEmpty && compare.hasAnyQuotes && !compare.isLoading)
              ? _ProceedBar(
                  summary: summary,
                  requests: requests,
                  finished: finished,
                )
              : null,
      body: allIds.isEmpty
          ? const _EmptyBasket()
          : !compare.hasAnyQuotes && !compare.isLoading
              ? _NoPricesYet(
                  onFetch: () => compare.fetchForShoppingItems(
                    requests: requests,
                    finishedSupplies: finished,
                  ),
                )
              : _CompareBody(
                  requests: requests,
                  finished: finished,
                  allIds: allIds,
                  summary: summary,
                  mode: _mode,
                  onModeChanged: (m) {
                    setState(() => _mode = m);
                    compare.applyModeToAll(m, allIds);
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────────────────────────────────────

class _CompareBody extends StatelessWidget {
  final List<ShoppingRequest> requests;
  final List<SupplyItem> finished;
  final List<String> allIds;
  final BasketSummary summary;
  final CompareMode mode;
  final ValueChanged<CompareMode> onModeChanged;

  const _CompareBody({
    required this.requests,
    required this.finished,
    required this.allIds,
    required this.summary,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // ── Totals cards ──────────────────────────────────────────────────
        _TotalsRow(summary: summary),

        const SizedBox(height: 16),

        // ── Best Mix savings callout ───────────────────────────────────────
        if (summary.bestSavings != null && summary.bestSavings! >= 5)
          _SavingsCallout(savings: summary.bestSavings!),

        const SizedBox(height: 12),

        // ── Mode selector ────────────────────────────────────────────────
        _ModeSelector(current: mode, onChanged: onModeChanged),

        const SizedBox(height: 20),

        // ── Unmatched warning ────────────────────────────────────────────
        if (summary.unmatchedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UnmatchedBanner(count: summary.unmatchedCount),
          ),

        // ── Item list ────────────────────────────────────────────────────
        if (requests.isNotEmpty) ...[
          _SectionLabel(label: 'SHOPPING LIST (${requests.length})'),
          const SizedBox(height: 8),
          ...requests.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemAssignmentCard(
                  itemId: r.id,
                  itemName: r.itemName,
                  subtitle: r.quantity,
                ),
              )),
          const SizedBox(height: 8),
        ],

        if (finished.isNotEmpty) ...[
          _SectionLabel(label: 'FINISHED SUPPLIES (${finished.length})'),
          const SizedBox(height: 8),
          ...finished.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemAssignmentCard(
                  itemId: s.id,
                  itemName: s.name,
                  subtitle: s.category,
                ),
              )),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOTALS ROW — three cards side by side
// ─────────────────────────────────────────────────────────────────────────────

class _TotalsRow extends StatelessWidget {
  final BasketSummary summary;
  const _TotalsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cheapest = summary.cheapestSingleStore;

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _TotalCard(
              retailer: RetailerInfo.carrefour,
              total: summary.carrefourTotal,
              coverage: summary.carrefourCoverage,
              totalItems: summary.totalItems,
              isCheapest: cheapest == RetailerCode.carrefour,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _BestMixCard(summary: summary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TotalCard(
              retailer: RetailerInfo.naivas,
              total: summary.naivasTotal,
              coverage: summary.naivasCoverage,
              totalItems: summary.totalItems,
              isCheapest: cheapest == RetailerCode.naivas,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final RetailerInfo retailer;
  final double? total;
  final int coverage;
  final int totalItems;
  final bool isCheapest;

  const _TotalCard({
    required this.retailer,
    required this.total,
    required this.coverage,
    required this.totalItems,
    required this.isCheapest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCheapest
            ? retailer.brandColorLight
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCheapest
              ? retailer.brandColor.withValues(alpha: 0.5)
              : AppColors.divider,
          width: isCheapest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: retailer.brandColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  retailer.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: retailer.brandColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          total != null
              ? Text(
                  'KES ${total!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isCheapest
                        ? retailer.brandColor
                        : AppColors.textPrimary,
                  ),
                )
              : const Text('—',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(
            '$coverage/$totalItems items',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary),
          ),
          if (isCheapest) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: retailer.brandColor,
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
    );
  }
}

class _BestMixCard extends StatelessWidget {
  final BasketSummary summary;
  const _BestMixCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.bestMixTotal;
    final isBestMixCheapest = total != null &&
        (summary.carrefourTotal == null || total <= summary.carrefourTotal!) &&
        (summary.naivasTotal == null || total <= summary.naivasTotal!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBestMixCheapest
            ? const Color(0xFFE8F5E9)
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestMixCheapest
              ? const Color(0xFF43A047).withValues(alpha: 0.6)
              : AppColors.divider,
          width: isBestMixCheapest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 9, color: Color(0xFF2E7D32)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Best Mix',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          total != null
              ? Text(
                  'KES ${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                )
              : const Text('—',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textHint)),
          const SizedBox(height: 4),
          const Text(
            'Best per item',
            style:
                TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          if (isBestMixCheapest) ...[
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVINGS CALLOUT
// ─────────────────────────────────────────────────────────────────────────────

class _SavingsCallout extends StatelessWidget {
  final double savings;
  const _SavingsCallout({required this.savings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF43A047).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined,
              color: Color(0xFF2E7D32), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Buy from the best store per item and save KES ${savings.toStringAsFixed(0)} on this basket',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODE SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final CompareMode current;
  final ValueChanged<CompareMode> onChanged;

  const _ModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
          label: 'Best Mix',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF2E7D32),
          selected: current == CompareMode.bestMix,
          onTap: () => onChanged(CompareMode.bestMix),
        ),
        const SizedBox(width: 8),
        _ModeChip(
          label: 'Carrefour only',
          dot: RetailerInfo.carrefour.brandColor,
          selected: current == CompareMode.carrefourOnly,
          onTap: () => onChanged(CompareMode.carrefourOnly),
        ),
        const SizedBox(width: 8),
        _ModeChip(
          label: 'Naivas only',
          dot: RetailerInfo.naivas.brandColor,
          selected: current == CompareMode.naivasOnly,
          onTap: () => onChanged(CompareMode.naivasOnly),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? dot;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    this.icon,
    this.dot,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? dot ?? AppColors.primaryTeal;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor.withValues(alpha: 0.6)
                : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon,
                  size: 12,
                  color: selected ? activeColor : AppColors.textSecondary),
            if (dot != null)
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM ASSIGNMENT CARD — one per shopping item with Switch control
// ─────────────────────────────────────────────────────────────────────────────

class _ItemAssignmentCard extends StatelessWidget {
  final String itemId;
  final String itemName;
  final String subtitle;

  const _ItemAssignmentCard({
    required this.itemId,
    required this.itemName,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final compare = context.watch<PriceCompareProvider>();
    final result = compare.quoteFor(itemId);
    final selected = compare.selectionFor(itemId);

    if (result == null) {
      return _SkeletonAssignmentCard(itemName: itemName, subtitle: subtitle);
    }

    if (!result.hasAnyPrice) {
      return _NoMatchCard(itemId: itemId, itemName: itemName, subtitle: subtitle);
    }

    final selectedQuote = selected != null ? result.quoteFor(selected) : null;
    final otherCode = selected == RetailerCode.carrefour
        ? RetailerCode.naivas
        : RetailerCode.carrefour;
    final otherQuote = result.quoteFor(otherCode);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    if (selectedQuote?.productName != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 10, color: AppColors.primaryTeal),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [
                                selectedQuote!.productName,
                                selectedQuote.sizeLabel,
                              ].whereType<String>().join(' · '),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryTeal,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (compare.isManualSelection(itemId))
                _ManualBadge(
                  onReset: () => compare.resetToAuto(itemId),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _ProductPickerSheet(
                    itemId: itemId,
                    itemName: itemName,
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.tune_rounded,
                      size: 16, color: AppColors.textHint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Selected store pill
              Expanded(
                child: _SelectedStorePill(
                  quote: selectedQuote,
                  selected: selected,
                  result: result,
                ),
              ),
              const SizedBox(width: 10),
              // Other store price + switch button
              if (otherQuote?.hasPrice == true)
                _SwitchControl(
                  otherQuote: otherQuote!,
                  onSwitch: () => compare.setSelection(itemId, otherCode),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedStorePill extends StatelessWidget {
  final RetailerQuote? quote;
  final RetailerCode? selected;
  final ItemCompareResult result;

  const _SelectedStorePill({
    required this.quote,
    required this.selected,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (selected == null || quote == null || !quote!.hasPrice) {
      // No store selected — show cheapest unselected
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No store selected',
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      );
    }

    final info = RetailerInfo.forCode(selected!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.brandColorLight,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: info.brandColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: quote!.isLivePrice ? Colors.green.shade600 : info.brandColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${info.name} · ${quote!.fullPriceLabel}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: info.brandColor),
            ),
          ),
          if (quote!.isLivePrice) ...
            [
              const SizedBox(width: 4),
              Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SwitchControl extends StatelessWidget {
  final RetailerQuote otherQuote;
  final VoidCallback onSwitch;

  const _SwitchControl({
    required this.otherQuote,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final info = RetailerInfo.forCode(otherQuote.retailerCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${info.name} ${otherQuote.fullPriceLabel}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onSwitch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'Switch',
              style: TextStyle(
                  fontSize: 11,
                  color: info.brandColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManualBadge extends StatelessWidget {
  final VoidCallback onReset;
  const _ManualBadge({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accentYellow.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: AppColors.accentYellow.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manual',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.warningAmber,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.close_rounded,
                size: 10, color: AppColors.warningAmber),
          ],
        ),
      ),
    );
  }
}

class _SkeletonAssignmentCard extends StatelessWidget {
  final String itemName;
  final String subtitle;
  const _SkeletonAssignmentCard(
      {required this.itemName, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(
              width: 80,
              height: 14,
              child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceMuted)),
        ],
      ),
    );
  }
}

class _NoMatchCard extends StatelessWidget {
  final String itemId;
  final String itemName;
  final String subtitle;
  const _NoMatchCard(
      {required this.itemId,
      required this.itemName,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Text('Not found',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  _ProductPickerSheet(itemId: itemId, itemName: itemName),
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MISC WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _UnmatchedBanner extends StatelessWidget {
  final int count;
  const _UnmatchedBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.accentYellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.warningAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count item${count > 1 ? 's' : ''} not found in any store — '
              'totals show matched items only',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.warningAmber),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.8));
  }
}

// Returns a human-readable "X mins ago" string for the AppBar chip tooltip.
String _ago(DateTime? dt) {
  if (dt == null) return 'unknown';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _EmptyBasket extends StatelessWidget {
  const _EmptyBasket();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket_outlined,
              size: 56, color: AppColors.textHint),
          SizedBox(height: 16),
          Text('Your basket is empty',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          SizedBox(height: 8),
          Text(
            'Add items to the shopping list first',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NoPricesYet extends StatelessWidget {
  final VoidCallback onFetch;
  const _NoPricesYet({required this.onFetch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.price_check_rounded,
              size: 56, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text('Price comparison not loaded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Tap below to load Carrefour & Naivas prices',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal),
            onPressed: onFetch,
            icon: const Icon(Icons.price_check_rounded,
                color: Colors.white, size: 18),
            label: const Text('Load Prices',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT PICKER SHEET — lets user choose exact catalog product per item
// ─────────────────────────────────────────────────────────────────────────────

class _ProductPickerSheet extends StatelessWidget {
  final String itemId;
  final String itemName;

  const _ProductPickerSheet(
      {required this.itemId, required this.itemName});

  @override
  Widget build(BuildContext context) {
    final compare = context.read<PriceCompareProvider>();
    final preferredBrand = compare.quoteFor(itemId)?.preferredBrand;
    final allMatches = RetailerCatalogService.allMatchesForItem(
      itemName,
      preferredBrand: preferredBrand,
    );
    final naivasMatches = allMatches
        .where((m) => m.quote.retailerCode == RetailerCode.naivas)
        .toList();
    final carrefourMatches = allMatches
        .where((m) => m.quote.retailerCode == RetailerCode.carrefour)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Consumer<PriceCompareProvider>(
            builder: (context, cmp, child) {
              final currentNaivas =
                  cmp.quoteFor(itemId)?.quoteFor(RetailerCode.naivas);
              final currentCarrefour =
                  cmp.quoteFor(itemId)?.quoteFor(RetailerCode.carrefour);

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose product for "$itemName"',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap a product to lock it in for basket calculations',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (allMatches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No catalog matches found.\nTry editing the item name or brand on the supply.',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    if (naivasMatches.isNotEmpty) ...[
                      _PickerSectionLabel(retailer: RetailerInfo.naivas),
                      const SizedBox(height: 8),
                      ...naivasMatches.map((m) => _PickerProductRow(
                            match: m,
                            isSelected: currentNaivas?.productId ==
                                m.quote.productId,
                            onTap: () {
                              cmp.setMatchedProduct(
                                  itemId, RetailerCode.naivas, m.quote);
                              Navigator.pop(ctx);
                            },
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (carrefourMatches.isNotEmpty) ...[
                      _PickerSectionLabel(
                          retailer: RetailerInfo.carrefour),
                      const SizedBox(height: 8),
                      ...carrefourMatches.map((m) => _PickerProductRow(
                            match: m,
                            isSelected: currentCarrefour?.productId ==
                                m.quote.productId,
                            onTap: () {
                              cmp.setMatchedProduct(
                                  itemId, RetailerCode.carrefour, m.quote);
                              Navigator.pop(ctx);
                            },
                          )),
                    ],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PickerSectionLabel extends StatelessWidget {
  final RetailerInfo retailer;
  const _PickerSectionLabel({required this.retailer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: retailer.brandColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          retailer.name.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: retailer.brandColor,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _PickerProductRow extends StatelessWidget {
  final ({RetailerQuote quote, double score}) match;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerProductRow({
    required this.match,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final q = match.quote;
    final info = RetailerInfo.forCode(q.retailerCode);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? info.brandColorLight : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? info.brandColor.withValues(alpha: 0.5)
                : AppColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.productName ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (q.brand != null || q.sizeLabel != null)
                    Text(
                      [q.brand, q.sizeLabel]
                          .whereType<String>()
                          .join(' · '),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${q.price!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected ? info.brandColor : AppColors.textPrimary,
                  ),
                ),
                if (isSelected)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13, color: info.brandColor),
                      const SizedBox(width: 3),
                      Text(
                        'Selected',
                        style: TextStyle(
                            fontSize: 10,
                            color: info.brandColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
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
// PROCEED BAR — sticky bottom bar with Naivas / Carrefour totals
// ─────────────────────────────────────────────────────────────────────────────

class _ProceedBar extends StatelessWidget {
  final BasketSummary summary;
  final List<ShoppingRequest> requests;
  final List<SupplyItem> finished;

  const _ProceedBar({
    required this.summary,
    required this.requests,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    final hasNaivas = summary.naivasTotal != null;
    final hasCarrefour = summary.carrefourTotal != null;
    if (!hasNaivas && !hasCarrefour) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasNaivas)
            Expanded(
              child: _ProceedButton(
                retailer: RetailerInfo.naivas,
                total: summary.naivasTotal!,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _HandoffSheet(
                    retailerCode: RetailerCode.naivas,
                    requests: requests,
                    finished: finished,
                  ),
                ),
              ),
            ),
          if (hasNaivas && hasCarrefour) const SizedBox(width: 10),
          if (hasCarrefour)
            Expanded(
              child: _ProceedButton(
                retailer: RetailerInfo.carrefour,
                total: summary.carrefourTotal!,
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _HandoffSheet(
                    retailerCode: RetailerCode.carrefour,
                    requests: requests,
                    finished: finished,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProceedButton extends StatelessWidget {
  final RetailerInfo retailer;
  final double total;
  final VoidCallback onTap;

  const _ProceedButton({
    required this.retailer,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: retailer.brandColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                retailer.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              Text(
                'KES ${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Proceed',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 10)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded,
                      size: 11, color: Colors.white70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HANDOFF SHEET — basket grouped by one retailer + "Open [Retailer]" CTA
// ─────────────────────────────────────────────────────────────────────────────

class _HandoffSheet extends StatelessWidget {
  final RetailerCode retailerCode;
  final List<ShoppingRequest> requests;
  final List<SupplyItem> finished;

  const _HandoffSheet({
    required this.retailerCode,
    required this.requests,
    required this.finished,
  });

  @override
  Widget build(BuildContext context) {
    final compare = context.read<PriceCompareProvider>();
    final retailer = RetailerInfo.forCode(retailerCode);

    final items = <
        ({
          String name,
          String? productName,
          String? sizeLabel,
          double? price
        })>[];
    double subtotal = 0;

    for (final r in requests) {
      final q = compare.quoteFor(r.id)?.quoteFor(retailerCode);
      if (q?.price != null) subtotal += q!.price!;
      items.add((
        name: r.itemName,
        productName: q?.productName,
        sizeLabel: q?.sizeLabel,
        price: q?.price,
      ));
    }
    for (final s in finished) {
      final q = compare.quoteFor(s.id)?.quoteFor(retailerCode);
      if (q?.price != null) subtotal += q!.price!;
      items.add((
        name: s.name,
        productName: q?.productName,
        sizeLabel: q?.sizeLabel,
        price: q?.price,
      ));
    }

    final auth = context.read<AuthProvider>();
    final householdName =
        auth.household?.householdName ?? 'Your Household';
    final ownerName = auth.householdMembers
            .where((u) => u.isOwner)
            .map((u) => u.fullName)
            .firstOrNull ??
        auth.currentUser?.fullName ??
        '';
    final ownerEmail = auth.householdMembers
            .where((u) => u.isOwner)
            .map((u) => u.email)
            .firstOrNull ??
        auth.currentUser?.email ??
        '';
    final minOrder =
        retailerCode == RetailerCode.naivas ? 2000.0 : 4000.0;
    final minOrderLabel =
        retailerCode == RetailerCode.naivas ? '2,000' : '4,000';
    final serviceFee = subtotal * 0.01;
    final grandTotal = subtotal + serviceFee;
    final belowMinimum = subtotal > 0 && subtotal < minOrder;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(ctx).padding.bottom + 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: retailer.brandColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${retailer.name} basket',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${items.where((i) => i.price != null).length} of ${items.length} items matched',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      householdName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    if (ownerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ownerName,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ],
                    if (ownerEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ownerEmail,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              ...items.map((item) {
                final display = item.productName ?? item.name;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(display,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            if (item.sizeLabel != null)
                              Text(item.sizeLabel!,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          item.price != null
                              ? Text(
                                  'KES ${item.price!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))
                              : const Text('—',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textHint)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _searchItem(
                                item.productName ?? item.name, retailer),
                            child: const Icon(Icons.open_in_new_rounded,
                                size: 13, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('KES ${subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${retailer.name} delivery (est.)',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const Text('KES 150+',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Service fee (1%)',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Text('KES ${serviceFee.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('KES ${grandTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
              if (belowMinimum) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFF856404)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Minimum order for ${retailer.name} is KES $minOrderLabel. '
                          'Your basket is below the minimum — consider adding more items.',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF856404),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: retailer.brandColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          retailer: retailer,
                          subtotal: subtotal,
                          serviceFee: serviceFee,
                          grandTotal: grandTotal,
                          itemCount: items.length,
                          householdName: householdName,
                          belowMinimum: belowMinimum,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment_rounded,
                      color: Colors.white, size: 18),
                  label: const Text('Pay now',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You will receive an M-Pesa STK push to enter your PIN.',
                style: TextStyle(fontSize: 11, color: AppColors.textHint),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _searchItem(String name, RetailerInfo retailer) {
    final query = Uri.encodeQueryComponent(name.toLowerCase());
    final url = retailer.code == RetailerCode.naivas
        ? 'https://www.naivas.co.ke/search?q=$query'
        : 'https://www.carrefour.ke/search?q=$query';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// M-PESA STK PUSH PAYMENT SHEET
// ─────────────────────────────────────────────────────────────────────────────

enum _PayState { idle, loading, success, error }

class _MpesaPaySheet extends StatefulWidget {
  const _MpesaPaySheet({required this.retailer, required this.amount});

  final RetailerInfo retailer;
  final double amount;

  @override
  State<_MpesaPaySheet> createState() => _MpesaPaySheetState();
}

class _MpesaPaySheetState extends State<_MpesaPaySheet> {
  final _phoneCtrl = TextEditingController();
  _PayState _state = _PayState.idle;
  String? _errorMsg;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMsg = 'Enter your M-Pesa phone number');
      return;
    }
    setState(() {
      _state = _PayState.loading;
      _errorMsg = null;
    });

    final result = await MpesaService.stkPush(
      phone: phone,
      amount: widget.amount,
    );

    if (!mounted) return;
    if (result.success) {
      setState(() => _state = _PayState.success);
    } else {
      setState(() {
        _state = _PayState.error;
        _errorMsg = result.errorMessage;
      });
    }
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
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            if (_state == _PayState.success) ...[
              const Center(
                child: Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 56),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'STK Push Sent!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Check your phone — enter your M-Pesa PIN to complete the payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: widget.retailer.brandColor,
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pay via M-Pesa — ${widget.retailer.name}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'KES ${widget.amount.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.retailer.brandColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'M-Pesa phone number',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '07XXXXXXXX or 254XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_android_rounded,
                      size: 18),
                  errorText: _errorMsg,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.divider),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.retailer.brandColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed:
                      _state == _PayState.loading ? null : _pay,
                  child: _state == _PayState.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send M-Pesa request',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
              if (_state == _PayState.error && _errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMsg!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.accentOrange),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
