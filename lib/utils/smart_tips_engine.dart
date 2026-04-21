import 'package:flutter/material.dart';
import '../models/meal_log.dart';
import '../models/laundry_item.dart';
import '../models/supply_item.dart';
import '../models/utility_tracker.dart';
import 'app_colors.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Smart Tips Engine — homeFlow Home Pro analytics intelligence layer
// Analyses household data and produces actionable, personalised tips.
// ──────────────────────────────────────────────────────────────────────────────

enum TipCategory { nutrition, laundry, supplies, utilities }

enum TipSeverity {
  insight,    // teal  — positive observation / fun fact
  suggestion, // blue  — easy improvement
  warning,    // amber — moderate concern
  alert,      // red   — needs attention now
}

class SmartTip {
  final String id;
  final TipCategory category;
  final TipSeverity severity;
  final IconData icon;
  final String title;
  final String body;

  const SmartTip({
    required this.id,
    required this.category,
    required this.severity,
    required this.icon,
    required this.title,
    required this.body,
  });

  Color get color {
    switch (severity) {
      case TipSeverity.insight:    return AppColors.tipInsight;
      case TipSeverity.suggestion: return AppColors.tipSuggestion;
      case TipSeverity.warning:    return AppColors.tipWarning;
      case TipSeverity.alert:      return AppColors.tipAlert;
    }
  }

  Color get bgColor {
    switch (severity) {
      case TipSeverity.insight:    return AppColors.tipInsightBg;
      case TipSeverity.suggestion: return AppColors.tipSuggestionBg;
      case TipSeverity.warning:    return AppColors.tipWarningBg;
      case TipSeverity.alert:      return AppColors.tipAlertBg;
    }
  }

