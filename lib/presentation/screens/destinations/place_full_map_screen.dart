import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/place_model.dart';
import '../../widgets/mapbox_interactive_map.dart';
import 'map_directions_screen.dart';
import 'travel_map_screen.dart';

class PlaceFullMapScreen extends StatefulWidget {
  final PlaceModel place;
  final String mapboxToken;

  const PlaceFullMapScreen({
    super.key,
    required this.place,
    this.mapboxToken =
        'pk.eyJ1IjoiZGluaHRhbnRoYW5oMTkiLCJhIjoiY210bnNsZ2V2MG14NzJ5cHN1ZjhzMjU3MiJ9.qM8oAp0Hb9ThJlBzvn0Qtw',
  });

  @override
  State<PlaceFullMapScreen> createState() => _PlaceFullMapScreenState();
}

class _PlaceFullMapScreenState extends State<PlaceFullMapScreen> {
  String _currentStyle = 'mapbox/streets-v12';
  final GlobalKey<MapboxInteractiveMapState> _mapKey =
      GlobalKey<MapboxInteractiveMapState>();

  final List<Map<String, String>> _mapStyles = [
    {'id': 'mapbox/streets-v12', 'name': 'Đường phố', 'icon': 'map'},
    {'id': 'mapbox/satellite-streets-v12', 'name': 'Vệ tinh', 'icon': 'satellite'},
    {'id': 'mapbox/outdoors-v12', 'name': 'Ngoài trời', 'icon': 'terrain'},
    {'id': 'mapbox/dark-v11', 'name': 'Tối', 'icon': 'dark_mode'},
  ];

  late double _lat;
  late double _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.place.latitude != 0.0 ? widget.place.latitude : 21.0285;
    _lng = widget.place.longitude != 0.0 ? widget.place.longitude : 105.8542;
  }

  void _zoomIn() {
    _mapKey.currentState?.zoomIn();
  }

  void _zoomOut() {
    _mapKey.currentState?.zoomOut();
  }

  void _resetCenter() {
    _mapKey.currentState?.setCenter(_lat, _lng, 15.0);
  }

  void _copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
            SizedBox(width: 8),
            Text('Đã sao chép tọa độ GPS vào bộ nhớ tạm!'),
          ],
        ),
        backgroundColor: const Color(0xFF111827),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Stack(
        children: [
          // 1. Full Screen Continuous Dynamic Mapbox Tile Map
          Positioned.fill(
            child: MapboxInteractiveMap(
              key: _mapKey,
              initialLat: _lat,
              initialLng: _lng,
              initialZoom: 15.0,
              styleId: _currentStyle,
              token: widget.mapboxToken,
              destLat: _lat,
              destLng: _lng,
              destTitle: place.name,
            ),
          ),

          // 2. Top Header Navigation Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back Button
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title Pill
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Search / Full Explore Button
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TravelMapScreen(
                          initialPlace: place,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Right Map Controls (Zoom, Re-center, Layer Switcher)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 70,
            child: Column(
              children: [
                // Zoom In
                _buildFloatingButton(
                  icon: Icons.add,
                  tooltip: 'Phóng to',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),

                // Zoom Out
                _buildFloatingButton(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),

                // Center Reset
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Căn giữa vị trí',
                  iconColor: const Color(0xFF059669),
                  onTap: _resetCenter,
                ),
                const SizedBox(height: 8),

                // Map Style Switcher Modal Trigger
                _buildFloatingButton(
                  icon: Icons.layers_outlined,
                  tooltip: 'Đổi kiểu bản đồ',
                  iconColor: const Color(0xFF0284C7),
                  onTap: () => _showStyleSelector(context),
                ),
              ],
            ),
          ),

          // 4. Bottom Info Card with Place Details & Actions
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row: Name, Category, Rating
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place Thumbnail
                      if (place.img.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            place.img,
                            width: 54,
                            height: 54,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 54,
                              height: 54,
                              color: const Color(0xFFF3F4F6),
                              child: const Icon(
                                Icons.image_outlined,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                        ),
                      if (place.img.isNotEmpty) const SizedBox(width: 12),

                      // Name and details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (place.category.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      place.category,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 16,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  place.rating > 0
                                      ? place.rating.toStringAsFixed(1)
                                      : '5.0',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Full Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 15,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          place.location.isNotEmpty
                              ? place.location
                              : (place.province.isNotEmpty
                                  ? place.province
                                  : 'Việt Nam'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4B5563),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // GPS Coordinates chip
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'GPS: ${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _copyCoordinates(_lat, _lng),
                        child: const Text(
                          'Sao chép',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons: Directions & Share
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MapDirectionsScreen(place: place),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.directions_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Chỉ đường đến đây',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF1F2937),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: iconColor),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
        padding: EdgeInsets.zero,
      ),
    );
  }

  void _showStyleSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chọn kiểu hiển thị bản đồ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._mapStyles.map((s) {
                  final isSelected = _currentStyle == s['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF059669)
                            : const Color(0xFFE5E7EB),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        s['name']!,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF065F46)
                              : const Color(0xFF111827),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() => _currentStyle = s['id']!);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
