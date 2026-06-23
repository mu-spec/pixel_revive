import 'package:flutter/material.dart';
import 'package:pixel_revive/constants/app_colors.dart';

class DemoComparisonScreen extends StatefulWidget {
  final String type;
  final String title;
  final String description;

  const DemoComparisonScreen({
    super.key,
    required this.type,
    required this.title,
    required this.description,
  });

  @override
  State<DemoComparisonScreen> createState() => _DemoComparisonScreenState();
}

class _DemoComparisonScreenState extends State<DemoComparisonScreen> {
  double _sliderPos = 0.5;

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
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final dividerX = w * _sliderPos;

                    return GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _sliderPos = (details.localPosition.dx / w).clamp(0.0, 1.0);
                        });
                      },
                      onTapDown: (details) {
                        setState(() {
                          _sliderPos = (details.localPosition.dx / w).clamp(0.0, 1.0);
                        });
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Enhanced View (Base - Sharp/Colorful)
                          Image.asset(
                            _getAfterPath(),
                            fit: BoxFit.cover,
                            width: w,
                            height: h,
                          ),

                          // 2. Original View (Clipped - Blurry/Low Quality on the Left)
                          ClipRect(
                            clipper: _DemoSliderClipper(_sliderPos),
                            child: Image.asset(
                              _getBeforePath(),
                              fit: BoxFit.cover,
                              width: w,
                              height: h,
                            ),
                          ),

                          // Divider Line
                          Positioned(
                            left: dividerX - 1.25,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2.5,
                              color: Colors.white,
                            ),
                          ),

                          // Slider Handle
                          Positioned(
                            left: dividerX - 22,
                            top: h / 2 - 22,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.unfold_more,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                          ),

                          // Tags
                          Positioned(
                            left: 18,
                            top: 18,
                            child: _tag('AI ACTIVE', AppColors.success),
                          ),
                          Positioned(
                            right: 18,
                            top: 18,
                            child: _tag('BEFORE', AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Detail Card
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'INTERACTIVE DEMO',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.touch_app, color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Drag slider to compare',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _DemoSliderClipper extends CustomClipper<Rect> {
  final double position;
  _DemoSliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    // Clips the top BEFORE image from 0 (left) to the slider dividerX position!
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_DemoSliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}