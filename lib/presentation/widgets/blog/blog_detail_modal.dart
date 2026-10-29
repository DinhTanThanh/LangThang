import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';
import '../../screens/blog/blog_detail_screen.dart';
import '../../screens/profile/user_profile_screen.dart';

class BlogDetailModal extends StatelessWidget {
  final BlogModel blog;
  final VoidCallback? onToggleLike;
  final VoidCallback? onToggleSave;

  const BlogDetailModal({
    super.key,
    required this.blog,
    this.onToggleLike,
    this.onToggleSave,
  });

  static void show(
    BuildContext context, {
    required BlogModel blog,
    VoidCallback? onToggleLike,
    VoidCallback? onToggleSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlogDetailModal(
        blog: blog,
        onToggleLike: onToggleLike,
        onToggleSave: onToggleSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    blog.category,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF6B7280)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Đã sao chép liên kết bài viết!'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    blog.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Author Info
                  InkWell(
                    onTap: () {
                      Navigator.pop(context); // close modal first
                      UserProfileScreen.navigate(
                        context,
                        userId: blog.author.id.isNotEmpty ? blog.author.id : null,
                        userName: blog.authorName,
                        userAvatar: blog.authorAvatar,
                        userBio: blog.author.bio,
                        userRank: blog.author.role,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF059669),
                          backgroundImage: blog.authorAvatar.isNotEmpty
                              ? NetworkImage(blog.authorAvatar)
                              : null,
                          child: blog.authorAvatar.isEmpty
                              ? Text(
                                  blog.authorName.isNotEmpty ? blog.authorName[0].toUpperCase() : 'A',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blog.authorName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                            Text(
                              '${blog.publishedDate} • ${blog.readTimeMinutes} phút đọc',
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cover Image
                  if (blog.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: () {
                          final url = blog.imageUrl.trim();
                          if (url.startsWith('data:image')) {
                            try {
                              final commaIdx = url.indexOf(',');
                              final b64 = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
                              final bytes = base64Decode(b64);
                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: const Color(0xFF059669),
                                  child: const Center(
                                    child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 36),
                                  ),
                                ),
                              );
                            } catch (_) {}
                          }
                          return Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF059669),
                              child: const Center(
                                child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 36),
                              ),
                            ),
                          );
                        }(),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Summary
                  if (blog.summary.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(left: BorderSide(color: Color(0xFF059669), width: 3)),
                      ),
                      child: Text(
                        blog.summary,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF374151),
                          height: 1.45,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Full Content snippet
                  if (blog.content != null && blog.content!.isNotEmpty)
                    Text(
                      blog.content!.replaceAll(RegExp(r'#+\s'), '').replaceAll('> ', ''),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF374151),
                        height: 1.6,
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Full Screen Reader Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BlogDetailScreen(blog: blog)),
                        );
                      },
                      icon: const Icon(Icons.chrome_reader_mode_rounded, size: 16),
                      label: const Text(
                        'Đọc toàn bộ bài viết & Mục lục',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
