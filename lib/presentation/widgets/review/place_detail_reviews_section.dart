import 'package:flutter/material.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/place_api_service.dart';
import 'create_review_modal.dart';
import 'review_item_card.dart';

class PlaceDetailReviewsSection extends StatefulWidget {
  final int placeId;
  final String placeName;
  final double avgRating;
  final int totalReviews;

  const PlaceDetailReviewsSection({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.avgRating,
    required this.totalReviews,
  });

  @override
  State<PlaceDetailReviewsSection> createState() => _PlaceDetailReviewsSectionState();
}

class _PlaceDetailReviewsSectionState extends State<PlaceDetailReviewsSection> {
  List<ReviewItemModel> _reviews = [];
  Map<String, int> _ratingBreakdown = {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
  late double _avgRating;
  late int _totalReviews;
  bool _isLoading = false;
  int? _selectedRatingFilter;

  bool _isAuthenticated = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _avgRating = widget.avgRating;
    _totalReviews = widget.totalReviews;
    _checkAuth();
    _fetchReviews();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await AuthService().isLoggedIn();
    final user = await AuthService().getCachedUser();
    if (mounted) {
      setState(() {
        _isAuthenticated = loggedIn;
        _currentUser = user;
      });
    }
  }

  Future<void> _fetchReviews({int? rating}) async {
    setState(() {
      _isLoading = true;
      _selectedRatingFilter = rating;
    });

    try {
      final res = await PlaceApiService().getPlaceReviews(
        widget.placeId,
        page: 1,
        pageSize: 30,
        rating: rating,
      );

      if (mounted && res.data != null) {
        setState(() {
          _reviews = res.data!.items;
          _ratingBreakdown = res.data!.ratingBreakdown;
          if (rating == null) {
            _totalReviews = res.data!.totalReviews;
            if (res.data!.avgRating > 0) {
              _avgRating = res.data!.avgRating;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[PlaceDetailReviewsSection] _fetchReviews error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleReviewAdded(ReviewItemModel newReview) {
    setState(() {
      _reviews = [newReview, ..._reviews];
      _totalReviews += 1;
      final starKey = newReview.rating.toString();
      _ratingBreakdown[starKey] = (_ratingBreakdown[starKey] ?? 0) + 1;
    });
  }

  void _handleReviewUpdated(ReviewItemModel updatedReview) {
    setState(() {
      _reviews = _reviews.map((r) => r.id == updatedReview.id ? updatedReview : r).toList();
    });
  }

  void _handleReviewDeleted(int reviewId) {
    final target = _reviews.where((r) => r.id == reviewId).firstOrNull;
    setState(() {
      _reviews = _reviews.where((r) => r.id != reviewId).toList();
      _totalReviews = (_totalReviews - 1).clamp(0, 999999);
      if (target != null) {
        final starKey = target.rating.toString();
        _ratingBreakdown[starKey] = ((_ratingBreakdown[starKey] ?? 1) - 1).clamp(0, 999999);
      }
    });
  }

  void _openWriteReviewModal() {
    CreateReviewModal.show(
      context,
      placeId: widget.placeId,
      placeName: widget.placeName,
      onReviewAdded: _handleReviewAdded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayAvg = _avgRating > 0 ? _avgRating : 5.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header (Title + Write review button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF059669)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đánh giá & Phản hồi cộng đồng ($_totalReviews)',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Trải nghiệm thực tế và cảm nhận từ các du khách đã từng ghé thăm',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              ElevatedButton.icon(
                onPressed: _openWriteReviewModal,
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Viết đánh giá',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Rating Breakdown Card (matching Share_Locations PlaceDetailReviews.tsx)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                // Left Column: Big score + stars
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayAvg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: i < displayAvg.round() ? const Color(0xFFF59E0B) : const Color(0xFFD1D5DB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dựa trên $_totalReviews lượt',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right Column: 5 progress bars
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final starStr = star.toString();
                      final count = _ratingBreakdown[starStr] ?? 0;
                      final pct = _totalReviews > 0 ? (count / _totalReviews).clamp(0.0, 1.0) : 0.0;
                      final isSelected = _selectedRatingFilter == star;

                      return GestureDetector(
                        onTap: () {
                          if (_selectedRatingFilter == star) {
                            _fetchReviews();
                          } else {
                            _fetchReviews(rating: star);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: Text(
                                  '$star sao',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Tất cả ($_totalReviews)',
                  isSelected: _selectedRatingFilter == null,
                  onTap: () => _fetchReviews(),
                ),
                const SizedBox(width: 6),
                ...[5, 4, 3, 2, 1].map((star) {
                  final count = _ratingBreakdown[star.toString()] ?? 0;
                  final isSelected = _selectedRatingFilter == star;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildFilterChip(
                      label: '$star ★ ($count)',
                      isSelected: isSelected,
                      onTap: () {
                        if (isSelected) {
                          _fetchReviews();
                        } else {
                          _fetchReviews(rating: star);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Review Cards List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                  ),
                ),
              ),
            )
          else if (_reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 36, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 10),
                  Text(
                    _selectedRatingFilter != null
                        ? 'Chưa có đánh giá $_selectedRatingFilter sao nào.'
                        : 'Chưa có đánh giá nào cho địa điểm này.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hãy là người đầu tiên chia sẻ cảm nhận!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            )
          else
            ..._reviews.map(
              (r) => ReviewItemCard(
                key: ValueKey(r.id),
                review: r,
                isAuthenticated: _isAuthenticated,
                currentUser: _currentUser,
                onReviewUpdated: _handleReviewUpdated,
                onReviewDeleted: _handleReviewDeleted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF059669) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
