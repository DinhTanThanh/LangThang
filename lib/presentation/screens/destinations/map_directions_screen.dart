import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/models/place_model.dart';
import '../../../data/services/mapbox_service.dart';
import '../../widgets/mapbox_interactive_map.dart';

enum TravelMode { motorcycle, car, walk, cycling }
enum MapStyle { standard, satellite, outdoors, dark }

class MapDirectionsScreen extends StatefulWidget {
  final PlaceModel place;
  final String? startLocationName;
  final double? startLatitude;
  final double? startLongitude;

  const MapDirectionsScreen({
    super.key,
    required this.place,
    this.startLocationName,
    this.startLatitude,
    this.startLongitude,
  });

  @override
  State<MapDirectionsScreen> createState() => _MapDirectionsScreenState();
}

class _MapDirectionsScreenState extends State<MapDirectionsScreen>
    with SingleTickerProviderStateMixin {
  TravelMode _selectedMode = TravelMode.motorcycle;
  MapStyle _mapStyle = MapStyle.standard;
  bool _isNavigating = false;
  double _navProgress = 0.0;
  Timer? _navTimer;

  late double _originLat;
  late double _originLng;
  late String _originName;

  late double _destLat;
  late double _destLng;

  bool _isLoadingRoute = true;
  MapboxRouteResult? _routeResult;

  final GlobalKey<MapboxInteractiveMapState> _mapKey =
      GlobalKey<MapboxInteractiveMapState>();

  @override
  void initState() {
    super.initState();

    _destLat = widget.place.latitude != 0.0 ? widget.place.latitude : 21.0285;
    _destLng = widget.place.longitude != 0.0 ? widget.place.longitude : 105.8542;

    // Set origin: if passed, use it; otherwise compute realistic start location nearby
    if (widget.startLatitude != null && widget.startLongitude != null) {
      _originLat = widget.startLatitude!;
      _originLng = widget.startLongitude!;
      _originName = widget.startLocationName ?? 'Vị trí của bạn';
    } else {
      // Offset slightly (~3-4km) from destination to create a realistic route
      _originLat = _destLat - 0.028;
      _originLng = _destLng - 0.022;
      _originName = widget.startLocationName ?? 'Vị trí của bạn';
    }

    _fetchMapboxRoute();
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }

  String _getMapboxProfile(TravelMode mode) {
    switch (mode) {
      case TravelMode.motorcycle:
      case TravelMode.car:
        return 'driving';
      case TravelMode.walk:
        return 'walking';
      case TravelMode.cycling:
        return 'cycling';
    }
  }

  String _getStyleId(MapStyle style) {
    switch (style) {
      case MapStyle.standard:
        return 'mapbox/streets-v12';
      case MapStyle.satellite:
        return 'mapbox/satellite-streets-v12';
      case MapStyle.outdoors:
        return 'mapbox/outdoors-v12';
      case MapStyle.dark:
        return 'mapbox/dark-v11';
    }
  }

  Future<void> _fetchMapboxRoute() async {
    setState(() => _isLoadingRoute = true);

    final result = await MapboxService.getDirections(
      originLat: _originLat,
      originLng: _originLng,
      destLat: _destLat,
      destLng: _destLng,
      profile: _getMapboxProfile(_selectedMode),
    );

    if (mounted) {
      setState(() {
        _routeResult = result;
        _isLoadingRoute = false;
        _navProgress = 0.0;
        if (_isNavigating) {
          _isNavigating = false;
          _navTimer?.cancel();
        }
      });

      _reCenterMap();
    }
  }

  void _reCenterMap() {
    final minLat = _originLat < _destLat ? _originLat : _destLat;
    final maxLat = _originLat > _destLat ? _originLat : _destLat;
    final minLng = _originLng < _destLng ? _originLng : _destLng;
    final maxLng = _originLng > _destLng ? _originLng : _destLng;

    _mapKey.currentState?.fitBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
      screenSize: MediaQuery.of(context).size,
    );
  }

  void _zoomIn() {
    _mapKey.currentState?.zoomIn();
  }

  void _zoomOut() {
    _mapKey.currentState?.zoomOut();
  }

  void _toggleNavigationSimulation() {
    if (_isNavigating) {
      _navTimer?.cancel();
      setState(() {
        _isNavigating = false;
        _navProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã dừng chế độ điều hướng.'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() {
        _isNavigating = true;
        _navProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.navigation, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Đang bắt đầu điều hướng Google Maps...'),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ),
      );

      _navTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
        if (!mounted) return;
        setState(() {
          _navProgress += 0.015;
          if (_navProgress >= 1.0) {
            _navProgress = 1.0;
            _isNavigating = false;
            timer.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Bạn đã đến nơi: ${widget.place.name}!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          }
        });
      });
    }
  }

  String _getEta() {
    if (_routeResult != null) {
      return _routeResult!.formattedDuration;
    }
    switch (_selectedMode) {
      case TravelMode.motorcycle:
        return '8 phút';
      case TravelMode.car:
        return '12 phút';
      case TravelMode.walk:
        return '30 phút';
      case TravelMode.cycling:
        return '15 phút';
    }
  }

  String _getDistance() {
    if (_routeResult != null) {
      return _routeResult!.formattedDistance;
    }
    switch (_selectedMode) {
      case TravelMode.motorcycle:
      case TravelMode.car:
        return '3.8 km';
      case TravelMode.walk:
        return '3.2 km';
      case TravelMode.cycling:
        return '3.5 km';
    }
  }

  IconData _getStepIcon(String maneuverType, String maneuverModifier) {
    final type = maneuverType.toLowerCase();
    final mod = maneuverModifier.toLowerCase();

    if (type.contains('arrive')) return Icons.location_on;
    if (type.contains('depart')) return Icons.my_location;
    if (mod.contains('left')) return Icons.turn_left_rounded;
    if (mod.contains('right')) return Icons.turn_right_rounded;
    if (mod.contains('u-turn')) return Icons.u_turn_left_rounded;
    if (type.contains('roundabout') || type.contains('rotary')) return Icons.roundabout_right_rounded;
    return Icons.straight_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final steps = _routeResult?.steps ?? [];
    final midLat = (_originLat + _destLat) / 2;
    final midLng = (_originLng + _destLng) / 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Dynamic Mapbox Tile Map (Infinite 360-degree panning & zooming with Google Maps style Route)
          Positioned.fill(
            child: MapboxInteractiveMap(
              key: _mapKey,
              initialLat: midLat,
              initialLng: midLng,
              initialZoom: 13.5,
              styleId: _getStyleId(_mapStyle),
              routeCoordinates: _routeResult?.coordinates,
              originLat: _originLat,
              originLng: _originLng,
              destLat: _destLat,
              destLng: _destLng,
              startTitle: _originName,
              destTitle: place.name,
              navProgress: _navProgress,
              isNavigating: _isNavigating,
            ),
          ),

          // 2. Sleek Compact Top Bar (Google Maps Style)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B), size: 20),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Quay lại',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),

                      // Route summary info (Destination & ETA)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFFE11D48), size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    place.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _isLoadingRoute
                                  ? 'Đang tính toán đường đi...'
                                  : '${_getEta()} • ${_getDistance()}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Map Style toggle button
                      IconButton(
                        icon: const Icon(Icons.layers_outlined, color: Color(0xFF475569), size: 20),
                        tooltip: 'Đổi kiểu bản đồ',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            if (_mapStyle == MapStyle.standard) {
                              _mapStyle = MapStyle.satellite;
                            } else if (_mapStyle == MapStyle.satellite) {
                              _mapStyle = MapStyle.outdoors;
                            } else if (_mapStyle == MapStyle.outdoors) {
                              _mapStyle = MapStyle.dark;
                            } else {
                              _mapStyle = MapStyle.standard;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Active Turn-by-Turn Instruction Banner (Only when navigating)
                if (_isNavigating && steps.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF065F46),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF065F46).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getStepIcon(
                              steps.length > 1 ? steps[1].maneuverType : steps[0].maneuverType,
                              steps.length > 1 ? steps[1].maneuverModifier : steps[0].maneuverModifier,
                            ),
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                steps.length > 1
                                    ? 'Sau ${steps[0].formattedDistance}'
                                    : 'Bắt đầu di chuyển',
                                style: const TextStyle(
                                  color: Color(0xFF6EE7B7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                steps.length > 1 ? steps[1].instruction : steps[0].instruction,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(_navProgress * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3. Floating Right Map Controls (Re-center, Zoom In, Zoom Out)
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 75,
            child: Column(
              children: [
                _buildFloatingBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Căn giữa lộ trình',
                  iconColor: const Color(0xFF059669),
                  onTap: _reCenterMap,
                ),
                const SizedBox(height: 8),
                _buildFloatingBtn(
                  icon: Icons.add,
                  tooltip: 'Phóng to',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildFloatingBtn(
                  icon: Icons.remove,
                  tooltip: 'Thu nhỏ',
                  onTap: _zoomOut,
                ),
              ],
            ),
          ),

          // 4. Google Maps Style Bottom Drawer (Starts compact, expandable)
          DraggableScrollableSheet(
            initialChildSize: 0.22,
            minChildSize: 0.14,
            maxChildSize: 0.70,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Pull Handle Indicator
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Travel Mode Selection Row
                    Row(
                      children: [
                        _buildModeButton(TravelMode.motorcycle, Icons.two_wheeler, 'Xe máy'),
                        const SizedBox(width: 6),
                        _buildModeButton(TravelMode.car, Icons.directions_car, 'Ô tô'),
                        const SizedBox(width: 6),
                        _buildModeButton(TravelMode.walk, Icons.directions_walk, 'Đi bộ'),
                        const SizedBox(width: 6),
                        _buildModeButton(TravelMode.cycling, Icons.pedal_bike, 'Xe đạp'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Primary Action Button: "Bắt đầu đi"
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _toggleNavigationSimulation,
                            icon: Icon(
                              _isNavigating ? Icons.stop_rounded : Icons.navigation_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              _isNavigating ? 'Dừng điều hướng' : 'Bắt đầu đi',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNavigating
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _fetchMapboxRoute,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.refresh, color: Color(0xFF475569), size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Turn-by-Turn Instruction Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chi tiết lộ trình từng bước',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_isLoadingRoute)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                          )
                        else
                          Text(
                            '${steps.length} bước',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Turn-by-Turn Steps List
                    if (steps.isNotEmpty)
                      ...List.generate(steps.length, (index) {
                        final step = steps[index];
                        final isLast = index == steps.length - 1;
                        final icon = _getStepIcon(step.maneuverType, step.maneuverModifier);

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: isLast
                                          ? const Color(0xFFFEE2E2)
                                          : (index == 0 ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 14,
                                      color: isLast
                                          ? const Color(0xFFDC2626)
                                          : (index == 0 ? const Color(0xFF0284C7) : const Color(0xFF059669)),
                                    ),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(
                                        width: 2,
                                        color: const Color(0xFFE2E8F0),
                                        margin: const EdgeInsets.symmetric(vertical: 3),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.instruction.isNotEmpty
                                            ? step.instruction
                                            : 'Tiếp tục đi thẳng',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (step.distanceMeters > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            '${step.formattedDistance} • ${step.formattedTime}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
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
                      })
                    else if (!_isLoadingRoute)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Lộ trình từ $_originName đến ${place.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF334155),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildModeButton(TravelMode mode, IconData icon, String label) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedMode = mode);
          _fetchMapboxRoute();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF065F46) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
