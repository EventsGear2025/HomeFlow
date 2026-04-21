import '../models/laundry_item.dart';
import '../models/meal_log.dart';
import '../models/supply_item.dart';
import '../models/utility_tracker.dart';
import 'smart_tips_engine.dart';

class HomeProIntelligenceReport {
  const HomeProIntelligenceReport({
    required this.headline,
    required this.summary,
    required this.personaTitle,
    required this.personaSummary,
    required this.homePulse,
    required this.rhythmScore,
    required this.surpriseShield,
    required this.calmHoursRecovered,
    required this.watchpointCount,
    required this.signals,
    required this.modules,
    required this.dayLabels,
    required this.forecastRows,
    required this.recommendations,
    required this.tips,
    required this.supplyMonthlySpend,
  });

  final String headline;
  final String summary;
  final String personaTitle;
  final String personaSummary;
  final int homePulse;
  final int rhythmScore;
  final int surpriseShield;
  final double calmHoursRecovered;
  final int watchpointCount;
  final List<HomeProSignalMetric> signals;
  final List<HomeProModuleNode> modules;
  final List<String> dayLabels;
  final List<HomeProForecastRow> forecastRows;
  final List<HomeProRecommendation> recommendations;
  final List<SmartTip> tips;
  /// Monthly spend per supply item (items with price logs only).
  final List<SupplySpendRow> supplyMonthlySpend;
}

class HomeProSignalMetric {
  const HomeProSignalMetric({
    required this.label,
    required this.score,
    required this.note,
  });

  final String label;
  final int score;
  final String note;
}

class HomeProModuleNode {
  const HomeProModuleNode({
    required this.label,
    required this.subtitle,
    required this.score,
    required this.tone,
  });

  final String label;
  final String subtitle;
  final int score;
  final String tone;
}

class HomeProForecastRow {
  const HomeProForecastRow({
    required this.label,
    required this.values,
    required this.summary,
  });

  final String label;
  final List<int> values;
  final String summary;
}

class HomeProRecommendation {
  const HomeProRecommendation({
    required this.title,
    required this.body,
    required this.badge,
    required this.score,
    required this.tone,
  });

  final String title;
  final String body;
  final String badge;
  final int score;
  final String tone;
}

/// Item-level monthly spend row for the Home Intelligence spend table.
class SupplySpendRow {
  const SupplySpendRow({
    required this.itemName,
    required this.category,
    required this.thisMonthSpend,
    required this.lastMonthSpend,
    required this.entryCount,
  });

  final String itemName;
  final String category;
  /// Total KES spent this calendar month.
  final double thisMonthSpend;
  /// Total KES spent last calendar month.
  final double lastMonthSpend;
  /// Number of price-logged entries this month.
  final int entryCount;
}

