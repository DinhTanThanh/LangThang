import 'package:flutter/material.dart';
import '../../../data/models/blog_model.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              // Cover Image Header
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      blog.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF047857),
                        child: const Center(
                          child: Icon(Icons.menu_book_rounded, color: Colors.white54, size: 32),
                        ),
                      ),
                    ),
                  ),

                  // Category Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        blog.category,
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Bookmark Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          blog.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 16,
                          color: blog.isSaved ? const Color(0xFF34D399) : Colors.white,
                        ),
                        onPressed: onToggleSave,
                      ),
                    ),
                  ),

                  // Quick Preview Button
                  if (onQuickPreview != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: InkWell(
                        onTap: onQuickPreview,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
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

                  // Read time
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${blog.readTimeMinutes} phút đọc',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Excerpt
                    Text(
                      blog.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    const SizedBox(height: 10),

                    // Author & Social Counters
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Author
                        Expanded(
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF059669),
                                backgroundImage: blog.authorAvatar.isNotEmpty
                                    ? NetworkImage(blog.authorAvatar)
                                    : null,
                                child: blog.authorAvatar.isEmpty
                                    ? Text(
                                        blog.authorName.isNotEmpty ? blog.authorName[0].toUpperCase() : 'A',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      blog.authorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                                    ),
                                    Text(
                                      blog.publishedDate,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Likes & Comments
                        Row(
                          children: [
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
                                      color: blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${blog.likesCount}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: blog.isLiked ? const Color(0xFFE11D48) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF9CA3AF)),
                                const SizedBox(width: 3),
                                Text(
                                  '${blog.commentsCount}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                                ),
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
}
