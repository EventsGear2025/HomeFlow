import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../utils/app_colors.dart';
import '../models/admin_models.dart';

class AdminShellScaffold extends StatelessWidget {
  const AdminShellScaffold({
    super.key,
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final int selectedIndex;
  final List<AdminNavItem> navItems;
  final ValueChanged<int> onSelect;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      drawer: isDesktop ? null : Drawer(child: _SidebarContents(selectedIndex: selectedIndex, navItems: navItems, onSelect: onSelect)),
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 280,
              child: _SidebarContents(selectedIndex: selectedIndex, navItems: navItems, onSelect: onSelect),
            ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(title: title, subtitle: subtitle, trailing: trailing),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarContents extends StatelessWidget {
  const _SidebarContents({required this.selectedIndex, required this.navItems, required this.onSelect});

  final int selectedIndex;
  final List<AdminNavItem> navItems;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [AppColors.secondaryTeal, AppColors.primaryTeal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text('HomeFlow Admin', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Operations console', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: navItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = navItems[index];
                  final selected = index == selectedIndex;
                  return Material(
                    color: selected ? AppColors.surfaceMuted : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        onSelect(index);
                        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(item.icon, color: selected ? AppColors.primaryTeal : AppColors.textSecondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: selected ? AppColors.primaryTeal : AppColors.textPrimary,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF001D39),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Admin role', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 6),
                  Text('Super Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Can manage households, billing, support, presets, and audit controls.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showSearch = width >= 900;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
              final isDesktop = MediaQuery.of(context).size.width >= 1100;
              if (!hasDrawer || isDesktop) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (showSearch) ...[
            SizedBox(
              width: 320,
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search households, users, issues...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          ?trailing,
          const SizedBox(width: 12),
          const CircleAvatar(radius: 20, backgroundColor: AppColors.surfaceMuted, child: Icon(Icons.person, color: AppColors.primaryTeal)),
        ],
      ),
    );
  }
}

class AdminContentSection extends StatelessWidget {
  const AdminContentSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }
}

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({super.key, required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon, color: stat.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _AdminStatDeltaBadge(delta: stat.delta),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(stat.value, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(stat.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          );
        },
      ),
    );
  }
}

class _AdminStatDeltaBadge extends StatelessWidget {
  const _AdminStatDeltaBadge({required this.delta});

  final String delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        delta,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({super.key, required this.title, required this.subtitle, this.actions = const []});

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    );
  }
}

class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(items.length, (index) {
        final selected = index == selectedIndex;
        return Material(
          color: selected ? AppColors.surfaceMuted : Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onSelected == null ? null : () => onSelected!(index),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? AppColors.primaryTeal : AppColors.divider),
              ),
              child: Text(
                items[index],
                style: TextStyle(
                  color: selected ? AppColors.primaryTeal : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({super.key, required this.values, this.color = AppColors.primaryTeal});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _LineChartPainter(values: values, color: color),
        child: Container(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final dx = size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final dy = size.height - (normalized * (size.height - 10)) - 5;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.01)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UsageBar extends StatelessWidget {
  const UsageBar({super.key, required this.label, required this.current, required this.max});

  final String label;
  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final percent = max == 0 ? 0.0 : current / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$current/$max', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 10,
          percent: percent.clamp(0.0, 1.0),
          backgroundColor: AppColors.surfaceMuted,
          progressColor: percent >= 0.9 ? AppColors.accentOrange : AppColors.primaryTeal,
          barRadius: const Radius.circular(999),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surfaceMuted;
    Color fg = AppColors.primaryTeal;
    final lower = label.toLowerCase();
    if (lower.contains('critical') || lower.contains('inactive') || lower.contains('deactivate')) {
      bg = const Color(0xFFFFE9E5);
      fg = AppColors.accentOrange;
    } else if (lower.contains('warning') || lower.contains('trial') || lower.contains('near')) {
      bg = const Color(0xFFFFF7DB);
      fg = const Color(0xFF9A6C00);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class TableCard extends StatelessWidget {
  const TableCard({super.key, required this.title, required this.columns, required this.rows});

  final String title;
  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceLight),
              columns: columns.map((col) => DataColumn(label: Text(col, style: const TextStyle(fontWeight: FontWeight.w700)))).toList(),
              rows: rows.map((cells) => DataRow(cells: cells.map((w) => DataCell(w)).toList())).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