class HomeProIntelligenceEngine {
  static HomeProIntelligenceReport build({
    required List<MealLog> meals,
    required List<LaundryItem> laundry,
    required List<SupplyItem> supplies,
    required List<UtilityTracker> utilities,
    int householdMembers = 0,
    int childrenCount = 0,
  }) {
    final tips = SmartTipsEngine.allTips(
      meals: meals,
      laundry: laundry,
      supplies: supplies,
      utilities: utilities,
    );

    final mealProfile = _buildMealProfile(meals);
    final laundryProfile = _buildLaundryProfile(laundry);
    final supplyProfile = _buildSupplyProfile(supplies);
    final utilityProfile = _buildUtilityProfile(utilities);

    final moduleProfiles = <_ModuleProfile>[
      mealProfile,
      laundryProfile,
      supplyProfile,
      utilityProfile,
    ];

    final strongest = _highestProfile(moduleProfiles);
    final weakest = _lowestProfile(moduleProfiles);
    final rhythmLeader = _highestCadenceProfile(
      <_ModuleProfile>[mealProfile, laundryProfile, supplyProfile],
    );
    final watchpointCount = moduleProfiles.fold<int>(
      0,
      (sum, profile) => sum + profile.watchpoints,
    );

    final homePulse = _clampScore(
      (mealProfile.score * 0.28) +
          (laundryProfile.score * 0.18) +
          (supplyProfile.score * 0.27) +
          (utilityProfile.score * 0.27),
    );

    final rhythmScore = _clampScore(
      (mealProfile.cadenceScore * 0.58) +
          (laundryProfile.cadenceScore * 0.32) +
          (supplyProfile.cadenceScore * 0.10),
    );

    final surpriseShield = _clampScore(
      (supplyProfile.score * 0.55) +
          (utilityProfile.score * 0.45) -
          (watchpointCount * 4.0),
    );

    final calmHoursRecovered = (((homePulse + rhythmScore + surpriseShield) /
                    58.0) +
                (householdMembers >= 4 ? 0.55 : 0.0) +
                (childrenCount > 0 ? 0.35 : 0.0) -
                (watchpointCount / 16.0))
            .clamp(1.2, 8.6)
            .toDouble();

    final persona = _selectPersona(
      strongest: strongest,
      weakest: weakest,
      mealProfile: mealProfile,
      laundryProfile: laundryProfile,
      supplyProfile: supplyProfile,
      utilityProfile: utilityProfile,
      homePulse: homePulse,
      surpriseShield: surpriseShield,
    );

    final dayLabels = _nextSevenDayLabels();
    final supplyMonthlySpend = _buildSupplySpend(supplies);

    return HomeProIntelligenceReport(
      headline: _headlineForPersona(persona.title),
      summary:
          '${strongest.label} is your strongest household rhythm right now, while ${weakest.label.toLowerCase()} still has the biggest chance to make the week calmer.',
      personaTitle: persona.title,
      personaSummary: persona.summary,
      homePulse: homePulse,
      rhythmScore: rhythmScore,
      surpriseShield: surpriseShield,
      calmHoursRecovered: calmHoursRecovered,
      watchpointCount: watchpointCount,
      signals: <HomeProSignalMetric>[
        HomeProSignalMetric(
          label: 'Home pulse',
          score: homePulse,
          note:
              '${strongest.label} is delivering the clearest premium value right now.',
        ),
        HomeProSignalMetric(
          label: 'Routine strength',
          score: rhythmScore,
          note: rhythmLeader.routineNote,
        ),
        HomeProSignalMetric(
          label: 'Surprise shield',
          score: surpriseShield,
          note: watchpointCount == 0
              ? 'No urgent watchpoints are stacking up right now.'
              : '$watchpointCount live watchpoint${watchpointCount == 1 ? '' : 's'} still need attention before they create friction.',
        ),
      ],
      modules: moduleProfiles
          .map(
            (profile) => HomeProModuleNode(
              label: profile.label,
              subtitle: profile.subtitle,
              score: profile.score,
              tone: _toneForScore(profile.score),
            ),
          )
          .toList(),
      dayLabels: dayLabels,
      forecastRows: moduleProfiles
          .map(
            (profile) => HomeProForecastRow(
              label: profile.label,
              values: profile.forecastValues,
              summary: profile.forecastSummary,
            ),
          )
          .toList(),
      recommendations: _buildRecommendations(
        strongest: strongest,
        weakest: weakest,
        tips: tips,
        surpriseShield: surpriseShield,
        homePulse: homePulse,
      ),
      tips: tips.take(6).toList(),
      supplyMonthlySpend: supplyMonthlySpend,
    );
  }

  static _ModuleProfile _buildMealProfile(List<MealLog> meals) {
    final last30 = meals.where((log) => _withinDays(log.date, 30)).toList();
    final last14 = meals.where((log) => _withinDays(log.date, 14)).toList();
    final last7 = meals.where((log) => _withinDays(log.date, 7)).toList();

    final uniqueMealDays = _uniqueDayCount(last14.map((log) => log.date));
    final breakfastDays = _uniqueDayCount(
      last7
          .where(
            (log) => log.mealPeriod.toLowerCase().contains('breakfast') ||
                log.mealPeriod.toLowerCase().contains('morning'),
          )
          .map((log) => log.date),
    );
    final uniqueTags = last30.expand((log) => log.nutritionTags).toSet().length;

    final cadenceScore = last14.isEmpty
        ? 28
        : _clampScore((uniqueMealDays / 14.0) * 100);
    final breakfastScore = last7.isEmpty
        ? 35
        : _clampScore((breakfastDays / 7.0) * 100);
    final varietyScore = _clampScore((uniqueTags / 5.0) * 100);
    final score = last30.isEmpty
        ? 30
        : _clampScore(
            (cadenceScore * 0.55) +
                (breakfastScore * 0.20) +
                (varietyScore * 0.25),
          );

    final routineNote = uniqueMealDays >= 10
        ? 'Meals are landing on most days, which is exactly where premium household rhythm starts.'
        : breakfastDays < 3
            ? 'Mornings are the weakest part of the meal rhythm right now.'
            : 'Meal logging is still patchy enough to hide household patterns.';

    return _ModuleProfile(
      label: 'Meals',
      score: score,
      cadenceScore: cadenceScore,
      subtitle: last30.isEmpty
          ? 'Start logging meals to unlock household food patterns'
          : '$uniqueMealDays of the last 14 days have meal logs',
      forecastValues: _forecastFromDates(
        last30.map((log) => log.date),
        baseline: last30.isEmpty ? 8 : 18,
      ),
      forecastSummary: breakfastDays < 3
          ? 'The next lift will come from making mornings more predictable.'
          : uniqueMealDays >= 10
              ? 'Meal rhythm is already carrying a lot of household calm.'
              : 'A steadier meal rhythm will make the rest of the home easier to read.',
      routineNote: routineNote,
      watchpoints: 0,
    );
  }

