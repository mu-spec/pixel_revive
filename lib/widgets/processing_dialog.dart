import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';

class ProcessingDialog extends StatefulWidget {
  const ProcessingDialog({super.key});

  @override
  State<ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<ProcessingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  int _textIndex = 0;

  List<String> _loadingPhrases(String lang) => [
    AppStrings.getText('phrase1', lang),
    AppStrings.getText('phrase2', lang),
    AppStrings.getText('phrase3', lang),
    AppStrings.getText('phrase4', lang),
    AppStrings.getText('phrase5', lang),
    AppStrings.getText('phrase6', lang),
    AppStrings.getText('phrase7', lang),
  ];

  @override
  void initState() {
    super.initState();
    // 1. Setup continuous laser animation (up and down)
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    // 2. Rotate loading phrases every 1.5 seconds to build anticipation
    _rotatePhrases();
  }

  void _rotatePhrases() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % 7;
        });
      }
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final phrases = _loadingPhrases(provider.languageCode);
    return PopScope(
      canPop: false, // Prevent dismissing by back button
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stylized Scanning Box
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Sub-grid pattern
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.08,
                          child: CustomPaint(
                            painter: _LaserGridPainter(),
                          ),
                        ),
                      ),
                      // Core scanner icon in center
                      const Center(
                        child: Icon(
                          Icons.face_retouching_natural,
                          size: 44,
                          color: AppColors.accent,
                        ),
                      ),
                      // Glowing laser line sweeping up and down
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _laserAnimation.value * 128,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Main title
              Text(
                AppStrings.getText('aiProcessing', provider.languageCode),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),
              // Dynamically changing phrase
              SizedBox(
                height: 38,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Text(
                    provider.lastProcessingMessage.isNotEmpty
                        ? provider.lastProcessingMessage
                        : phrases[_textIndex],
                    key: ValueKey<String>(provider.lastProcessingMessage.isNotEmpty
                        ? provider.lastProcessingMessage
                        : phrases[_textIndex]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Progress track
              const SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.card,
                  color: AppColors.success,
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () {
                  provider.cancelProcessing();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  AppStrings.getText('cancel', provider.languageCode),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaserGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;
    const double step = 10.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}