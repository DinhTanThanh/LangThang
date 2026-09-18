import 'package:flutter/material.dart';

class BlogHeadingItem {
  final int index;
  final String title;
  final int level; // 2 for H2, 3 for H3

  const BlogHeadingItem({
    required this.index,
    required this.title,
    required this.level,
  });
}

class BlogTableOfContentsSheet extends StatelessWidget {
  final List<BlogHeadingItem> headings;
  final Function(int index) onSelectHeading;

  const BlogTableOfContentsSheet({
    super.key,
    required this.headings,
    required this.onSelectHeading,
  });

  static void show(
    BuildContext context, {
    required List<BlogHeadingItem> headings,
    required Function(int index) onSelectHeading,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BlogTableOfContentsSheet(
        headings: headings,
        onSelectHeading: onSelectHeading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.format_list_bulleted_rounded, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Mục lục bài viết',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Headings List
          if (headings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Bài viết không có đề mục phụ.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: headings.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF9FAFB)),
                itemBuilder: (context, index) {
                  final heading = headings[index];
                  final isSub = heading.level > 2;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onSelectHeading(heading.index);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isSub ? 28 : 8,
                        right: 8,
                        top: 10,
                        bottom: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSub ? const Color(0xFF9CA3AF) : const Color(0xFF059669),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              heading.title,
                              style: TextStyle(
                                fontSize: isSub ? 12.5 : 13.5,
                                fontWeight: isSub ? FontWeight.w600 : FontWeight.w800,
                                color: isSub ? const Color(0xFF4B5563) : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFD1D5DB)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
