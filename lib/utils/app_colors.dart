import 'package:flutter/material.dart';

class AppColors {
  // ── Brand palette ──────────────────────────────────────────────
  /// Deep navy — main buttons, icons, active states, nav bar
  static const Color primaryTeal = Color(0xFF001D39);
  /// Medium navy — secondary elements, section headers
  static const Color secondaryTeal = Color(0xFF0A4174);
  /// Warm accent — warnings, destructive actions (unchanged)
  static const Color accentOrange = Color(0xFFF1715A);
  /// Yellow accent — caution states (unchanged)
  static const Color accentYellow = Color(0xFFFBCE60);
  static const Color white = Color(0xFFFFFFFF);

  // ── Extended blue palette ──────────────────────────────────────
  /// Main UI blue — secondary buttons, chips, progress
  static const Color uiBlue = Color(0xFF49769F);
  /// Soft support blue — backgrounds of tinted elements
  static const Color supportBlue = Color(0xFF4E8EA2);
  /// Light card blue — tinted card surfaces
  static const Color cardBlue = Color(0xFF6EA2B3);
  /// Light highlight blue — selected states, emphasis
  static const Color highlightBlue = Color(0xFF7BBDE8);

  // ── Surface hierarchy (light → dark tint) ─────────────────────
  /// Near-white scaffold / page background
  static const Color surfaceLight = Color(0xFFF5F9FC);
  /// Subtle blue tint — selected states, panels, chips
  static const Color surfaceMuted = Color(0xFFEAF1F7);
  /// Visible blue tint — tinted cards, section headers
  static const Color surfaceTinted = Color(0xFFDDE9F2);
  /// Soft blue card surface
  static const Color surfaceCard = Color(0xFFD6E4EF);
  /// Tag / badge tint on dark backgrounds
  static const Color tagTint = Color(0xFFEDF4FA);

  // ── Semantic ───────────────────────────────────────────────────
  static const Color success = Color(0xFF198754);
  static const Color warningAmber = Color(0xFFD4960A);
  static const Color warningBg = Color(0xFFFBCE60);
  static const Color danger = Color(0xFFF1715A);
  static const Color info = Color(0xFF49769F);

  // ── Tip severity palette ───────────────────────────────────────
  static const Color tipInsight = Color(0xFF4E8EA2);
  static const Color tipInsightBg = Color(0xFFE4EEF5);
  static const Color tipSuggestion = Color(0xFF1E88E5);
  static const Color tipSuggestionBg = Color(0xFFE3F2FD);
  static const Color tipWarning = Color(0xFFF57C00);
  static const Color tipWarningBg = Color(0xFFFFF3E0);
  static const Color tipAlert = Color(0xFFD32F2F);
  static const Color tipAlertBg = Color(0xFFFFEBEE);

  // ── Third-party brand colours (intentional) ───────────────────
  /// M-Pesa green — used only on M-Pesa payment UI elements
  static const Color mpesaGreen = Color(0xFF16A34A);
  /// WhatsApp green — used only on WhatsApp action buttons
  static const Color whatsappGreen = Color(0xFF25D366);
  /// SMS blue — used only on SMS action buttons
  static const Color smsBlue = Color(0xFF0EA5E9);

  // ── Category-specific colours ─────────────────────────────────
  /// Nutrition green — used in meals / nutrition charts
  static const Color nutritionGreen = Color(0xFF16A34A);
  /// Utilities burnt orange — used for utilities quick-action icon
  static const Color utilitiesOrange = Color(0xFFE0882A);

  // ── Neutral ────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFBDD8E9);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFA4C0D4);
  static const Color textPrimary = Color(0xFF001D39);
  static const Color textSecondary = Color(0xFF0A4174);
  static const Color textHint = Color(0xFF5F7D94);

  // ── Status chip colors ─────────────────────────────────────────
  static const Color statusEnough = Color(0xFFC8DFF0);
  static const Color statusEnoughText = Color(0xFF0A4174);
  static const Color statusLow = Color(0xFFFFF8E1);
  static const Color statusLowText = Color(0xFFB8860B);
  static const Color statusVeryLow = Color(0xFFFFEDE8);
  static const Color statusVeryLowText = Color(0xFFD9442A);
  static const Color statusFinished = Color(0xFFFCECEC);
  static const Color statusFinishedText = Color(0xFFB71C1C);
}
