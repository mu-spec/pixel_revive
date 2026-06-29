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
  bool _isDraggingSlider = false;

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
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              panEnabled: !_isDraggingSlider,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(24),
              clipBehavior: Clip.hardEdge,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _isDraggingSlider = true),
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _isDraggingSlider = true;
                    _sliderPosition = (_sliderPosition + details.delta.dx / width).clamp(0.02, 0.98);
                  });
                },
                onHorizontalDragEnd: (_) => setState(() => _isDraggingSlider = false),
                onTapDown: (details) {
                  setState(() {
                    _sliderPosition = (details.localPosition.dx / width).clamp(0.02, 0.98);
                  });
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Enhanced image on the right/base.
                    _imageLayer(widget.afterImage, width, height),

                    // Original image clipped from left to divider.
                    ClipRect(
                      clipper: _SliderClipper(_sliderPosition),
                      child: _imageLayer(widget.beforeImage, width, height),
                    ),

                    // Subtle dark vignette for professional contrast.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.08),
                                Colors.transparent,
                                Colors.black.withOpacity(0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Professional vertical compare line.
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
                            BoxShadow(
                              color: AppColors.cyan.withOpacity(0.45),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Center draggable handle with horizontal arrows.
                    Positioned(
                      left: dividerX - 25,
                      top: height / 2 - 25,
                      child: _compareHandle(),
                    ),

                    // Top labels.
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

                    // Small hint bottom center.
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.42),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Text(
                              'Pinch to zoom • Drag to compare',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _compareHandle() {
    return Container(
      width: 50,
      height: 50,
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
            color: AppColors.cyan.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
          SizedBox(width: 0),
          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10),
        ],
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
