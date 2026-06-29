import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _routeToHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_launch', false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final List<Map<String, dynamic>> slides = [
      {
        'title': AppStrings.getText('onboardingTitle1', provider.languageCode),
        'subtitle': AppStrings.getText('onboardingSub1', provider.languageCode),
        'type': 'restore',
      },
      {
        'title': AppStrings.getText('onboardingTitle2', provider.languageCode),
        'subtitle': AppStrings.getText('onboardingSub2', provider.languageCode),
        'type': 'upscale',
      },
      {
        'title': AppStrings.getText('onboardingTitle3', provider.languageCode),
        'subtitle': AppStrings.getText('onboardingSub3', provider.languageCode),
        'type': 'blur',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
            // Top Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _routeToHome,
                  child: Text(
                    AppStrings.getText('skip', provider.languageCode),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            // Page View for Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Draggable Before/After demo canvas
                        _buildSlideVisual(slide['type']),
                        const SizedBox(height: 36),
                        // Title
                        Text(
                          slide['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Subtitle
                        Text(
                          slide['subtitle'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Footer controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.accent
                              : AppColors.card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.brandGradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < slides.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _routeToHome();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage == slides.length - 1
                              ? AppStrings.getText('getStarted', provider.languageCode)
                              : AppStrings.getText('next', provider.languageCode),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlideVisual(String type) {
    final lang = context.read<AppProvider>().languageCode;
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _InteractiveDemoSlider(type: type),
      ),
    );
  }
}

class _InteractiveDemoSlider extends StatefulWidget {
  final String type;
  const _InteractiveDemoSlider({required this.type});

  @override
  State<_InteractiveDemoSlider> createState() => _InteractiveDemoSliderState();
}

class _InteractiveDemoSliderState extends State<_InteractiveDemoSlider> {
  double _dragPosition = 0.5;

  String _getBeforePath() {
    if (widget.type == 'restore') return 'assets/images/demo_restore_before.png';
    if (widget.type == 'upscale') return 'assets/images/demo_upscale_before.png';
    return 'assets/images/demo_blur_before.png';
  }

  String _getAfterPath() {
    if (widget.type == 'restore') return 'assets/images/demo_restore_after.png';
    if (widget.type == 'upscale') return 'assets/images/demo_upscale_after.png';
    return 'assets/images/demo_blur_after.png';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().languageCode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dividerX = w * _dragPosition;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragPosition = (details.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          onTapDown: (details) {
            setState(() {
              _dragPosition = (details.localPosition.dx / w).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Enhanced (Vibrant) Image on left background
              Image.asset(
                _getAfterPath(),
                fit: BoxFit.cover,
                width: w,
                height: h,
              ),

              // 2. Faded/Original Image on right clipped area
              ClipRect(
                clipper: _RectClipper(dividerX, w, h),
                child: Image.asset(
                  _getBeforePath(),
                  fit: BoxFit.cover,
                  width: w,
                  height: h,
                ),
              ),

              // 3. Professional vertical compare divider
              Positioned(
                left: dividerX - 1.25,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.white,
                        AppColors.cyan,
                        Colors.white,
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 10),
                    ],
                  ),
                ),
              ),

              // 4. Professional compare handle
              Positioned(
                left: dividerX - 22,
                top: h / 2 - 22,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.cyan, AppColors.accent]),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                      Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),

              // 5. Left Label "AFTER"
              Positioned(
                left: 14,
                bottom: 14,
                child: _buildLabel(AppStrings.getText('labelAiActive', lang), AppColors.success),
              ),

              // 6. Right Label "BEFORE"
              Positioned(
                right: 14,
                bottom: 14,
                child: _buildLabel(AppStrings.getText('labelOriginal', lang), AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _RectClipper extends CustomClipper<Rect> {
  final double limit;
  final double fullW;
  final double fullH;

  _RectClipper(this.limit, this.fullW, this.fullH);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(limit, 0, fullW, fullH);
  }

  @override
  bool shouldReclip(_RectClipper oldClipper) {
    return oldClipper.limit != limit;
  }
}