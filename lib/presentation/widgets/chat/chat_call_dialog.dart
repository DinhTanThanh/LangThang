import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ChatCallDialog extends StatefulWidget {
  final String partnerName;
  final String? partnerAvatar;
  final bool isVideoCall;

  const ChatCallDialog({
    super.key,
    required this.partnerName,
    this.partnerAvatar,
    this.isVideoCall = false,
  });

  @override
  State<ChatCallDialog> createState() => _ChatCallDialogState();
}

class _ChatCallDialogState extends State<ChatCallDialog> with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOff = false;
  int _callSeconds = 0;
  Timer? _timer;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    // Simulate connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isConnected = true);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _callSeconds++);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Call Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isVideoCall ? Icons.videocam_rounded : Icons.call_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isVideoCall ? 'Cuộc gọi Video HD' : 'Cuộc gọi thoại',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Middle: Partner Avatar & Name
            Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.partnerAvatar != null && widget.partnerAvatar!.isNotEmpty
                      ? Image.network(widget.partnerAvatar!, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 50, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.partnerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isConnected ? _formatDuration(_callSeconds) : 'Đang kết nối tín hiệu...',
                  style: TextStyle(
                    color: _isConnected ? const Color(0xFF34D399) : Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Bottom: Action Buttons
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    IconButton(
                      icon: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: _isMuted ? Colors.red.shade400 : Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                    ),

                    // Speaker Button
                    IconButton(
                      icon: Icon(_isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                      color: Colors.white,
                      style: IconButton.styleFrom(
                        backgroundColor: _isSpeaker ? AppColors.primary : Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => setState(() => _isSpeaker = !_isSpeaker),
                    ),

                    // Video Toggle (if video call)
                    if (widget.isVideoCall)
                      IconButton(
                        icon: Icon(_isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: _isVideoOff ? Colors.red.shade400 : Colors.white.withValues(alpha: 0.15),
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // End Call Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
                  label: const Text(
                    'Kết thúc cuộc gọi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