  String get categoryLabel {
    switch (category) {
      case TipCategory.nutrition:  return 'Nutrition';
      case TipCategory.laundry:    return 'Laundry';
      case TipCategory.supplies:   return 'Supplies';
      case TipCategory.utilities:  return 'Utilities';
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class SmartTipsEngine {

  // ── NUTRITION TIPS ──────────────────────────────────────────────────────────

  static List<SmartTip> analyzeMeals(List<MealLog> logs) {
    if (logs.isEmpty) return [];

    final tips = <SmartTip>[];
    final now = DateTime.now();

    // Last-30-day window
    final last30 = logs
        .where((l) => now.difference(l.date).inDays <= 30)
        .toList();

    // Last-7-day window
    final last7 = logs
        .where((l) => now.difference(l.date).inDays <= 7)
        .toList();

    if (last30.isEmpty) return [];

    // ── Count nutritionTag occurrences ──────────────────────────────────────
    int carbCount = 0, proteinCount = 0, vegCount = 0,
        fruitCount = 0, dairyCount = 0, hydrationCount = 0;

    for (final log in last30) {
      final tags = log.nutritionTags;
      if (tags.contains('Carbs'))      carbCount++;
      if (tags.contains('Protein'))    proteinCount++;
      if (tags.contains('Vegetables')) vegCount++;
      if (tags.contains('Fruit'))      fruitCount++;
      if (tags.contains('Dairy'))      dairyCount++;
      if (tags.contains('Hydration'))  hydrationCount++;
    }

    final total = last30.length;
    final carbPct    = (carbCount    / total * 100).round();
    final proteinPct = (proteinCount / total * 100).round();
    final vegPct     = (vegCount     / total * 100).round();
    final fruitPct   = (fruitCount   / total * 100).round();

    // Too many carbs
    if (carbPct >= 70) {
      tips.add(SmartTip(
        id: 'carbs_high',
        category: TipCategory.nutrition,
        severity: TipSeverity.warning,
        icon: Icons.grain_rounded,
        title: 'High Carb Frequency — $carbPct% of Meals',
        body: 'In the last 30 days, $carbPct% of logged meals were carb-heavy. '
              'Try swapping 3–4 carb days per week with protein-rich meals like '
              'chicken stew, fish, eggs or beans for better energy and balance.',
      ));
    } else if (carbPct >= 55) {
      tips.add(SmartTip(
        id: 'carbs_moderate',
        category: TipCategory.nutrition,
        severity: TipSeverity.suggestion,
        icon: Icons.grain_rounded,
        title: 'Carb-Heavy Week — Diversify a Bit',
        body: 'About $carbPct% of recent meals have been carb-based. '
              'Consider adding 2 extra protein or vegetable days per week '
              'to keep the household\'s diet better balanced.',
      ));
    }

    // Low protein
    if (proteinPct < 25 && total >= 7) {
      tips.add(SmartTip(
        id: 'protein_low',
        category: TipCategory.nutrition,
        severity: TipSeverity.warning,
        icon: Icons.egg_rounded,
        title: 'Low Protein Intake — $proteinPct% of Meals',
        body: 'Only $proteinPct% of meals in the last 30 days included a '
              'protein source. Add eggs, beans, fish, chicken or lentils at '
              'least once a day to support energy levels and growth — '
              'especially important for children.',
      ));
    }

    // Low vegetables (last 7 days)
    if (vegPct < 20 && last7.isNotEmpty) {
      final vegLast7 = last7.where((l) => l.nutritionTags.contains('Vegetables')).length;
      if (vegLast7 < 3) {
        tips.add(SmartTip(
          id: 'veggies_low',
          category: TipCategory.nutrition,
          severity: TipSeverity.suggestion,
          icon: Icons.eco_rounded,
          title: 'Very Few Vegetables This Week',
          body: 'Only $vegLast7 meals this week had vegetables. '
                'Sukuma wiki, spinach, and cabbage are easy, affordable additions '
                'with high nutritional value — try to reach at least 5 veggie meals per week.',
        ));
      }
    }

    // No fruit all week
    final fruitLast7 = last7.where((l) => l.nutritionTags.contains('Fruit')).length;
    if (fruitLast7 == 0 && last7.length >= 5) {
      tips.add(SmartTip(
        id: 'fruit_absent',
        category: TipCategory.nutrition,
        severity: TipSeverity.suggestion,
        icon: Icons.apple_rounded,
        title: 'No Fruits Logged This Week',
        body: 'Fruits are a great source of vitamins and natural sugars. '
              'Even a banana, mango or orange as a daily snack makes a difference. '
              'Try adding fruit to at least 3 days a week.',
      ));
    }

    // Good balance — positive insight
    if (carbPct < 60 && proteinPct >= 30 && vegPct >= 25) {
      tips.add(SmartTip(
        id: 'diet_balanced',
        category: TipCategory.nutrition,
        severity: TipSeverity.insight,
        icon: Icons.thumb_up_rounded,
        title: 'Well-Balanced Diet This Month',
        body: 'Great job! The household\'s meals are balanced — '
              '$proteinPct% protein, $vegPct% vegetables, $carbPct% carbs. '
              'Keep this pattern going for sustained energy and health.',
      ));
    }

    // Check breakfast skipping (last 7 days)
    final daysWithBreakfast = <String>{};
    for (final log in last7) {
      if (log.mealPeriod.toLowerCase().contains('breakfast') ||
          log.mealPeriod.toLowerCase().contains('morning')) {
        daysWithBreakfast.add(log.date.toIso8601String().substring(0, 10));
      }
    }
    final uniqueDays7 = last7.map((l) => l.date.toIso8601String().substring(0, 10)).toSet().length;
    if (uniqueDays7 >= 5 && daysWithBreakfast.length < (uniqueDays7 / 2).ceil()) {
      tips.add(SmartTip(
        id: 'breakfast_skipped',
        category: TipCategory.nutrition,
        severity: TipSeverity.suggestion,
        icon: Icons.wb_sunny_rounded,
        title: 'Breakfast Often Skipped',
        body: 'Breakfast was only logged on ${daysWithBreakfast.length} out of '
              '$uniqueDays7 tracked days this week. Starting the day with even '
              'a light meal — tea, fruit or porridge — improves focus and energy.',
      ));
    }

    return tips;
  }

  // ── LAUNDRY TIPS ────────────────────────────────────────────────────────────

  static List<SmartTip> analyzeLaundry(List<LaundryItem> allItems) {
    if (allItems.isEmpty) return [];

    final tips = <SmartTip>[];
    final now = DateTime.now();

    final thisMonth = allItems
        .where((i) => i.createdAt.year == now.year && i.createdAt.month == now.month)
        .toList();

    // ── Per-bedroom loads this month ─────────────────────────────────────────
    final Map<String, int> bedroomLoads = {};
    for (final item in thisMonth) {
      bedroomLoads[item.bedroom] = (bedroomLoads[item.bedroom] ?? 0) + item.numberOfLoads;
    }

    // Alert per bedroom if loads are high
    for (final entry in bedroomLoads.entries) {
      final room = entry.key;
      final loads = entry.value;
      if (loads >= 12) {
        final target = (loads * 0.5).round().clamp(5, loads - 1);
        tips.add(SmartTip(
          id: 'laundry_high_${room.replaceAll(' ', '_')}',
          category: TipCategory.laundry,
          severity: TipSeverity.warning,
          icon: Icons.local_laundry_service_rounded,
          title: '$room: $loads Loads This Month',
          body: '$room has done $loads laundry loads so far this month — '
                'that\'s quite high. Reducing to around $target loads monthly '
                'could cut electricity and detergent costs by up to 40%. '
                'Try grouping small washes into fuller loads.',
        ));
      } else if (loads >= 8) {
        tips.add(SmartTip(
          id: 'laundry_moderate_${room.replaceAll(' ', '_')}',
          category: TipCategory.laundry,
          severity: TipSeverity.suggestion,
          icon: Icons.local_laundry_service_rounded,
          title: '$room: $loads Loads This Month',
          body: '$room is averaging about ${(loads / 4).toStringAsFixed(1)} loads '
                'per week. Grouping clothes and washing fuller loads (instead of '
                'several small ones) saves water, electricity and detergent.',
        ));
      }
    }

    // ── Total household loads ────────────────────────────────────────────────
    final totalLoads = bedroomLoads.values.fold(0, (a, b) => a + b);
    if (totalLoads >= 25) {
      tips.add(SmartTip(
        id: 'laundry_total_high',
        category: TipCategory.laundry,
        severity: TipSeverity.warning,
        icon: Icons.water_drop_rounded,
        title: '$totalLoads Total Loads This Month',
        body: 'Your household has done $totalLoads laundry loads this month. '
              'Consider a "laundry day" schedule — 2 designated days per bedroom '
              'per week — to reduce unplanned washes and control power use.',
      ));
    } else if (totalLoads >= 15) {
      tips.add(SmartTip(
        id: 'laundry_total_moderate',
        category: TipCategory.laundry,
        severity: TipSeverity.suggestion,
        icon: Icons.water_drop_rounded,
        title: 'Track Your Monthly Laundry Costs',
        body: 'With $totalLoads loads this month, laundry is a real electricity '
              'cost. Each load uses roughly 1–2 kWh — that\'s up to '
              '${(totalLoads * 1.5).round()} kWh just for laundry this month.',
      ));
    }

    // ── Stuck batches (washing for > 24 hrs) ────────────────────────────────
    final stuck = allItems.where((i) =>
        i.stage == LaundryStage.washing &&
        now.difference(i.createdAt).inHours > 24).toList();
    if (stuck.isNotEmpty) {
      final rooms = stuck.map((i) => i.bedroom).toSet().join(', ');
      tips.add(SmartTip(
        id: 'laundry_stuck',
        category: TipCategory.laundry,
        severity: TipSeverity.alert,
        icon: Icons.hourglass_top_rounded,
        title: 'Laundry Left in Machine (${stuck.length} batch${stuck.length > 1 ? 'es' : ''})',
        body: 'Laundry in $rooms has been in the washing stage for more than '
              '24 hours. Clothes left wet in machines can develop mould and odours — '
              'please move them to drying as soon as possible.',
      ));
    }

    // ── Positive insight if laundry is well-managed ──────────────────────────
    if (totalLoads > 0 && totalLoads <= 10 && stuck.isEmpty) {
      tips.add(SmartTip(
        id: 'laundry_efficient',
        category: TipCategory.laundry,
        severity: TipSeverity.insight,
        icon: Icons.check_circle_rounded,
        title: 'Laundry Well-Managed This Month',
        body: 'Only $totalLoads loads so far this month with no stuck batches. '
              'The household is being efficient with laundry — keep it up!',
      ));
    }

    return tips;
  }

  // ── SUPPLIES TIPS ───────────────────────────────────────────────────────────

  static List<SmartTip> analyzeSupplies(List<SupplyItem> supplies) {
    if (supplies.isEmpty) return [];

    final tips = <SmartTip>[];
    final now = DateTime.now();

    final finished   = supplies.where((s) => s.status == SupplyStatus.finished).toList();
    final veryLow    = supplies.where((s) => s.status == SupplyStatus.veryLow).toList();
    final runningLow = supplies.where((s) => s.status == SupplyStatus.runningLow).toList();
    final noDate     = supplies.where((s) => s.lastRestockedAt == null).toList();

    // Finished items
    if (finished.length >= 3) {
      final names = finished.take(3).map((s) => s.name).join(', ');
      tips.add(SmartTip(
        id: 'supplies_finished_many',
        category: TipCategory.supplies,
        severity: TipSeverity.alert,
        icon: Icons.inventory_2_rounded,
        title: '${finished.length} Items Completely Finished',
        body: 'You\'ve run out of: $names${finished.length > 3 ? " and ${finished.length - 3} more" : ""}. '
              'These should be restocked as soon as possible to avoid disruptions '
              'to the household routine.',
      ));
    } else if (finished.isNotEmpty) {
      tips.add(SmartTip(
        id: 'supplies_finished',
        category: TipCategory.supplies,
        severity: TipSeverity.alert,
        icon: Icons.inventory_2_rounded,
        title: '${finished.map((s) => s.name).join(' & ')} Finished',
        body: '${finished.map((s) => s.name).join(' and ')} ${finished.length == 1 ? 'has' : 'have'} '
              'run out. Restock now to avoid household disruptions.',
      ));
    }

    // Very low warning
    if (veryLow.length >= 2) {
      final names = veryLow.take(3).map((s) => s.name).join(', ');
      tips.add(SmartTip(
        id: 'supplies_very_low',
        category: TipCategory.supplies,
        severity: TipSeverity.warning,
        icon: Icons.warning_amber_rounded,
        title: '${veryLow.length} Items at Critical Levels',
        body: '$names${veryLow.length > 3 ? " +" + "${veryLow.length - 3} more" : ""} '
              'are at very low levels. These are at risk of running out '
              'before your next shopping trip — order soon.',
      ));
    }

    // Items frequently low — look for short restock cycles
    final fastBurners = supplies.where((s) {
      if (s.lastRestockedAt == null || s.expectedDurationDays == null) return false;
      final daysSince = now.difference(s.lastRestockedAt!).inDays;
      return s.status != SupplyStatus.enough &&
             daysSince < (s.expectedDurationDays! * 0.6).round();
    }).toList();

    if (fastBurners.isNotEmpty) {
      final names = fastBurners.take(2).map((s) => s.name).join(' & ');
      tips.add(SmartTip(
        id: 'supplies_fast_burn',
        category: TipCategory.supplies,
        severity: TipSeverity.suggestion,
        icon: Icons.bolt_rounded,
        title: '$names Run Out Faster Than Expected',
        body: '${fastBurners.map((s) => s.name).take(3).join(", ")} '
              '${fastBurners.length == 1 ? "is" : "are"} running low sooner than '
              'the expected restock window. Consider buying a larger quantity '
              'or setting a shorter reorder reminder.',
      ));
    }

    // No restock dates tracked
    if (noDate.length > (supplies.length * 0.4).round() && noDate.length >= 3) {
      tips.add(SmartTip(
        id: 'supplies_no_dates',
        category: TipCategory.supplies,
        severity: TipSeverity.suggestion,
        icon: Icons.event_rounded,
        title: '${noDate.length} Items Have No Restock Date',
        body: 'Setting restock dates on your supplies lets homeFlow predict '
              'when you\'ll run out and send you timely reminders. '
              'Tap any supply item to add when it was last restocked.',
      ));
    }

    // Many categories in low state
    final categoriesLow = <String>{};
    for (final s in [...veryLow, ...finished]) {
      categoriesLow.add(s.category);
    }
    if (categoriesLow.length >= 3) {
      tips.add(SmartTip(
        id: 'supplies_multi_category',
        category: TipCategory.supplies,
        severity: TipSeverity.warning,
        icon: Icons.shopping_cart_rounded,
        title: 'Multiple Supply Categories Running Low',
        body: 'Items across ${categoriesLow.length} categories need attention: '
              '${categoriesLow.take(4).join(", ")}. '
              'Consider doing a comprehensive restock for all categories in one trip.',
      ));
    }

    // Good state insight
    final attentionCount = finished.length + veryLow.length + runningLow.length;
    if (attentionCount == 0 && supplies.length >= 5) {
      tips.add(SmartTip(
        id: 'supplies_all_good',
        category: TipCategory.supplies,
        severity: TipSeverity.insight,
        icon: Icons.check_circle_rounded,
        title: 'All Supplies Well-Stocked',
        body: 'All ${supplies.length} tracked supplies are in good shape. '
              'Keep logging restock dates to maintain accurate forecasts.',
      ));
    }

    return tips;
  }

  // ── UTILITIES TIPS ──────────────────────────────────────────────────────────

  static List<SmartTip> analyzeUtilities(List<UtilityTracker> trackers) {
    if (trackers.isEmpty) return [];

    final tips = <SmartTip>[];

    // ── Gas tips ─────────────────────────────────────────────────────────────
    final gasItems = trackers.where((t) => t.type == UtilityType.cookingGas).toList();
    for (final gas in gasItems) {
      final rem = gas.estimatedDaysRemaining;
      if (rem != null) {
        if (rem <= 3 && rem > 0) {
          tips.add(SmartTip(
            id: 'gas_critical_${gas.id}',
            category: TipCategory.utilities,
            severity: TipSeverity.alert,
            icon: Icons.local_fire_department_rounded,
            title: '${gas.label}: Gas Finishing in $rem Day${rem == 1 ? '' : 's'}',
            body: 'Your ${gas.brandName} cylinder has about $rem day${rem == 1 ? '' : 's'} '
                  'remaining. Order a refill now to avoid running out mid-meal. '
                  'Call your supplier or use M-Pesa to book delivery.',
          ));
        } else if (rem <= 7) {
          tips.add(SmartTip(
            id: 'gas_low_${gas.id}',
            category: TipCategory.utilities,
            severity: TipSeverity.warning,
            icon: Icons.local_fire_department_rounded,
            title: '${gas.label}: About a Week Left',
            body: '${gas.brandName} has approximately $rem days of gas remaining. '
                  'Plan a refill in the next 2–3 days to avoid disruption. '
                  'Pre-booking ensures faster delivery.',
          ));
        } else if (rem != null && rem > 7 && rem <= 14) {
          tips.add(SmartTip(
            id: 'gas_plan_${gas.id}',
            category: TipCategory.utilities,
            severity: TipSeverity.suggestion,
            icon: Icons.local_fire_department_rounded,
            title: 'Plan Your Next Gas Refill (${gas.label})',
            body: 'Gas will run out in about $rem days. Now is a good time to '
                  'check supplier availability and set a reminder, especially '
                  'before weekends when deliveries can be delayed.',
          ));
        }
      }
    }

    // ── Electricity tips ──────────────────────────────────────────────────────
    final elecItems = trackers.where((t) => t.type == UtilityType.electricity).toList();
    for (final elec in elecItems) {
      if (!elec.isPostpaid) {
        // Prepaid
        final units = elec.unitsRemaining;
        if (units != null && units <= 50 && units > 20) {
          tips.add(SmartTip(
            id: 'elec_low_${elec.id}',
            category: TipCategory.utilities,
            severity: TipSeverity.suggestion,
            icon: Icons.bolt_rounded,
            title: 'Electricity: ${units.toStringAsFixed(0)} kWh Remaining',
            body: 'Your prepaid meter has ${units.toStringAsFixed(0)} kWh left. '
                  'A typical 3-bedroom home uses 3–5 kWh/day, giving you roughly '
                  '${(units / 4).round()} more days. Top up soon to avoid running dry.',
          ));
        }
        if (elec.electricityLowAlertSent) {
          tips.add(SmartTip(
            id: 'elec_alert_sent_${elec.id}',
            category: TipCategory.utilities,
            severity: TipSeverity.alert,
            icon: Icons.power_off_rounded,
            title: 'Low Token Alert Active',
            body: 'The house manager has flagged that electricity tokens are '
                  'running very low. Top up now to avoid a power cut. '
                  'Use M-Pesa Paybill ${elec.electricityPaybill ?? "or KPLC app"}.',
          ));
        }
      }
    }

    // ── Bills due soon ────────────────────────────────────────────────────────
    final dueSoon = <String>[];
    final overdue = <String>[];

    for (final t in trackers) {
      final days = _daysUntilDue(t);
      final isPaid = _isPaid(t);
      if (isPaid) continue;
      if (days != null && days < 0) {
        overdue.add(t.label);
      } else if (days != null && days <= 5) {
        dueSoon.add('${t.label} (${days}d)');
      }
    }

    if (overdue.isNotEmpty) {
      tips.add(SmartTip(
        id: 'bills_overdue',
        category: TipCategory.utilities,
        severity: TipSeverity.alert,
        icon: Icons.payment_rounded,
        title: '${overdue.length} Bill${overdue.length > 1 ? 's' : ''} Overdue',
        body: '${overdue.join(", ")} ${overdue.length == 1 ? 'payment is' : 'payments are'} '
              'past the due date. Late payments can attract penalties or service '
              'disconnection. Pay immediately via M-Pesa.',
      ));
    }

    if (dueSoon.isNotEmpty) {
      tips.add(SmartTip(
        id: 'bills_due_soon',
        category: TipCategory.utilities,
        severity: TipSeverity.warning,
        icon: Icons.schedule_rounded,
        title: '${dueSoon.length} Bill${dueSoon.length > 1 ? 's' : ''} Due Soon',
        body: '${dueSoon.join(", ")} ${dueSoon.length == 1 ? 'is' : 'are'} '
              'due in the next 5 days. Set aside payment funds now to avoid '
              'last-minute scrambles.',
      ));
    }

    // ── Water level tips ──────────────────────────────────────────────────────
    final waterItems = trackers.where((t) =>
      t.type == UtilityType.water && t.isDrinkingWater).toList();
    for (final water in waterItems) {
      final full = water.fullContainers ?? 0;
      final threshold = water.reorderThreshold ?? 2;
      if (full <= threshold && full > 0) {
        tips.add(SmartTip(
          id: 'water_low_${water.id}',
          category: TipCategory.utilities,
          severity: TipSeverity.warning,
          icon: Icons.water_drop_rounded,
          title: 'Drinking Water Running Low',
          body: 'Only $full ${water.containerSizeLitres != null ? "${water.containerSizeLitres}L" : ""}'
                ' container${full == 1 ? '' : 's'} remaining — below your reorder '
                'threshold of $threshold. Order a delivery soon.',
        ));
      } else if (full == 0) {
        tips.add(SmartTip(
          id: 'water_empty_${water.id}',
          category: TipCategory.utilities,
          severity: TipSeverity.alert,
          icon: Icons.water_drop_rounded,
          title: 'No Drinking Water Remaining',
          body: 'All drinking water containers are empty. Order a delivery '
                'immediately to restore safe drinking water for the household.',
        ));
      }
    }

    // ── Positive insight ─────────────────────────────────────────────────────
    if (dueSoon.isEmpty && overdue.isEmpty) {
      final setupCount = trackers.where((t) => _isSetUp(t)).length;
      if (setupCount >= 2) {
        tips.add(SmartTip(
          id: 'utilities_clear',
          category: TipCategory.utilities,
          severity: TipSeverity.insight,
          icon: Icons.verified_rounded,
          title: 'No Utility Bills Due This Week',
          body: 'All $setupCount tracked utilities are on schedule — '
                'no overdue payments or imminent deadlines. '
                'Keep bills marked as paid promptly for accurate tracking.',
        ));
      }
    }

    return tips;
  }

  // ── ALL TIPS (combined, sorted by severity) ────────────────────────────────

  static List<SmartTip> allTips({
    required List<MealLog> meals,
    required List<LaundryItem> laundry,
    required List<SupplyItem> supplies,
    required List<UtilityTracker> utilities,
  }) {
    final all = [
      ...analyzeMeals(meals),
      ...analyzeLaundry(laundry),
      ...analyzeSupplies(supplies),
      ...analyzeUtilities(utilities),
    ];
    // Sort: alert > warning > suggestion > insight
    all.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    // Reverse so alert comes first
    return all.reversed.toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int? _daysUntilDue(UtilityTracker t) {
    final now = DateTime.now();
    int? dueDay;
    switch (t.type) {
      case UtilityType.electricity:
        if (t.isPostpaid) dueDay = t.electricityBillDueDayOfMonth;
        break;
      case UtilityType.internet:
        dueDay = t.internetDueDayOfMonth;
        break;
      case UtilityType.waterBill:
        dueDay = t.waterBillDueDayOfMonth;
        break;
      case UtilityType.serviceCharge:
        dueDay = t.serviceChargeDueDayOfMonth;
        break;
      case UtilityType.rent:
        dueDay = t.rentDueDayOfMonth;
        break;
      case UtilityType.payTv:
        dueDay = t.payTvDueDayOfMonth;
        break;
      default:
        return null;
    }
    if (dueDay == null) return null;
    var due = DateTime(now.year, now.month, dueDay);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, dueDay);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  static bool _isPaid(UtilityTracker t) {
    switch (t.type) {
      case UtilityType.electricity:
        return t.electricityPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.internet:
        return t.internetPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.waterBill:
        return t.waterBillPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.serviceCharge:
        return t.serviceChargePaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.rent:
        return t.rentPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.payTv:
        return t.payTvPaymentStatus == UtilityPaymentStatus.paid;
      default:
        return true;
    }
  }

  static bool _isSetUp(UtilityTracker t) {
    switch (t.type) {
      case UtilityType.cookingGas:    return t.gasSetupDone;
      case UtilityType.electricity:   return t.electricitySetupDone;
      case UtilityType.internet:      return t.internetSetupDone;
      case UtilityType.waterBill:     return t.waterBillSetupDone;
      case UtilityType.serviceCharge: return t.serviceChargeSetupDone;
      case UtilityType.rent:          return t.rentSetupDone;
      case UtilityType.payTv:         return t.payTvSetupDone;
      default:                        return t.waterSetupDone;
    }
  }
}
