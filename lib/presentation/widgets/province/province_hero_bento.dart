import 'package:flutter/material.dart';
import '../../../data/models/province_landing_model.dart';
import '../../../data/models/region_landing_model.dart';

class ProvinceHeroBento extends StatefulWidget {
  final ProvinceLandingModel data;

  const ProvinceHeroBento({
    super.key,
    required this.data,
  });

  @override
  State<ProvinceHeroBento> createState() => _ProvinceHeroBentoState();
}

class _ProvinceHeroBentoState extends State<ProvinceHeroBento> {
  int _currentIdx = 0;
  bool _isExpanded = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePrev() {
    final images = widget.data.heroImages;
    if (images.isEmpty) return;
    final nextIdx = (_currentIdx == 0) ? images.length - 1 : _currentIdx - 1;
    _pageController.animateToPage(
      nextIdx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _handleNext() {
    final images = widget.data.heroImages;
    if (images.isEmpty) return;
    final nextIdx = (_currentIdx == images.length - 1) ? 0 : _currentIdx + 1;
    _pageController.animateToPage(
      nextIdx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final images = data.heroImages.isNotEmpty
        ? data.heroImages
        : [
            RegionHeroImage(
              url: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?q=80&w=1200&auto=format&fit=crop',
              title: data.province.name,
              location: data.province.name,
            ),
          ];

    final regionText = data.province.regionName != null && data.province.regionName!.isNotEmpty
        ? data.province.regionName!
        : 'Việt Nam';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Text Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.province.name}, $regionText',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1C1917),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.heroHeadline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF44403C),
                  height: 1.35,
                ),
              ),
              if (data.heroSubheadline.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  data.heroSubheadline,
                  maxLines: _isExpanded ? null : 2,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF78716C),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Thu gọn' : 'Đọc thêm',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: const Color(0xFF1C1917),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 2. Bento Hero Slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: const Color(0xFF1C1917),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (idx) => setState(() => _currentIdx = idx),
                      itemBuilder: (context, index) {
                        final img = images[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              img.url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF292524),
                                child: const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.white30, size: 48),
                                ),
                              ),
                            ),
                            // Gradient overlay
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0x99000000),
                                    Colors.transparent,
                                    Color(0x4D000000),
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // Prev Button
                    if (images.length > 1)
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _handlePrev,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Next Button
                    if (images.length > 1)
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: _handleNext,
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Dot Indicators (Bottom Center)
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (dotIdx) {
                            final isSelected = dotIdx == _currentIdx;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              height: 6,
                              width: isSelected ? 20 : 6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),

                    // Image Counter (Bottom Right)
                    if (images.length > 1)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_outlined, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentIdx + 1} / ${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
