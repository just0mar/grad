import 'dart:io';
import 'package:flutter/material.dart';
import '../services/file_cache_service.dart';

class CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  const CachedImageWidget({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<CachedImageWidget> {
  File? _imageFile;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final file = await FileCacheService.instance.getImage(widget.imageUrl);
      if (!mounted) return;
      setState(() {
        _imageFile = file;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_hasError || _imageFile == null) {
      return widget.errorWidget ?? const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
    return Image.file(
      _imageFile!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
    );
  }
}
