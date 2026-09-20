import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/disease_result.dart';

/// AI Disease Detection screen — capture/upload leaf image.
class DiseaseDetectionScreen extends ConsumerWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(diseaseDetectionProvider);
    final notifier = ref.read(diseaseDetectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Disease Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan History',
            onPressed: () => context.push('/disease/history'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 40, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 16),
                  Text('Detect Crop Diseases', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a leaf image and use AI-powered analysis to identify crop diseases.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Capture Buttons ──
          if (state.status == DiseaseDetectionStatus.idle || state.status == DiseaseDetectionStatus.imageSelected) ...[
            Row(
              children: [
                Expanded(
                  child: _CaptureButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Take Photo',
                    onTap: () => _pickImage(context, ref, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CaptureButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Upload from Gallery',
                    onTap: () => _pickImage(context, ref, ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Image Preview ──
            if (state.imagePath != null) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.file(
                        File(state.imagePath!),
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.image_rounded, size: 18, color: AppColors.primaryGreen),
                          const SizedBox(width: 8),
                          Text('Leaf image selected', style: theme.textTheme.bodyMedium),
                          const Spacer(),
                          TextButton(
                            onPressed: () => notifier.reset(),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () async {
                  await notifier.analyzeImage();
                  if (context.mounted) {
                    final st = ref.read(diseaseDetectionProvider);
                    if (st.status == DiseaseDetectionStatus.success) {
                      context.push('/disease/result');
                    }
                  }
                },
                icon: const Icon(Icons.search_rounded),
                label: const Text('Analyze Disease'),
              ),
            ],
          ],

          // ── Loading States ──
          if (state.status == DiseaseDetectionStatus.uploading ||
              state.status == DiseaseDetectionStatus.analyzing) ...[
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(strokeWidth: 4),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      state.status == DiseaseDetectionStatus.uploading
                          ? 'Uploading image...'
                          : 'Analyzing image with AI...',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please wait...',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (state.status == DiseaseDetectionStatus.uploading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: state.uploadProgress),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── Error State ──
          if (state.status == DiseaseDetectionStatus.error) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.statusCriticalBg,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.statusCritical, size: 32),
                    const SizedBox(height: 8),
                    Text(state.errorMessage ?? 'Analysis failed. Please try again.',
                        style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => notifier.reset(),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    if (image != null) {
      ref.read(diseaseDetectionProvider.notifier).selectImage(image.path);
    }
  }
}

class _CaptureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CaptureButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: AppColors.primaryGreen),
              ),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