  static _ModuleProfile _buildLaundryProfile(List<LaundryItem> laundry) {
    final last14 = laundry.where((item) => _withinDays(item.createdAt, 14)).toList();
    final last28 = laundry.where((item) => _withinDays(item.createdAt, 28)).toList();
    final uniqueDays = _uniqueDayCount(last14.map((item) => item.createdAt));
    final weeklyLoads = laundry
        .where((item) => _withinDays(item.createdAt, 7))
        .fold<int>(0, (sum, item) => sum + item.numberOfLoads);
    final storedCount = laundry.where((item) => item.isStored).length;
    final stuckCount = laundry
        .where(
          (item) =>
              item.stage == LaundryStage.washing && item.age.inHours > 24,
        )
        .length;

    final cadenceScore = last14.isEmpty
        ? 34
        : _clampScore((uniqueDays / 6.0) * 100);
    final balanceScore = weeklyLoads == 0
        ? 44
        : _clampScore(100 - ((weeklyLoads - 4).abs() * 12.0));
    final completionScore = laundry.isEmpty
        ? 46
        : _clampScore(((storedCount / laundry.length) * 100) + 28);
    final score = laundry.isEmpty
        ? 34
        : _clampScore(
            (cadenceScore * 0.35) +
                (balanceScore * 0.25) +
                (completionScore * 0.40) -
                (stuckCount * 12.0),
          );

    final forecastValues = _forecastFromDates(
      last28.map((item) => item.createdAt),
      baseline: last28.isEmpty ? 8 : 14,
      floor: 8,
    );
    if (forecastValues.isNotEmpty && stuckCount > 0) {
      forecastValues[0] = forecastValues[0] < 82 ? 82 : forecastValues[0];
    }

    return _ModuleProfile(
      label: 'Laundry',
      score: score,
      cadenceScore: cadenceScore,
      subtitle: stuckCount > 0
          ? '$stuckCount batch${stuckCount == 1 ? '' : 'es'} still need to move out of washing'
          : weeklyLoads == 0
              ? 'Laundry is quiet this week'
              : '$weeklyLoads load${weeklyLoads == 1 ? '' : 's'} tracked this week',
      forecastValues: forecastValues,
      forecastSummary: stuckCount > 0
          ? 'Finish the current batches before the next laundry spike lands.'
          : weeklyLoads > 0
              ? 'Laundry already has a visible rhythm this week.'
              : 'A planned reset day would make laundry easier to predict.',
      routineNote: uniqueDays >= 3
          ? 'Laundry is starting to behave like a repeatable weekly reset.'
          : 'Laundry still clusters into bursts instead of a reliable rhythm.',
      watchpoints: stuckCount,
    );
  }

