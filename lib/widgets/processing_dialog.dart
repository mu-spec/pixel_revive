import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/providers/app_provider.dart';

class ProcessingDialog extends StatefulWidget {
  const ProcessingDialog({super.key});

  @override
  State<ProcessingDialog> createState() => _ProcessingDialogState();
}

class _ProcessingDialogState extends State<ProcessingDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final message = provider.lastProcessingMessage.isNotEmpty
        ? provider.lastProcessingMessage
        : 'Preparing your enhanced photo...';
    final bool cloud = message.toLowerCase().contains('cloud') || message.toLowerCase().contains('fal');

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.58), blurRadius: 34, offset: const Offset(0, 18)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: cloud
                          ? const [Color(0xFF22D3EE), Color(0xFF7C3AED)]
                          : const [Color(0xFF10B981), Color(0xFF22D3EE)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (cloud ? AppColors.cyan : AppColors.success).withOpacity(0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    cloud ? Icons.cloud_sync_rounded : Icons.auto_fix_high_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                cloud ? 'Cloud AI Processing' : 'Enhancing Photo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.2,
                  height: 1.38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  height: 5,
                  width: 190,
                  child: LinearProgressIndicator(
                    backgroundColor: Color(0xFF1F2937),
                    color: AppColors.success,
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton.icon(
                  onPressed: () {
                    provider.cancelProcessing();
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
