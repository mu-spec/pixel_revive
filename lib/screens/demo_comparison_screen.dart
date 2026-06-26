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
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final dividerX = (w * _sliderPos).clamp(0.0, w);

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // BEFORE - base layer (left side revealed)
                          Image.asset(
                            _getBeforePath(),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),

                          // AFTER - clipped on the right
                          ClipRect(
                            clipper: _AfterClipper(_sliderPos),
                            child: Image.asset(
                              _getAfterPath(),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                            ),
                          ),

                          // Divider line
                          Positioned(
                            left: dividerX - 1.5,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Handle
                          Positioned(
                            left: dividerX - 28,
                            top: h / 2 - 28,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragUpdate: (d) {
                                final box = context.findRenderObject() as RenderBox?;
                                if (box == null) return;
                                final local = box.globalToLocal(d.globalPosition);
                                final newPos = ((local.dx - 20) / w).clamp(0.0, 1.0);
                                setState(() => _sliderPos = newPos);
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: AppColors.accent.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chevron_left_rounded,
                                        size: 22, color: AppColors.textMuted),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 22, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // BEFORE tag - left
                          Positioned(
                            left: 14,
                            top: 14,
                            child: _chip('BEFORE', false),
                          ),
                          // AFTER tag - right
                          Positioned(
                            right: 14,
                            top: 14,
                            child: _chip('AFTER', true),
                          ),

                          // Full-width drag catcher
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _sliderPos =
                                      (details.localPosition.dx / w).clamp(0.0, 1.0);
                                });
                              },
                              onTapDown: (details) {
                                setState(() {
                                  _sliderPos =
                                      (details.localPosition.dx / w).clamp(0.0, 1.0);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Detail Card
          Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -6),
                )
              ],
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
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'INTERACTIVE DEMO',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.swap_horiz_rounded,
                          color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 6),
                      const Text(
                        'Drag to compare',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13.5,
                      height: 1.5,
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

  Widget _chip(String text, bool isAfter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isAfter ? AppColors.accent : Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Clips the AFTER image - shows it on the RIGHT side of the slider
class _AfterClipper extends CustomClipper<Rect> {
  final double position;
  _AfterClipper(this.position);

  @override
  Rect getClip(Size size) {
    // Show AFTER on the right side
    return Rect.fromLTRB(size.width * position, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_AfterClipper oldClipper) => oldClipper.position != position;
}
