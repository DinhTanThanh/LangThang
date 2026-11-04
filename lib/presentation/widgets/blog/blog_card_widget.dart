import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../screens/profile/user_profile_screen.dart';

class BlogCardWidget extends StatelessWidget {
  final BlogModel blog;
  final VoidCallback onTap;
  final VoidCallback? onQuickPreview;
  final VoidCallback? onToggleLike;
  final VoidCallback? onToggleSave;

  const BlogCardWidget({
    super.key,
    required this.blog,
    required this.onTap,
    this.onQuickPreview,
    this.onToggleLike,
    this.onToggleSave,
  });

  Widget _buildCoverImage() {
    final url = blog.imageUrl.trim();
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.menu_book_rounded, color: Color(0xFF065F46), size: 36),
        ),
      );
    }

    if (url.startsWith('data:image')) {
      try {
        final commaIndex = url.indexOf(',');
        final b64 = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, color: Color(0xFF065F46), size: 36),
            ),
          ),
        );
      } catch (_) {}
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.menu_book_rounded, color: Color(0xFF065F46), size: 36),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Header (16:10 matching Share_Locations)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _buildCoverImage(),
                  ),

                  // Category Badge Floating on Top-Left
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        blog.category.isNotEmpty ? blog.category : 'Cẩm nang du lịch',
                        style: const TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Status Badge Floating on Top-Right (if Pending or Draft)
                  if (blog.status == 2 || blog.status == 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: blog.status == 2 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: blog.status == 2 ? const Color(0xFFFDE68A) : const Color(0xFFCBD5E1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              blog.status == 2 ? Icons.schedule_rounded : Icons.edit_note_rounded,
                              size: 12,
                              color: blog.status == 2 ? const Color(0xFFB45309) : const Color(0xFF475569),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              blog.status == 2 ? 'Đang chờ duyệt' : 'Bản nháp',
                              style: TextStyle(
                                color: blog.status == 2 ? const Color(0xFF92400E) : const Color(0xFF334155),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Quick Preview Button (Bottom Left)
                  if (onQuickPreview != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: InkWell(
                        onTap: onQuickPreview,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.visibility_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Xem nhanh', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Read Time Badge (Bottom Right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 10.5, color: Colors.white),
                          const SizedBox(width: 3.5),
                          Text(
                            '${blog.readTimeMinutes > 0 ? blog.readTimeMinutes : 5} phút đọc',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Card Content Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with ArrowUpRight
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            blog.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_outward_rounded,
                          size: 17,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),

                    if (blog.summary.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        blog.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.45,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Date & Views Row (Matching Screenshot 2)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          blog.publishedDate.isNotEmpty ? blog.publishedDate : '24/09/2026',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                        const SizedBox(width: 8),
                        const Icon(Icons.remove_red_eye_outlined, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          '${blog.likesCount * 3 + 12}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Author & Read Info Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Author Avatar & Name
                        Expanded(
                          child: InkWell(
                            onTap: () => UserProfileScreen.navigate(
                              context,
                              userId: blog.author.id.isNotEmpty ? blog.author.id : (int.tryParse(blog.id) ?? 1),
                              userName: blog.authorName.isNotEmpty ? blog.authorName : 'Tác giả',
                              userAvatar: blog.authorAvatar.isNotEmpty ? blog.authorAvatar : null,
                              userRank: 'Tác giả cẩm nang',
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              children: [
                                if (blog.authorAvatar.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      blog.authorAvatar,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
                                    ),
                                  )
                                else
                                  _buildFallbackAvatar(),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    blog.authorName.isNotEmpty ? blog.authorName : 'Thổ Địa LangThang',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Social Actions (Likes & Detail Link)
                        Row(
                          children: [
                            if (onToggleLike != null)
                              InkWell(
                                onTap: onToggleLike,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        blog.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        size: 15,
                                        color: blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${blog.likesCount}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            const Row(
                              children: [
                                Text(
                                  'Chi tiết',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 15, color: Color(0xFF059669)),
                              ],
                            ),
                          ],
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
  }

  Widget _buildFallbackAvatar() {
    final initial = blog.authorName.isNotEmpty ? blog.authorName[0].toUpperCase() : 'T';
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