  static _ModuleProfile _buildSupplyProfile(List<SupplyItem> supplies) {
    final total = supplies.length;
    final enoughCount = supplies
        .where((item) => item.status == SupplyStatus.enough)
        .length;
    final needAttention = supplies.where((item) => item.needsAttention).length;
    final finished = supplies
        .where((item) => item.status == SupplyStatus.finished)
        .length;
    final gasAlerts = supplies.where((item) => item.isGasLowAlert).length;
    final restockDates = supplies
        .where((item) => item.lastRestockedAt != null)
        .map((item) => item.lastRestockedAt!)
        .toList();
    final recentRestocks = restockDates
        .where((date) => _withinDays(date, 14))
        .length;
    final cadenceScore = restockDates.isEmpty
        ? 42
        : _clampScore((_uniqueDayCount(restockDates) / 4.0) * 100);
    final enoughScore = total == 0
        ? 32
        : _clampScore((enoughCount / total) * 100);
    final recentScore = restockDates.isEmpty
        ? 48
        : _clampScore((recentRestocks / restockDates.length) * 100);
    final score = total == 0
        ? 34
        : _clampScore(
            (enoughScore * 0.62) +
                (recentScore * 0.18) +
                (cadenceScore * 0.20) -
                (finished * 10.0) -
                ((needAttention > 1 ? needAttention - 1 : 0) * 4.0) -
                (gasAlerts * 6.0),
          );

    final basePressure = (needAttention * 18) + (finished * 12) + (gasAlerts * 10);
    final forecastValues = List<int>.generate(7, (index) {
      var value = basePressure == 0 ? (index >= 4 ? 14 : 10) : basePressure - (index * 4);
      if (finished > 0 && index <= 2) {
        value += 18;
      }
      if (gasAlerts > 0 && index <= 3) {
        value += 12;
      }
      return _clampScore(value.toDouble());
    });

    return _ModuleProfile(
      label: 'Supplies',
      score: score,
      cadenceScore: cadenceScore,
      subtitle: needAttention == 0
          ? '$total tracked items feel under control'
          : '$needAttention item${needAttention == 1 ? '' : 's'} need attention',
      forecastValues: forecastValues,
      forecastSummary: needAttention == 0
          ? 'Supply cover is healthy, so the week should stay quiet here.'
          : finished > 0
              ? '$finished item${finished == 1 ? '' : 's'} are already out and likely to create friction soon.'
              : 'Restocking earlier will keep shopping from becoming reactive.',
      routineNote: needAttention == 0
          ? 'Supplies are protecting the week instead of interrupting it.'
          : 'Supplies are starting to create avoidable household friction.',
      watchpoints: needAttention + gasAlerts,
    );
  }

