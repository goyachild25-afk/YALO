import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';

/// Grid reutilizable para subir 0..maxPhotos fotos a un bucket de Supabase.
///
/// Envía cada archivo al bucket bajo el path `<folder>/<uuid>.jpg` y llama
/// a `onChange(urls)` con los URLs públicos actualizados.
class PhotoPickerGrid extends StatefulWidget {
  final String bucket;
  final String folder;
  final int maxPhotos;
  final List<String> initialUrls;
  final ValueChanged<List<String>> onChange;
  final String addLabel;

  const PhotoPickerGrid({
    super.key,
    required this.bucket,
    required this.folder,
    required this.onChange,
    this.maxPhotos = 5,
    this.initialUrls = const [],
    this.addLabel = 'Agregar foto',
  });

  @override
  State<PhotoPickerGrid> createState() => _PhotoPickerGridState();
}

class _PhotoPickerGridState extends State<PhotoPickerGrid> {
  late List<String> _urls;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _urls = List.of(widget.initialUrls);
  }

  Future<void> _pick() async {
    if (_urls.length >= widget.maxPhotos) return;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${widget.folder}/$ts-${file.name}';
      final url = await SupabaseService.uploadFile(
        bucket: widget.bucket,
        path: path,
        bytes: bytes,
      );
      setState(() {
        _urls = [..._urls, url];
      });
      widget.onChange(_urls);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos subir la foto. Intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int i) {
    setState(() => _urls = List.of(_urls)..removeAt(i));
    widget.onChange(_urls);
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _urls.length < widget.maxPhotos && !_uploading;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < _urls.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _urls[i],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.surfaceVariant,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.errorLight,
                    child: const Icon(Icons.error_outline,
                        color: AppColors.error),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => _remove(i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        if (canAdd)
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    style: BorderStyle.solid,
                    width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    widget.addLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_uploading)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
