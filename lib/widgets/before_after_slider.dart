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
  final TransformationController _transformController = TransformationController();
  double _sliderPosition = 0.5;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final nextScale = _transformController.value.getMaxScaleOnAxis();
    if ((nextScale - _scale).abs() > 0.03 && mounted) {
      setState(() => _scale = nextScale);
    }
  }

  void _resetZoom() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _scale = 1.0;
    });
  }

  void _zoomIn() {
    final next = (_scale + 0.75).clamp(1.0, 5.0);
    setState(() {
      _scale = next;
      _transformController.value = Matrix4.identity()..scale(next);
    });
  }

  void _zoomOut() {
    final next = (_scale - 0.75).clamp(1.0, 5.0);
    setState(() {
      _scale = next;
      _transformController.value = Matrix4.identity()..scale(next);
    });
  }

  void _setSliderFromGlobal(Offset globalPosition, BuildContext boxContext) {
    final box = boxContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final width = box.size.width;
    if (width <= 0) return;
    setState(() {
      _sliderPosition = (local.dx / width).clamp(0.02, 0.98);
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: const EdgeInsets.all(96),
                    clipBehavior: Clip.hardEdge,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: _resetZoom,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: _CompareStack(
                          beforeImage: widget.beforeImage,
                          afterImage: widget.afterImage,
                          sliderPosition: _sliderPosition,
                          dividerX: dividerX,
                          width: width,
                          height: height,
                          lang: lang,
                        ),
                      ),
                    ),
                  ),
                ),

                // Dedicated compare handle. It sits above the InteractiveViewer so
                // dragging the handle changes comparison, while dragging elsewhere pans.
                Positioned(
                  left: dividerX - 30,
                  top: 0,
                  bottom: 0,
                  width: 60,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) => _setSliderFromGlobal(details.globalPosition, context),
                    onPanUpdate: (details) => _setSliderFromGlobal(details.globalPosition, context),
                    child: Center(child: _compareHandle()),
                  ),
                ),

                // Zoom controls.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _zoomControls(),
                ),

                // Slider quick reset.
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
        );
      },
    );
  }

  Widget _zoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.46),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _miniIconButton(Icons.remove_rounded, _zoomOut),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${_scale.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _miniIconButton(Icons.add_rounded, _zoomIn),
        ],
      ),
    );
  }

  Widget _miniIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 16),
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
}

class _CompareStack extends StatelessWidget {
  final Uint8List beforeImage;
  final Uint8List afterImage;
  final double sliderPosition;
  final double dividerX;
  final double width;
  final double height;
  final String lang;

  const _CompareStack({
    required this.beforeImage,
    required this.afterImage,
    required this.sliderPosition,
    required this.dividerX,
    required this.width,
    required this.height,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _imageLayer(afterImage),
        ClipRect(
          clipper: _SliderClipper(sliderPosition),
          child: _imageLayer(beforeImage),
        ),
        Positioned.fill(child: _vignette()),
        _divider(),
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
      ],
    );
  }

  Widget _imageLayer(Uint8List bytes) {
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

  Widget _divider() {
    return Positioned(
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

  Widget _hint(String text) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.42),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
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
