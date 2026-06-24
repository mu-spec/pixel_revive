import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/premium_screen.dart';

class BatchProcessScreen extends StatefulWidget {
  const BatchProcessScreen({super.key});

  @override
  State<BatchProcessScreen> createState() => _BatchProcessScreenState();
}

class _BatchProcessScreenState extends State<BatchProcessScreen> {
  String _selectedFeatureId = 'auto';

  final List<Map<String, String>> _batchFeatures = [
    {'id': 'auto', 'title': 'Auto Enhance', 'icon': 'auto_fix_high'},
    {'id': 'upscale', 'title': 'HD Upscale', 'icon': 'hd'},
    {'id': 'denoise', 'title': 'Denoise', 'icon': 'grain'},
    {'id': 'unblur', 'title': 'Unblur', 'icon': 'deblur'},
    {'id': 'colorize', 'title': 'Colorize B&W', 'icon': 'palette'},
    {'id': 'bg_cleanup', 'title': 'BG Cleanup', 'icon': 'cleaning_services'},
  ];

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'hd':
        return Icons.hd;
      case 'grain':
        return Icons.grain;
      case 'deblur':
        return Icons.deblur;
      case 'palette':
        return Icons.palette;
      case 'cleaning_services':
        return Icons.cleaning_services;
      default:
        return Icons.auto_fix_high;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text(
          'Batch AI Studio',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (provider.batchImages.isNotEmpty && !provider.isBatchProcessing)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.success),
              tooltip: 'Clear Batch',
              onPressed: () {
                setState(() {
                  provider.batchImages.clear();
                  provider.batchOriginalBytes.clear();
                  provider.batchProcessedBytes.clear();
                });
              },
            ),
        ],
      ),
      body: provider.isBatchProcessing
          ? _buildProcessingProgress(provider)
          : provider.batchImages.isEmpty
              ? _buildEmptyState(context, provider)
              : _buildBatchDashboard(context, provider),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withOpacity(0.2), width: 1.5),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 60,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Batch Photo Enhance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Select multiple photos from your library to restore, upscale, or colorize them all in one single high-speed queue!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.goldGradient,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!provider.isPremium) {
                    _showPremiumLockedDialog(context);
                    return;
                  }
                  await provider.pickBatchImages();
                },
                icon: const Icon(Icons.add_photo_alternate, size: 20),
                label: const Text(
                  'Select Batch Photos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchDashboard(BuildContext context, AppProvider provider) {
    final bool isCompleted = provider.batchProcessedBytes.isNotEmpty &&
        provider.batchProcessedBytes.length == provider.batchOriginalBytes.length;

    return Column(
      children: [
        // 1. Grid of thumbnails
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: provider.batchImages.length,
              itemBuilder: (context, index) {
                final file = provider.batchImages[index];
                final hasProcessed = provider.batchProcessedBytes.length > index;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasProcessed ? AppColors.success : Colors.black.withOpacity(0.08),
                      width: hasProcessed ? 2 : 1.2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Thumbnail image
                        hasProcessed
                            ? Image.memory(
                                provider.batchProcessedBytes[index],
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                file,
                                fit: BoxFit.cover,
                              ),
                        
                        // Status overlays
                        if (hasProcessed)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 22,
                              ),
                            ),
                          )
                        else
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#${index + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
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

        // 2. Control dashboard
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCompleted) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select AI Batch Action:',
                    style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _batchFeatures.length,
                    itemBuilder: (context, index) {
                      final item = _batchFeatures[index];
                      final isSelected = _selectedFeatureId == item['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          avatar: Icon(
                            _getIconData(item['icon']!),
                            size: 14,
                            color: isSelected ? Colors.white : AppColors.textMuted,
                          ),
                          label: Text(
                            item['title']!,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (val) {
                            setState(() => _selectedFeatureId = item['id']!);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              if (isCompleted) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All photos processed successfully! You can now save them to your device gallery in one tap.',
                          style: TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                children: [
                  if (!isCompleted)
                    Expanded(
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.brandGradient),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => provider.processBatch(_selectedFeatureId),
                          icon: const Icon(Icons.rocket_launch, size: 20),
                          label: Text(
                            'Process ${provider.batchImages.length} Images',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final success = await provider.saveBatchToGallery();
                            if (mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 All batch photos saved successfully to your gallery!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.download_done_rounded, size: 20, color: Colors.black),
                          label: const Text(
                            'Save All to Gallery',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingProgress(AppProvider provider) {
    final double percent = provider.batchOriginalBytes.isEmpty
        ? 0.0
        : (provider.batchCurrentIndex + 1) / provider.batchOriginalBytes.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 8,
                    color: AppColors.gold,
                    backgroundColor: AppColors.primary,
                  ),
                ),
                Text(
                  '${(percent * 100).round()}%',
                  style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text(
              provider.batchStatusMessage ?? 'Processing queue...',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Running high-speed server pipeline. Please keep the app open.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.gold, size: 24),
            SizedBox(width: 10),
            Text('Premium Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Batch AI Processing is a PRO exclusive feature. Upgrade to Premium now to process multiple photos in parallel with extreme cloud GPU acceleration and no limits!',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Go Premium'),
          ),
        ],
      ),
    );
  }
}