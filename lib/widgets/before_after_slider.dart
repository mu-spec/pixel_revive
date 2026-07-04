import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';

class BeforeAfterSlider extends StatefulWidget {
  final Uint8List beforeImage;
  final Uint8List afterImage;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _sliderPosition = 0.5;

  void _setSliderFromLocal(double dx, double width) {
    if (width <= 0) return;
    setState(() {
      _sliderPosition = (dx / width).clamp(0.02, 0.98);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppProvider>().languageCode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dividerX = (width * _sliderPosition).clamp(0.0, width);

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            color: AppColors.primary,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => _setSliderFromLocal(details.localPosition.dx, width),
              onTapDown: (details) => _setSliderFromLocal(details.localPosition.dx, width),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _imageLayer(widget.afterImage, width, height),
                  ClipRect(
                    clipper: _SliderClipper(_sliderPosition),
                    child: _imageLayer(widget.beforeImage, width, height),
                  ),
                  Positioned.fill(child: _vignette()),
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
                          stops: [0.0, 0.18, 0.5, 0.82, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(color: AppColors.cyan.withOpacity(0.45), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: dividerX - 27,
                    top: height / 2 - 27,
                    child: _compareHandle(),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _label(AppStrings.getText('labelOriginal', lang), AppColors.textSoft),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: _label(AppStrings.getText('labelEnhanced', lang), AppColors.success),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _smallPill(
                      icon: Icons.swap_horiz_rounded,
                      text: '${(_sliderPosition * 100).round()}%',
                      onTap: () => setState(() => _sliderPosition = 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _imageLayer(Uint8List bytes, double width, double height) {
    return Center(
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: width,
        height: height,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _vignette() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.08),
              Colors.transparent,
              Colors.black.withOpacity(0.14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compareHandle() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cyan, AppColors.accent],
        ),
        border: Border.all(color: Colors.white, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.48),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  Widget _smallPill({required IconData icon, required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.46),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.cyan, size: 15),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double position;

  _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}
