import 'package:flutter/material.dart';

class MediaLightboxModal extends StatelessWidget {
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'

  const MediaLightboxModal({
    super.key,
    required this.mediaUrl,
    this.mediaType = 'image',
  });

  static void show(BuildContext context, {required String mediaUrl, String mediaType = 'image'}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => MediaLightboxModal(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Content
          Center(
            child: isVideo ? _buildVideoViewer(context) : _buildImageViewer(context),
          ),

          // Close button
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black.withValues(alpha: 0.65),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: InteractiveViewer(
        maxScale: 4.0,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded, color: Color(0xFF9CA3AF), size: 48),
                SizedBox(height: 12),
                Text(
                  'Không thể tải hình ảnh này',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewer(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.videocam_rounded, color: Color(0xFF4B5563), size: 64),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.9),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mediaUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Video đánh giá trải nghiệm thực tế',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
