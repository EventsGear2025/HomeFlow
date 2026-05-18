import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import 'splash_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_Slide> _slides = [
    _Slide(
      icon: Icons.home_rounded,
      iconColor: AppColors.primaryTeal,
      headline: 'Your home, all in one place',
      body:
          'homeFlow is a household management app built for Kenyan homes. '
          'Track utilities, manage supplies, coordinate staff, and keep '
          'everything running smoothly — all from one place.',
    ),
    _Slide(
      icon: Icons.group_rounded,
      iconColor: AppColors.uiBlue,
      headline: 'Roles that work for you',
      body:
          'You are the Homeowner — you set up the household and stay in '
          'charge. Invite a House Manager to help with day-to-day tasks. '
          'Every member sees only what is relevant to their role.',
    ),
    _Slide(
      icon: Icons.vpn_key_rounded,
      iconColor: AppColors.supportBlue,
      headline: 'Invite, don\'t share passwords',
      body:
          'Your household gets two unique invite codes — one for a '
          'co-owner and one for a house manager. Share the right code '
          'with the right person and keep access fully under your control.',
    ),
    _Slide(
      icon: Icons.receipt_long_rounded,
      iconColor: AppColors.utilitiesOrange,
      headline: 'Track every bill & utility',
      body:
          'Log electricity tokens, water bills, internet, rent, and '
          'service charges in one place. See spending trends over time '
          'and always know exactly what has been paid.',
    ),
    _Slide(
      icon: Icons.shopping_cart_rounded,
      iconColor: AppColors.success,
      headline: 'Shop smarter, stay private',
      body:
          'Build shared shopping lists, track deliveries to your door, '
          'and reorder supplies in seconds. Your data is visible only to '
          'your household — we never share or sell your information.',
    ),
  ];

  Future<void> _markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    _markSeen();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Pill-style step counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTinted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPage + 1} of ${_slides.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 56),
                ],
              ),
            ),

            // ── Page view ────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // ── Dots + CTA ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 32),
              child: Column(
                children: [
                  // Animated dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _currentPage ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primaryTeal
                              : AppColors.surfaceTinted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Next / Get Started button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _next,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(isLast ? 'Get Started' : 'Next'),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.arrow_forward_rounded
                                : Icons.chevron_right_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data ────────────────────────────────────────────────────────

class _Slide {
  final IconData icon;
  final Color iconColor;
  final String headline;
  final String body;

  const _Slide({
    required this.icon,
    required this.iconColor,
    required this.headline,
    required this.body,
  });
}

// ── Slide view ──────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: slide.iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              slide.icon,
              size: 58,
              color: slide.iconColor,
            ),
          ),
          const SizedBox(height: 44),

          // Headline
          Text(
            slide.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),

          // Body
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textHint,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
