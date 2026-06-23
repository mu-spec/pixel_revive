import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/providers/app_provider.dart';

class SavedImagesTab extends StatefulWidget {
  const SavedImagesTab({super.key});

  @override
  State<SavedImagesTab> createState() => _SavedImagesTabState();
}

class _SavedImagesTabState extends State<SavedImagesTab> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _selectedPaths.clear();
  }

  String _getFileDateString(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final lastMod = file.lastModifiedSync();
        return "${lastMod.year}-${lastMod.month.toString().padLeft(2, '0')}-${lastMod.day.toString().padLeft(2, '0')} "
            "${lastMod.hour.toString().padLeft(2, '0')}:${lastMod.minute.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return "Unknown Date";
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPaths.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected(AppProvider provider) async {
    final list = List<String>.from(_selectedPaths);
    for (var path in list) {
      await provider.removeFromHistory(path);
    }
    _clearSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected photos deleted successfully.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteAll(AppProvider provider) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete All Saved Images?'),
        content: const Text(
          'This will permanently delete all your saved AI enhanced creations from both the history and your device storage. This action cannot be undone.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final list = List<String>.from(provider.creationHistory);
              for (var path in list) {
                await provider.removeFromHistory(path);
              }
              _clearSelection();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All creations deleted from disk.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('${_selectedPaths.length} Selected', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              leading: IconButton(
                icon: const Icon(Icons.close, color: AppColors.text),
                onPressed: _clearSelection,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Delete Selected',
                  onPressed: () => _deleteSelected(provider),
                ),
              ],
            )
          : AppBar(
              title: const Text('My Creations', style: TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                if (provider.creationHistory.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: AppColors.textMuted),
                    tooltip: 'Delete All History',
                    onPressed: () => _deleteAll(provider),
                  ),
              ],
            ),
      body: provider.creationHistory.isEmpty
          ? _buildEmptyState()
          : _buildCreationsGrid(provider),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.04), width: 1.5),
              ),
              child: const Icon(Icons.photo_library_outlined, size: 52, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Creations',
              style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your enhanced masterpieces will appear here immediately after you save them to your gallery.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreationsGrid(AppProvider provider) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.76,
      ),
      itemCount: provider.creationHistory.length,
      itemBuilder: (context, index) {
        final path = provider.creationHistory[index];
        final isSelected = _selectedPaths.contains(path);
        final file = File(path);

        if (!file.existsSync()) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelect(path);
            } else {
              _showFullscreenHistoryImage(context, provider, path);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedPaths.add(path);
              });
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : Colors.black.withOpacity(0.05),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                        if (_isSelectionMode)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isSelected ? AppColors.accent : Colors.white70,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enhanced Photo',
                          style: TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled_outlined, color: AppColors.success, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _getFileDateString(path),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
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

  void _showFullscreenHistoryImage(BuildContext context, AppProvider provider, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: BorderSide(color: Colors.black.withOpacity(0.1)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await provider.shareImage();
                    },
                    icon: const Icon(Icons.share, size: 18, color: Colors.white),
                    label: const Text('Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}