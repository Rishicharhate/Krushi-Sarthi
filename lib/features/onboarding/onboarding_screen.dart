import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// 3-page onboarding flow for first-time users.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.sensors_rounded,
      iconBg: AppColors.earthBrown,
      title: 'Monitor Your Soil',
      description: 'Track soil conditions using real-time sensor data.',
    ),
    _OnboardingPageData(
      icon: Icons.satellite_alt_rounded,
      iconBg: AppColors.skyBlue,
      title: 'Monitor Crop Health',
      description: 'Track crop health using satellite-based NDVI analysis.',
    ),
    _OnboardingPageData(
      icon: Icons.psychology_rounded,
      iconBg: AppColors.primaryGreen,
      title: 'Detect Crop Diseases',
      description: 'Upload a leaf image and use AI-powered analysis to identify crop diseases.',
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    final storage = ref.read(localStorageProvider);
    storage.setBool(AppConstants.keyOnboardingComplete, true);
    ref.read(onboardingCompleteProvider.notifier).state = true;
    context.go('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ──
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

            // ── Page content ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _OnboardingPage(data: _pages[index]),
              ),
            ),

            // ── Dot indicators ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentPage ? 32 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? AppColors.primaryGreen
                          : AppColors.primaryGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),

            // ── Action button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ElevatedButton(
                onPressed: _onNext,
                child: Text(isLastPage ? 'Get Started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.description,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Illustration ──
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: data.iconBg.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              size: 80,
              color: data.iconBg,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 500.ms),

          const SizedBox(height: 48),

          // ── Title ──
          Text(
            data.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: 16),

          // ── Description ──
          Text(
            data.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }
}
