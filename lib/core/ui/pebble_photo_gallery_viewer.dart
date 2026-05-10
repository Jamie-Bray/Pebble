import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';

class PebbleGalleryPhoto {
  final String id;
  final String storedPath;
  final String title;
  final String? subtitle;

  const PebbleGalleryPhoto({
    required this.id,
    required this.storedPath,
    required this.title,
    this.subtitle,
  });
}

class PebblePhotoGalleryViewer extends StatefulWidget {
  const PebblePhotoGalleryViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.resolvePhotoFile,
    this.bottomBuilder,
  });

  final List<PebbleGalleryPhoto> photos;
  final int initialIndex;
  final Future<File?> Function(String storedPath) resolvePhotoFile;
  final Widget Function(BuildContext context, int index)? bottomBuilder;

  static Future<void> open(
    BuildContext context, {
    required List<PebbleGalleryPhoto> photos,
    required int initialIndex,
    required Future<File?> Function(String storedPath) resolvePhotoFile,
    Widget Function(BuildContext context, int index)? bottomBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PebblePhotoGalleryViewer(
          photos: photos,
          initialIndex: initialIndex,
          resolvePhotoFile: resolvePhotoFile,
          bottomBuilder: bottomBuilder,
        ),
      ),
    );
  }

  @override
  State<PebblePhotoGalleryViewer> createState() =>
      _PebblePhotoGalleryViewerState();
}

class _PebblePhotoGalleryViewerState extends State<PebblePhotoGalleryViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.photos[_currentIndex];
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  const PebbleBackButton(),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentIndex + 1} of ${widget.photos.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.photos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final photo = widget.photos[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: _PebbleGalleryPhotoFrame(
                            storedPath: photo.storedPath,
                            resolvePhotoFile: widget.resolvePhotoFile,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (current.subtitle != null &&
                      current.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      current.subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: colorScheme.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                  if (widget.bottomBuilder != null) ...[
                    const SizedBox(height: 16),
                    widget.bottomBuilder!(context, _currentIndex),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PebbleGalleryPhotoFrame extends StatelessWidget {
  const _PebbleGalleryPhotoFrame({
    required this.storedPath,
    required this.resolvePhotoFile,
  });

  final String storedPath;
  final Future<File?> Function(String storedPath) resolvePhotoFile;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<File?>(
      future: resolvePhotoFile(storedPath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return Center(child: Image.file(file, fit: BoxFit.contain));
        }

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 0.36),
              ),
              const SizedBox(height: 12),
              Text(
                'Photo unavailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
