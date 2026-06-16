import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class BootstrapImageWidget extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const BootstrapImageWidget(
      {super.key, required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // Check if it's a network URL
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    if (isNetwork) {
      if (kIsWeb) {
        final String viewType = 'bootstrap-image-${url.hashCode}-${fit.index}';
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
          final img = html.ImageElement()
            ..src = url
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';
          return img;
        });
        return HtmlElementView(viewType: viewType);
      }
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    } else {
      // Assume Asset
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset image: $url -> $error');
          return Container(
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
        },
      );
    }
  }
}
