import 'package:flutter/material.dart';

class BlogHeadingItem {
  final int index;
  final String title;
  final int level; // 1 for H1, 2 for H2, 3 for H3

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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Row (Matching Share_Locations BlogTableOfContents)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: Color(0xFF065F46), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'MỤC LỤC BÀI VIẾT (${headings.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Headings List
          if (headings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Bài viết không có đề mục phụ.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: headings.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final heading = headings[index];
                  final isH1 = heading.level == 1;
                  final isH2 = heading.level == 2;

                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      onSelectHeading(heading.index);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: EdgeInsets.only(
                        left: isH1 ? 8 : (isH2 ? 16 : 26),
                        right: 10,
                        top: 8,
                        bottom: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isH1 ? const Color(0xFFECFDF5).withValues(alpha: 0.6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Level badge (H1, H2, H3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isH1
                                  ? const Color(0xFF065F46)
                                  : isH2
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'H${heading.level}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isH1 ? Colors.white : (isH2 ? const Color(0xFF334155) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              heading.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isH1 ? 13 : (isH2 ? 12.5 : 11.5),
                                fontWeight: isH1 ? FontWeight.w800 : (isH2 ? FontWeight.w600 : FontWeight.normal),
                                color: isH1 ? const Color(0xFF064E3B) : const Color(0xFF1E293B),
                                height: 1.3,
                              ),
                            ),
                          ),
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
