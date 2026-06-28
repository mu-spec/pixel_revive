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
  bool _isDraggingSlider = false; // Flag to prevent panning collision when swiping!

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppProvider>().languageCode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dividerX = width * _sliderPosition;

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          panEnabled: !_isDraggingSlider, // Disable panning when sliding to prevent gesture collisions!
          scaleEnabled: true,
          clipBehavior: Clip.none, // Allow handle and indicators to render cleanly when zoomed in
          child: GestureDetector(
            onHorizontalDragStart: (_) {
              setState(() => _isDraggingSlider = true);
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _isDraggingSlider = true;
                _sliderPosition += details.delta.dx / width;
                _sliderPosition = _sliderPosition.clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() => _isDraggingSlider = false);
            },
            onTapDown: (details) {
              setState(() {
                _sliderPosition = (details.localPosition.dx / width).clamp(0.0, 1.0);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. AFTER IMAGE (Base Full-Size background)
                Center(
                  child: Image.memory(
                    widget.afterImage,
                    fit: BoxFit.contain,
                    width: width,
                    height: height,
                  ),
                ),

                // 2. BEFORE IMAGE (Identical render, clipped horizontally by SliderClipper)
                ClipRect(
                  clipper: _SliderClipper(_sliderPosition),
                  child: Center(
                    child: Image.memory(
                      widget.beforeImage,
                      fit: BoxFit.contain,
                      width: width,
                      height: height,
                    ),
                  ),
                ),

                // 3. Elegant thin divider line
                Positioned(
                  left: dividerX - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          AppColors.accent,
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Premium draggable handle with dual arrow icons
                Positioned(
                  left: dividerX - 20,
                  top: height / 2 - 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.unfold_more,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                // 5. Labels with modern glassmorphic look
                Positioned(
                  left: 16,
                  top: 16,
                  child: _label(AppStrings.getText('labelOriginal', lang), AppColors.textMuted),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: _label(AppStrings.getText('labelEnhanced', lang), AppColors.success),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
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