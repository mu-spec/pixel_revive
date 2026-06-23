import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/services/image_processor.dart';
import 'package:pixel_revive/widgets/processing_dialog.dart';

class CropRotateScreen extends StatefulWidget {
  const CropRotateScreen({super.key});

  @override
  State<CropRotateScreen> createState() => _CropRotateScreenState();
}

class _CropRotateScreenState extends State<CropRotateScreen> {
  bool _isLoading = true;
  double _originalWidth = 0;
  double _originalHeight = 0;

  // Viewport/Layout sizes
  Size _containerSize = Size.zero;
  Size _imageRenderSize = Size.zero;

  // Transformations
  int _rotationIndex = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // Crop Box state
  Rect _cropRect = Rect.zero;
  double? _selectedRatio; // null = free, otherwise width/height
  int _activeHandle = -1; // -1: none, 0: TL, 1: TR, 2: BL, 3: BR, 4: Move Box

  final List<Map<String, dynamic>> _aspectRatios = [
    {'label': 'Free', 'ratio': null, 'icon': Icons.crop_free},
    {'label': '1:1', 'ratio': 1.0, 'icon': Icons.crop_square},
    {'label': '4:3', 'ratio': 4.0 / 3.0, 'icon': Icons.crop},
    {'label': '16:9', 'ratio': 16.0 / 9.0, 'icon': Icons.crop_16_9},
    {'label': '3:2', 'ratio': 3.0 / 2.0, 'icon': Icons.crop_3_2},
  ];

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final provider = context.read<AppProvider>();
    if (provider.originalBytes == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final size = await ImageProcessor.getImageSize(provider.originalBytes!);
      if (size != null) {
        _originalWidth = size.width;
        _originalHeight = size.height;
      }
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _recalculateLayout() {
    if (_containerSize.width == 0 || _containerSize.height == 0) return;
    if (_originalWidth == 0 || _originalHeight == 0) return;

    // If rotated 90 or 270 degrees, swap original dimensions for layout fitting
    final bool isSwapped = _rotationIndex % 2 != 0;
    final double curW = isSwapped ? _originalHeight : _originalWidth;
    final double curH = isSwapped ? _originalWidth : _originalHeight;

    final imageSize = Size(curW, curH);

    // Calculate how the rotated image fits inside the container constraints (BoxFit.contain)
    final containerRatio = _containerSize.width / _containerSize.height;
    final imageRatio = imageSize.width / imageSize.height;

    double renderW, renderH;
    if (imageRatio > containerRatio) {
      renderW = _containerSize.width;
      renderH = renderW / imageRatio;
    } else {
      renderH = _containerSize.height;
      renderW = renderH * imageRatio;
    }

    _imageRenderSize = Size(renderW, renderH);

    _initCropRectToDefault();
  }

  void _initCropRectToDefault() {
    final double w = _imageRenderSize.width;
    final double h = _imageRenderSize.height;

    if (w == 0 || h == 0) return;

    if (_selectedRatio == null) {
      // Free form crop: default to 10% inside margins
      _cropRect = Rect.fromLTRB(
        w * 0.05,
        h * 0.05,
        w * 0.95,
        h * 0.95,
      );
    } else {
      final double ratio = _selectedRatio!;
      double targetW, targetH;

      if (w / h > ratio) {
        // Image is wider than crop aspect ratio
        targetH = h * 0.9;
        targetW = targetH * ratio;
      } else {
        // Image is taller than crop aspect ratio
        targetW = w * 0.9;
        targetH = targetW / ratio;
      }

      final double left = (w - targetW) / 2;
      final double top = (h - targetH) / 2;

      _cropRect = Rect.fromLTWH(left, top, targetW, targetH);
    }
  }

  int _getHandleAtPosition(Offset localPos) {
    const double touchThreshold = 35.0;

    final double dTL = (localPos - _cropRect.topLeft).distance;
    final double dTR = (localPos - _cropRect.topRight).distance;
    final double dBL = (localPos - _cropRect.bottomLeft).distance;
    final double dBR = (localPos - _cropRect.bottomRight).distance;

    if (dTL < touchThreshold) return 0;
    if (dTR < touchThreshold) return 1;
    if (dBL < touchThreshold) return 2;
    if (dBR < touchThreshold) return 3;

    if (_cropRect.contains(localPos)) {
      return 4; // Move the whole crop box
    }

    return -1;
  }

  void _resizeCropRect(int handle, Offset delta) {
    double left = _cropRect.left;
    double top = _cropRect.top;
    double right = _cropRect.right;
    double bottom = _cropRect.bottom;

    const double minSize = 60.0;
    final double maxW = _imageRenderSize.width;
    final double maxH = _imageRenderSize.height;

    double clampX(double x) => x.clamp(0.0, maxW);
    double clampY(double y) => y.clamp(0.0, maxH);

    if (_selectedRatio == null) {
      // FREE FORM
      switch (handle) {
        case 0:
          left = clampX(left + delta.dx);
          top = clampY(top + delta.dy);
          if (right - left < minSize) left = right - minSize;
          if (bottom - top < minSize) top = bottom - minSize;
          break;
        case 1:
          right = clampX(right + delta.dx);
          top = clampY(top + delta.dy);
          if (right - left < minSize) right = left + minSize;
          if (bottom - top < minSize) top = bottom - minSize;
          break;
        case 2:
          left = clampX(left + delta.dx);
          bottom = clampY(bottom + delta.dy);
          if (right - left < minSize) left = right - minSize;
          if (bottom - top < minSize) bottom = top + minSize;
          break;
        case 3:
          right = clampX(right + delta.dx);
          bottom = clampY(bottom + delta.dy);
          if (right - left < minSize) right = left + minSize;
          if (bottom - top < minSize) bottom = top + minSize;
          break;
        case 4:
          double w = _cropRect.width;
          double h = _cropRect.height;
          double newLeft = left + delta.dx;
          double newTop = top + delta.dy;

          if (newLeft < 0) newLeft = 0;
          if (newTop < 0) newTop = 0;
          if (newLeft + w > maxW) newLeft = maxW - w;
          if (newTop + h > maxH) newTop = maxH - h;

          left = newLeft;
          top = newTop;
          right = left + w;
          bottom = top + h;
          break;
      }
    } else {
      // ASPECT RATIO LOCKED
      final double ratio = _selectedRatio!;
      switch (handle) {
        case 0: // Top-Left
          double newLeft = clampX(left + delta.dx);
          double newWidth = right - newLeft;
          if (newWidth < minSize) {
            newWidth = minSize;
            newLeft = right - minSize;
          }
          double newHeight = newWidth / ratio;
          double newTop = bottom - newHeight;

          if (newTop < 0) {
            newTop = 0;
            newHeight = bottom - newTop;
            newWidth = newHeight * ratio;
            newLeft = right - newWidth;
          }
          left = newLeft;
          top = newTop;
          break;

        case 1: // Top-Right
          double newRight = clampX(right + delta.dx);
          double newWidth = newRight - left;
          if (newWidth < minSize) {
            newWidth = minSize;
            newRight = left + minSize;
          }
          double newHeight = newWidth / ratio;
          double newTop = bottom - newHeight;

          if (newTop < 0) {
            newTop = 0;
            newHeight = bottom - newTop;
            newWidth = newHeight * ratio;
            newRight = left + newWidth;
          }
          right = newRight;
          top = newTop;
          break;

        case 2: // Bottom-Left
          double newLeft = clampX(left + delta.dx);
          double newWidth = right - newLeft;
          if (newWidth < minSize) {
            newWidth = minSize;
            newLeft = right - minSize;
          }
          double newHeight = newWidth / ratio;
          double newBottom = top + newHeight;

          if (newBottom > maxH) {
            newBottom = maxH;
            newHeight = newBottom - top;
            newWidth = newHeight * ratio;
            newLeft = right - newWidth;
          }
          left = newLeft;
          bottom = newBottom;
          break;

        case 3: // Bottom-Right
          double newRight = clampX(right + delta.dx);
          double newWidth = newRight - left;
          if (newWidth < minSize) {
            newWidth = minSize;
            newRight = left + minSize;
          }
          double newHeight = newWidth / ratio;
          double newBottom = top + newHeight;

          if (newBottom > maxH) {
            newBottom = maxH;
            newHeight = newBottom - top;
            newWidth = newHeight * ratio;
            newRight = left + newWidth;
          }
          right = newRight;
          bottom = newBottom;
          break;

        case 4: // Move Entire Box
          double w = _cropRect.width;
          double h = _cropRect.height;
          double newLeft = left + delta.dx;
          double newTop = top + delta.dy;

          if (newLeft < 0) newLeft = 0;
          if (newTop < 0) newTop = 0;
          if (newLeft + w > maxW) newLeft = maxW - w;
          if (newTop + h > maxH) newTop = maxH - h;

          left = newLeft;
          top = newTop;
          right = left + w;
          bottom = top + h;
          break;
      }
    }

    setState(() {
      _cropRect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotationIndex = (_rotationIndex + 1) % 4;
      _recalculateLayout();
    });
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotationIndex = (_rotationIndex - 1 + 4) % 4;
      _recalculateLayout();
    });
  }

  void _flipHoriz() {
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void _flipVert() {
    setState(() {
      _flipVertical = !_flipVertical;
    });
  }

  void _reset() {
    setState(() {
      _rotationIndex = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _selectedRatio = null;
      _recalculateLayout();
    });
  }

  void _setAspectRatio(double? ratio) {
    setState(() {
      _selectedRatio = ratio;
      _initCropRectToDefault();
    });
  }

  Future<void> _applyAndSave() async {
    final provider = context.read<AppProvider>();
    if (provider.originalBytes == null) return;

    // Show a loading/processing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProcessingDialog(),
    );

    try {
      // Compute normalized crop coordinates relative to the rendered image bounds
      double cropL = 0.0, cropT = 0.0, cropW = 1.0, cropH = 1.0;
      if (_imageRenderSize.width > 0 && _imageRenderSize.height > 0) {
        cropL = _cropRect.left / _imageRenderSize.width;
        cropT = _cropRect.top / _imageRenderSize.height;
        cropW = _cropRect.width / _imageRenderSize.width;
        cropH = _cropRect.height / _imageRenderSize.height;
      }

      // Convert rotation turns index to actual degrees:
      // quarterTurns: 0->0, 1->90, 2->180, 3->270
      final int deg = _rotationIndex * 90;

      final editedBytes = await ImageProcessor.editImage(
        input: provider.originalBytes!,
        cropLeft: cropL,
        cropTop: cropT,
        cropWidth: cropW,
        cropHeight: cropH,
        rotateDegrees: deg,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      );

      await provider.updateOriginalImage(editedBytes);

      if (mounted) {
        Navigator.pop(context); // Pop processing dialog
        Navigator.pop(context); // Pop Crop & Rotate screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image changes applied!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop processing dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying changes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('Crop & Rotate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _reset,
          ),
          TextButton(
            onPressed: _isLoading ? null : _applyAndSave,
            child: const Text(
              'Apply',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final Size freshContainer =
                            Size(constraints.maxWidth, constraints.maxHeight);

                        if (_containerSize != freshContainer) {
                          _containerSize = freshContainer;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            setState(() {
                              _recalculateLayout();
                            });
                          });
                        }

                        if (_imageRenderSize.width == 0 ||
                            _imageRenderSize.height == 0) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        return Center(
                          child: SizedBox(
                            width: _imageRenderSize.width,
                            height: _imageRenderSize.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // The image transformed visually for responsive previews
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..scale(
                                          _flipHorizontal ? -1.0 : 1.0,
                                          _flipVertical ? -1.0 : 1.0,
                                        ),
                                      child: RotatedBox(
                                        quarterTurns: _rotationIndex,
                                        child: Image.memory(
                                          provider.originalBytes!,
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Crop shaded overlay & grid lines
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: CropOverlayPainter(
                                      cropRect: _cropRect,
                                      containerSize: _imageRenderSize,
                                    ),
                                  ),
                                ),

                                // Large gesture handler overlay
                                Positioned.fill(
                                  child: GestureDetector(
                                    onPanStart: (details) {
                                      final handle = _getHandleAtPosition(
                                          details.localPosition);
                                      if (handle != -1) {
                                        _activeHandle = handle;
                                      }
                                    },
                                    onPanUpdate: (details) {
                                      if (_activeHandle != -1) {
                                        _resizeCropRect(
                                            _activeHandle, details.delta);
                                      }
                                    },
                                    onPanEnd: (_) {
                                      _activeHandle = -1;
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
                _buildEditingControls(),
              ],
            ),
    );
  }

  Widget _buildEditingControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Flip & Rotates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlBtn(
                icon: Icons.rotate_left,
                label: 'Rotate L',
                onTap: _rotateCounterClockwise,
              ),
              _controlBtn(
                icon: Icons.rotate_right,
                label: 'Rotate R',
                onTap: _rotateClockwise,
              ),
              _controlBtn(
                icon: Icons.flip,
                label: 'Flip H',
                onTap: _flipHoriz,
              ),
              _controlBtn(
                icon: Icons.swap_vert,
                label: 'Flip V',
                onTap: _flipVert,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.card, height: 1),
          const SizedBox(height: 16),
          // Row 2: Aspect Ratios
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _aspectRatios.length,
              itemBuilder: (context, index) {
                final item = _aspectRatios[index];
                final isSelected = _selectedRatio == item['ratio'];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    avatar: Icon(
                      item['icon'],
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textMuted,
                    ),
                    label: Text(
                      item['label'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.card,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (_) => _setAspectRatio(item['ratio']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.success, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Size containerSize;

  CropOverlayPainter({required this.cropRect, required this.containerSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    // Outer shade
    canvas.drawRect(Rect.fromLTRB(0, 0, cropRect.left, size.height), paint);
    canvas.drawRect(
        Rect.fromLTRB(cropRect.right, 0, size.width, size.height), paint);
    canvas.drawRect(
        Rect.fromLTRB(cropRect.left, 0, cropRect.right, cropRect.top), paint);
    canvas.drawRect(
        Rect.fromLTRB(cropRect.left, cropRect.bottom, cropRect.right, size.height),
        paint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    // Thirds grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double thirdW = cropRect.width / 3;
    final double thirdH = cropRect.height / 3;

    canvas.drawLine(
        Offset(cropRect.left + thirdW, cropRect.top),
        Offset(cropRect.left + thirdW, cropRect.bottom),
        gridPaint);
    canvas.drawLine(
        Offset(cropRect.left + 2 * thirdW, cropRect.top),
        Offset(cropRect.left + 2 * thirdW, cropRect.bottom),
        gridPaint);

    canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH),
        Offset(cropRect.right, cropRect.top + thirdH),
        gridPaint);
    canvas.drawLine(
        Offset(cropRect.left, cropRect.top + 2 * thirdH),
        Offset(cropRect.right, cropRect.top + 2 * thirdH),
        gridPaint);

    // Thick Corner Handles
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    const double hLen = 18.0;

    // TL
    canvas.drawLine(
        cropRect.topLeft, cropRect.topLeft + const Offset(hLen, 0), handlePaint);
    canvas.drawLine(
        cropRect.topLeft, cropRect.topLeft + const Offset(0, hLen), handlePaint);

    // TR
    canvas.drawLine(
        cropRect.topRight, cropRect.topRight + const Offset(-hLen, 0), handlePaint);
    canvas.drawLine(
        cropRect.topRight, cropRect.topRight + const Offset(0, hLen), handlePaint);

    // BL
    canvas.drawLine(
        cropRect.bottomLeft, cropRect.bottomLeft + const Offset(hLen, 0), handlePaint);
    canvas.drawLine(
        cropRect.bottomLeft, cropRect.bottomLeft + const Offset(0, -hLen), handlePaint);

    // BR
    canvas.drawLine(
        cropRect.bottomRight, cropRect.bottomRight + const Offset(-hLen, 0), handlePaint);
    canvas.drawLine(
        cropRect.bottomRight, cropRect.bottomRight + const Offset(0, -hLen), handlePaint);
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.containerSize != containerSize;
  }
}