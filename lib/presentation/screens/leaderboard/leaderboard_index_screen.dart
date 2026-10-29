import 'package:flutter/material.dart';
import '../../../data/models/ranking_model.dart';
import '../../../data/services/ranking_api_service.dart';
import 'leaderboard_detail_screen.dart';

class LeaderboardIndexScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const LeaderboardIndexScreen({super.key, this.onNavigateTab});

  @override
  State<LeaderboardIndexScreen> createState() => _LeaderboardIndexScreenState();
}

class _LeaderboardIndexScreenState extends State<LeaderboardIndexScreen> {
  final RankingApiService _rankingApiService = RankingApiService();

  bool _isLoading = true;
  String? _errorMessage;
  RankingOverviewData? _overviewData;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _rankingApiService.getRankingOverview();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _overviewData = res.data;
        } else {
          _errorMessage = res.message.isNotEmpty ? res.message : 'Không thể tải dữ liệu trang tổng quan.';
        }
      });
    }
  }

  void _onCategoryTap(RankingOverviewCategory cat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaderboardDetailScreen(
          category: cat,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Bảng xếp hạng',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOverview,
        color: const Color(0xFF059669),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF059669)),
            SizedBox(height: 12),
            Text(
              'Đang nạp dữ liệu bảng xếp hạng...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _overviewData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFD97706)),
              const SizedBox(height: 12),
              const Text(
                'Không thể nạp dữ liệu Bảng Xếp Hạng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _overviewData;
    final title = data?.title ?? 'Bảng Xếp Hạng Du Lịch Xuất Sắc Nhất 2026';
    final subtitle = data?.subtitle ??
        'Hàng năm, chúng tôi tôn vinh những điểm đến, khách sạn, nhà hàng và hoạt động du lịch yêu thích nhất của du khách dựa trên các đánh giá thực tế được thu thập qua 12 tháng.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      children: [
        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF064E3B),
            letterSpacing: -0.6,
            height: 1.25,
          ),
        ),

        const SizedBox(height: 14),

        // Intro paragraphs (Matching Screenshot 1)
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF334155),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Những người chiến thắng năm 2026 là sự tôn vinh tất cả những chuyến đi đáng nhớ của chúng ta trong năm qua tất cả những vùng đất mới lạ chúng ta đã khám phá và tất cả những lần chúng ta nói "đồng ý" với những cuộc phiêu lưu mới. Chúng tôi sẽ lần lượt công bố danh sách đoạt giải theo từng hạng mục trong năm, hãy tiếp tục theo dõi để cập nhật các thông tin mới nhất.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF334155),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        // Category Cards List
        if (data?.categories != null && data!.categories.isNotEmpty)
          ...data.categories.map((cat) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCategoryCard(cat),
              )),
      ],
    );
  }

  Widget _buildCategoryCard(RankingOverviewCategory cat) {
    return GestureDetector(
      onTap: () => _onCategoryTap(cat),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover Image
              if (cat.coverImageUrl != null && cat.coverImageUrl!.isNotEmpty)
                Image.network(
                  cat.coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF0F172A),
                  ),
                )
              else
                Container(color: const Color(0xFF0F172A)),

              // Dark Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),

              // Title at bottom left
              Positioned(
                bottom: 18,
                left: 18,
                right: 18,
                child: Text(
                  cat.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
