import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/smart_tips_engine.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Smart Tips UI — reusable tip card and section for Home Pro analytics
// ──────────────────────────────────────────────────────────────────────────────

/// A single compact tip card with coloured left border, icon, and text.
class SmartTipCard extends StatelessWidget {
  final SmartTip tip;
  final bool compact;

  const SmartTipCard({super.key, required this.tip, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tip.bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: tip.color, width: 4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 10 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tip.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(tip.icon, size: 18, color: tip.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tip.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: tip.color,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _CategoryPill(tip: tip),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 4),
                    Text(
                      tip.body,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final SmartTip tip;
  const _CategoryPill({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tip.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tip.categoryLabel,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: tip.color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Section shown inside an analytics screen with a header + list of tips.
class SmartTipsSection extends StatefulWidget {
  final List<SmartTip> tips;
  final int? maxCollapsed;   // how many tips to show before "Show more"
  final String title;

  const SmartTipsSection({
    super.key,
    required this.tips,
    this.maxCollapsed = 3,
    this.title = 'Smart Tips',
  });

  @override
  State<SmartTipsSection> createState() => _SmartTipsSectionState();
}

class _SmartTipsSectionState extends State<SmartTipsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tips.isEmpty) return const SizedBox.shrink();

    final showAll = _expanded || widget.tips.length <= (widget.maxCollapsed ?? 3);
    final visible = showAll
        ? widget.tips
        : widget.tips.take(widget.maxCollapsed!).toList();
    final hiddenCount = widget.tips.length - visible.length;

    // Count severities for header badge
    final alerts    = widget.tips.where((t) => t.severity == TipSeverity.alert).length;
    final warnings  = widget.tips.where((t) => t.severity == TipSeverity.warning).length;
    final topColor  = alerts > 0
        ? AppColors.tipAlert
        : warnings > 0 ? AppColors.tipWarning : AppColors.tipInsight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: topColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lightbulb_rounded, size: 16, color: topColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: topColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.tips.length} tip${widget.tips.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: topColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Tip cards ───────────────────────────────────────────────────────
        ...visible.map((tip) => SmartTipCard(tip: tip)),

        // ── Show more / collapse ────────────────────────────────────────────
        if (widget.tips.length > (widget.maxCollapsed ?? 3))
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded
                        ? 'Show less'
                        : 'Show $hiddenCount more tip${hiddenCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.supportBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.supportBlue,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact horizontal summary row for the dashboard — shows up to 3 tips
/// as clickable mini chips.
class SmartTipsDashboardStrip extends StatelessWidget {
  final List<SmartTip> tips;
  final VoidCallback? onViewAll;

  const SmartTipsDashboardStrip({
    super.key,
    required this.tips,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();

    final topTips = tips.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...topTips.map((tip) => _DashTipRow(tip: tip)),
        if (tips.length > 3 && onViewAll != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '+ ${tips.length - 3} more tip${tips.length - 3 == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.supportBlue,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 13, color: AppColors.supportBlue),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DashTipRow extends StatelessWidget {
  final SmartTip tip;
  const _DashTipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tip.bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: tip.color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(tip.icon, size: 15, color: tip.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tip.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _CategoryPill(tip: tip),
        ],
      ),
    );
  }
}