  static List<SupplySpendRow> _buildSupplySpend(List<SupplyItem> supplies) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final rows = <SupplySpendRow>[];
    for (final item in supplies) {
      final priced =
          item.usageLogs.where((e) => e.price != null && e.price! > 0).toList();
      if (priced.isEmpty) continue;
      final thisMonth = priced
          .where((e) => !e.date.isBefore(thisMonthStart))
          .fold(0.0, (sum, e) => sum + e.price!);
      final lastMonth = priced
          .where((e) =>
              !e.date.isBefore(lastMonthStart) &&
              e.date.isBefore(thisMonthStart))
          .fold(0.0, (sum, e) => sum + e.price!);
      if (thisMonth == 0 && lastMonth == 0) continue;
      rows.add(SupplySpendRow(
        itemName: item.name,
        category: item.category,
        thisMonthSpend: thisMonth,
        lastMonthSpend: lastMonth,
        entryCount: priced
            .where((e) => !e.date.isBefore(thisMonthStart))
            .length,
      ));
    }
    rows.sort((a, b) => b.thisMonthSpend.compareTo(a.thisMonthSpend));
    return rows;
  }

  static _ModuleProfile _buildUtilityProfile(List<UtilityTracker> utilities) {
    final total = utilities.length;
    final configured = utilities.where(_isUtilityConfigured).length;
    final lowAlerts = utilities.where((utility) => utility.isLowAlert).length;
    final dueSoon = utilities
        .where((utility) {
          final dueIn = _daysUntilUtilityAttention(utility);
          return dueIn != null && dueIn <= 3;
        })
        .length;

    final cadenceScore = total == 0
        ? 36
        : _clampScore((configured / total) * 100);
    final alertFreeScore = total == 0
        ? 36
        : _clampScore(((total - lowAlerts) / total) * 100);
    final dueReadinessScore = dueSoon == 0
        ? 88
        : _clampScore(100 - (dueSoon * 22.0));
    final score = total == 0
        ? 34
        : _clampScore(
            (cadenceScore * 0.45) +
                (alertFreeScore * 0.30) +
                (dueReadinessScore * 0.25),
          );

    final forecastValues = List<int>.generate(7, (index) {
      var value = lowAlerts > 0 ? (lowAlerts * (index <= 2 ? 16 : 10)) : 0;
      for (final utility in utilities) {
        final dueIn = _daysUntilUtilityAttention(utility);
        if (dueIn == null) {
          continue;
        }
        if (dueIn <= 0 && index == 0) {
          value += 28;
          continue;
        }
        final distance = (dueIn - index).abs();
        if (distance == 0) {
          value += 24;
        } else if (distance == 1) {
          value += 18;
        } else if (distance <= 3) {
          value += 10;
        }
      }
      if (value == 0 && configured > 0) {
        value = 8;
      }
      return _clampScore(value.toDouble());
    });

    final watchpoints = lowAlerts + dueSoon;

    return _ModuleProfile(
      label: 'Utilities',
      score: score,
      cadenceScore: cadenceScore,
      subtitle: watchpoints == 0
          ? '$configured of $total systems look ready'
          : '$watchpoints utility watchpoint${watchpoints == 1 ? '' : 's'} this week',
      forecastValues: forecastValues,
      forecastSummary: watchpoints == 0
          ? 'Bills and refills are calm right now.'
          : 'Due dates and low alerts can become surprise costs if they stack.',
      routineNote: watchpoints == 0
          ? 'Utilities are staying one step ahead of the week.'
          : 'Utility readiness is the fastest way to reduce household surprise.',
      watchpoints: watchpoints,
    );
  }

  static List<HomeProRecommendation> _buildRecommendations({
    required _ModuleProfile strongest,
    required _ModuleProfile weakest,
    required List<SmartTip> tips,
    required int surpriseShield,
    required int homePulse,
  }) {
    SmartTip? urgentTip;
    for (final tip in tips) {
      if (tip.severity == TipSeverity.alert ||
          tip.severity == TipSeverity.warning) {
        urgentTip = tip;
        break;
      }
    }

    final protectRecommendation = urgentTip != null
        ? HomeProRecommendation(
            title: urgentTip.title,
            body: urgentTip.body,
            badge: 'Protect now',
            score: _clampScore(125 - surpriseShield.toDouble()),
            tone: 'warning',
          )
        : HomeProRecommendation(
            title: 'Keep the calm edge',
            body:
                'There are no major fires right now. Use this week to top up the smallest weak spots before they turn noisy.',
            badge: 'Protect now',
            score: _clampScore(110 - surpriseShield.toDouble()),
            tone: 'steady',
          );

    final optimizeRecommendation = HomeProRecommendation(
      title: _optimizeTitleForModule(weakest.label),
      body: _optimizeBodyForModule(weakest.label),
      badge: 'Smooth the routine',
      score: _clampScore(120 - weakest.score.toDouble()),
      tone: weakest.score < 56 ? 'warning' : 'steady',
    );

    final celebrateRecommendation = HomeProRecommendation(
      title: _celebrateTitleForModule(strongest.label),
      body: _celebrateBodyForModule(strongest.label, homePulse),
      badge: 'Signature move',
      score: strongest.score,
      tone: strongest.score >= 76 ? 'strong' : 'steady',
    );

    return <HomeProRecommendation>[
      protectRecommendation,
      optimizeRecommendation,
      celebrateRecommendation,
    ];
  }

  static _PersonaProfile _selectPersona({
    required _ModuleProfile strongest,
    required _ModuleProfile weakest,
    required _ModuleProfile mealProfile,
    required _ModuleProfile laundryProfile,
    required _ModuleProfile supplyProfile,
    required _ModuleProfile utilityProfile,
    required int homePulse,
    required int surpriseShield,
  }) {
    final strongCount = <_ModuleProfile>[
      mealProfile,
      laundryProfile,
      supplyProfile,
      utilityProfile,
    ].where((profile) => profile.score >= 72).length;

    if (strongCount >= 3 && homePulse >= 74) {
      return const _PersonaProfile(
        title: 'Command Center',
        summary:
            'The household is getting value across multiple systems, not just one feature. That is what premium should feel like.',
      );
    }

    if (mealProfile.score >= 70 && laundryProfile.score >= 68) {
      return const _PersonaProfile(
        title: 'Rhythm Keeper',
        summary:
            'Your strongest value is predictable household rhythm. Meals and resets are creating calm that compounds through the week.',
      );
    }

    if (supplyProfile.score >= 70 && utilityProfile.score >= 66) {
      return const _PersonaProfile(
        title: 'Supply Sentinel',
        summary:
            'This home wins by staying ahead of refills, bills, and quiet operational details before they become stress.',
      );
    }

    if (surpriseShield < 56 || weakest.watchpoints >= 2) {
      return const _PersonaProfile(
        title: 'Reset Mode',
        summary:
            'The home has good data, but a few weak links are stealing calm. One focused cleanup will noticeably improve the week.',
      );
    }

    return _PersonaProfile(
      title: 'Steady Builder',
      summary:
          '${strongest.label} is already strong, and the next premium lift is in ${weakest.label.toLowerCase()}.',
    );
  }

  static _ModuleProfile _highestProfile(List<_ModuleProfile> profiles) {
    var highest = profiles.first;
    for (final profile in profiles.skip(1)) {
      if (profile.score > highest.score) {
        highest = profile;
      }
    }
    return highest;
  }

  static _ModuleProfile _lowestProfile(List<_ModuleProfile> profiles) {
    var lowest = profiles.first;
    for (final profile in profiles.skip(1)) {
      if (profile.score < lowest.score) {
        lowest = profile;
      }
    }
    return lowest;
  }

  static _ModuleProfile _highestCadenceProfile(List<_ModuleProfile> profiles) {
    var highest = profiles.first;
    for (final profile in profiles.skip(1)) {
      if (profile.cadenceScore > highest.cadenceScore) {
        highest = profile;
      }
    }
    return highest;
  }

  static bool _withinDays(DateTime value, int days) {
    return DateTime.now().difference(value).inDays <= days;
  }

  static int _uniqueDayCount(Iterable<DateTime> dates) {
    final keys = <String>{};
    for (final date in dates) {
      keys.add('${date.year}-${date.month}-${date.day}');
    }
    return keys.length;
  }

  static List<int> _forecastFromDates(
    Iterable<DateTime> dates, {
    required int baseline,
    int floor = 10,
  }) {
    final counts = <int, int>{
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };

    for (final date in dates) {
      counts[date.weekday] = (counts[date.weekday] ?? 0) + 1;
    }

    var maxCount = 0;
    for (final value in counts.values) {
      if (value > maxCount) {
        maxCount = value;
      }
    }

    final start = DateTime.now();
    return List<int>.generate(7, (index) {
      final weekday = start.add(Duration(days: index)).weekday;
      final count = counts[weekday] ?? 0;
      if (maxCount == 0) {
        return baseline;
      }
      final scaled = (((count / maxCount) * (100 - floor)) + floor).round();
      return scaled.clamp(floor, 100);
    });
  }

  static bool _isUtilityConfigured(UtilityTracker utility) {
    switch (utility.type) {
      case UtilityType.cookingGas:
        return utility.gasSetupDone || utility.lastRefilledAt != null;
      case UtilityType.electricity:
        return utility.electricitySetupDone;
      case UtilityType.water:
        return utility.isDrinkingWater ? utility.waterSetupDone : true;
      case UtilityType.waterBill:
        return utility.waterBillSetupDone;
      case UtilityType.serviceCharge:
        return utility.serviceChargeSetupDone;
      case UtilityType.internet:
        return utility.internetSetupDone;
      case UtilityType.rent:
        return utility.rentSetupDone;
      case UtilityType.payTv:
        return utility.payTvSetupDone;
      case UtilityType.other:
        return true;
    }
  }

  static int? _daysUntilUtilityAttention(UtilityTracker utility) {
    if (utility.type == UtilityType.cookingGas && utility.isLowAlert) {
      return utility.estimatedDaysRemaining ?? 0;
    }
    if (utility.type == UtilityType.water && utility.isDrinkingWater) {
      return utility.isLowAlert ? 0 : null;
    }
    if (utility.type == UtilityType.electricity && !utility.isPostpaid) {
      return utility.isLowAlert ? 0 : null;
    }
    if (utility.type == UtilityType.electricity && utility.isPostpaid) {
      return utility.electricityDaysUntilDue;
    }
    if (utility.type == UtilityType.internet) {
      return utility.internetDaysUntilDue;
    }
    if (utility.type == UtilityType.waterBill) {
      return utility.waterBillDaysUntilDue;
    }
    if (utility.type == UtilityType.serviceCharge) {
      return utility.serviceChargeDaysUntilDue;
    }
    if (utility.type == UtilityType.rent) {
      return utility.rentDaysUntilDue;
    }
    if (utility.type == UtilityType.payTv) {
      return utility.payTvDaysUntilDue;
    }
    return null;
  }

  static int _clampScore(double value) {
    return value.round().clamp(0, 100);
  }

  static String _toneForScore(int score) {
    if (score >= 76) {
      return 'strong';
    }
    if (score >= 56) {
      return 'steady';
    }
    return 'warning';
  }

  static List<String> _nextSevenDayLabels() {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List<String>.generate(
      7,
      (index) => labels[now.add(Duration(days: index)).weekday - 1],
    );
  }

  static String _headlineForPersona(String personaTitle) {
    switch (personaTitle) {
      case 'Command Center':
        return 'Your home is operating like a calm command center.';
      case 'Rhythm Keeper':
        return 'Your biggest premium win is household rhythm, not raw volume.';
      case 'Supply Sentinel':
        return 'This home is strongest when it stays one step ahead of the week.';
      case 'Reset Mode':
        return 'A few weak links are stealing calm from an otherwise strong home.';
      default:
        return 'Your premium routine is taking shape, and the best value is starting to show.';
    }
  }

  static String _optimizeTitleForModule(String label) {
    switch (label) {
      case 'Meals':
        return 'Build one stronger meal anchor';
      case 'Laundry':
        return 'Close the laundry loop faster';
      case 'Supplies':
        return 'Restock before the list gets noisy';
      case 'Utilities':
        return 'Get ahead of the next bill or refill';
      default:
        return 'Tighten the weakest household loop';
    }
  }

  static String _optimizeBodyForModule(String label) {
    switch (label) {
      case 'Meals':
        return 'Lock one breakfast anchor and one dependable dinner prep window. A steadier meal rhythm makes the whole home easier to manage.';
      case 'Laundry':
        return 'Choose one reset window for each busy room so loads stop clustering into stressful bursts.';
      case 'Supplies':
        return 'Clear low and finished items earlier in the week so shopping stays deliberate instead of reactive.';
      case 'Utilities':
        return 'Pay or top up the nearest utility deadlines before they become interruptions, surprise costs, or last-minute errands.';
      default:
        return 'The easiest premium lift now is to tighten the weakest routine while momentum is still on your side.';
    }
  }

  static String _celebrateTitleForModule(String label) {
    switch (label) {
      case 'Meals':
        return 'Meals are setting the tone';
      case 'Laundry':
        return 'Laundry is becoming a real reset rhythm';
      case 'Supplies':
        return 'Supplies are quietly protecting the week';
      case 'Utilities':
        return 'Bills and refills are giving you a calm edge';
      default:
        return 'One system is already doing premium-level work';
    }
  }

  static String _celebrateBodyForModule(String label, int homePulse) {
    switch (label) {
      case 'Meals':
        return 'Keep the current cadence and add a little more variety. Food rhythm is already doing a lot of the work behind your home pulse of $homePulse.';
      case 'Laundry':
        return 'The reset pattern is visible now. Protect it by finishing active batches before the weekend rush builds.';
      case 'Supplies':
        return 'You are getting premium value from staying ahead of low stock. Keep restocks early and quiet so the shield stays strong.';
      case 'Utilities':
        return 'When utilities stay ahead, everything else feels lighter. Keep using that lead time to avoid surprise spending.';
      default:
        return 'Double down on the strongest routine because it is already lifting the rest of the household.';
    }
  }
}

class _ModuleProfile {
  const _ModuleProfile({
    required this.label,
    required this.score,
    required this.cadenceScore,
    required this.subtitle,
    required this.forecastValues,
    required this.forecastSummary,
    required this.routineNote,
    required this.watchpoints,
  });

  final String label;
  final int score;
  final int cadenceScore;
  final String subtitle;
  final List<int> forecastValues;
  final String forecastSummary;
  final String routineNote;
  final int watchpoints;
}

class _PersonaProfile {
  const _PersonaProfile({
    required this.title,
    required this.summary,
  });

  final String title;
  final String summary;
}