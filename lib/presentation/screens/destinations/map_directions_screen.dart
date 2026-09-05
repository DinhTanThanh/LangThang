import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/place_model.dart';

enum TravelMode { motorcycle, car, walk, transit }
enum MapStyle { standard, satellite, dark }

class NavigationStep {
  final IconData icon;
  final String instruction;
  final String distance;
  final String time;

  const NavigationStep({
    required this.icon,
    required this.instruction,
    required this.distance,
    required this.time,
  });
}

class MapDirectionsScreen extends StatefulWidget {
  final PlaceModel place;
  final String? startLocationName;

  const MapDirectionsScreen({
    super.key,
    required this.place,
    this.startLocationName,
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

  late AnimationController _radarController;
  final TransformationController _transformController = TransformationController();

  // Route Waypoints (Canvas relative positions 0.0 -> 1.0)
  final List<Offset> _routePoints = const [
    Offset(0.20, 0.78), // User start
    Offset(0.32, 0.68),
    Offset(0.38, 0.52),
    Offset(0.55, 0.48),
    Offset(0.65, 0.35),
    Offset(0.78, 0.22), // Destination
  ];

  late List<NavigationStep> _steps;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _updateSteps();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _navTimer?.cancel();
    _transformController.dispose();
    super.dispose();
  }

  void _updateSteps() {
    final name = widget.place.name;
    final loc = widget.place.location;

    if (_selectedMode == TravelMode.motorcycle) {
      _steps = [
        const NavigationStep(
          icon: Icons.my_location,
          instruction: 'Bắt đầu từ Vị trí hiện tại của bạn',
          distance: '0 m',
          time: '0 ph',
        ),
        const NavigationStep(
          icon: Icons.straight,
          instruction: 'Đi thẳng trên trục đường chính về hướng Đông Bắc',
          distance: '450 m',
          time: '2 ph',
        ),
        const NavigationStep(
          icon: Icons.turn_right,
          instruction: 'Rẽ phải vào đại lộ trung tâm',
          distance: '1.2 km',
          time: '4 ph',
        ),
        const NavigationStep(
          icon: Icons.turn_left,
          instruction: 'Rẽ trái tại vòng xoay thứ 2',
          distance: '850 m',
          time: '3 ph',
        ),
        NavigationStep(
          icon: Icons.location_on,
          instruction: 'Điểm đến $name ($loc) nằm ở bên phải',
          distance: '300 m',
          time: '1 ph',
        ),
      ];
    } else if (_selectedMode == TravelMode.car) {
      _steps = [
        const NavigationStep(
          icon: Icons.my_location,
          instruction: 'Bắt đầu từ Vị trí của bạn',
          distance: '0 m',
          time: '0 ph',
        ),
        const NavigationStep(
          icon: Icons.straight,
          instruction: 'Nhập làn đường ô tô hướng đại lộ',
          distance: '800 m',
          time: '3 ph',
        ),
        const NavigationStep(
          icon: Icons.turn_right,
          instruction: 'Rẽ phải qua cầu vượt trung tâm',
          distance: '2.1 km',
          time: '6 ph',
        ),
        NavigationStep(
          icon: Icons.location_on,
          instruction: 'Đến nơi: $name (bãi đỗ xe ô tô cách 50m)',
          distance: '400 m',
          time: '2 ph',
        ),
      ];
    } else if (_selectedMode == TravelMode.walk) {
      _steps = [
        const NavigationStep(
          icon: Icons.directions_walk,
          instruction: 'Đi bộ theo vỉa hè đường rợp bóng cây',
          distance: '300 m',
          time: '4 ph',
        ),
        const NavigationStep(
          icon: Icons.turn_left,
          instruction: 'Rẽ trái vào ngõ phố đi bộ',
          distance: '900 m',
          time: '12 ph',
        ),
        const NavigationStep(
          icon: Icons.turn_right,
          instruction: 'Rẽ phải qua công viên quảng trường',
          distance: '1.1 km',
          time: '15 ph',
        ),
        NavigationStep(
          icon: Icons.location_on,
          instruction: 'Đến cổng chính $name',
          distance: '200 m',
          time: '3 ph',
        ),
      ];
    } else {
      _steps = [
        const NavigationStep(
          icon: Icons.directions_walk,
          instruction: 'Đi bộ 150m đến Trạm xe buýt gần nhất',
          distance: '150 m',
          time: '2 ph',
        ),
        const NavigationStep(
          icon: Icons.directions_bus,
          instruction: 'Lên xe buýt Tuyến số 09 (5 trạm dừng)',
          distance: '3.4 km',
          time: '14 ph',
        ),
        NavigationStep(
          icon: Icons.location_on,
          instruction: 'Xuống trạm và đi bộ 80m vào $name',
          distance: '80 m',
          time: '1 ph',
        ),
      ];
    }
  }

  void _toggleNavigationSimulation() {
    if (_isNavigating) {
      _navTimer?.cancel();
      setState(() {
        _isNavigating = false;
        _navProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dừng chế độ điều hướng GPS.')),
      );
    } else {
      setState(() {
        _isNavigating = true;
        _navProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang mô phỏng điều hướng GPS trực tiếp...'),
          backgroundColor: AppColors.primary,
        ),
      );

      _navTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        if (!mounted) return;
        setState(() {
          _navProgress += 0.015;
          if (_navProgress >= 1.0) {
            _navProgress = 1.0;
            _isNavigating = false;
            timer.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Bạn đã đến điểm đến: ${widget.place.name}!'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        });
      });
    }
  }

  String _getEta() {
    switch (_selectedMode) {
      case TravelMode.motorcycle:
        return '11 phút';
      case TravelMode.car:
        return '15 phút';
      case TravelMode.walk:
        return '35 phút';
      case TravelMode.transit:
        return '18 phút';
    }
  }

  String _getDistance() {
    switch (_selectedMode) {
      case TravelMode.motorcycle:
        return '3.6 km';
      case TravelMode.car:
        return '4.1 km';
      case TravelMode.walk:
        return '2.8 km';
      case TravelMode.transit:
        return '3.9 km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. Interactive Vector Map Layer
          InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.8,
            maxScale: 3.5,
            boundaryMargin: const EdgeInsets.all(200),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 1.5,
              height: MediaQuery.of(context).size.height * 1.3,
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: MapVectorPainter(
                      routePoints: _routePoints,
                      radarValue: _radarController.value,
                      navProgress: _navProgress,
                      isNavigating: _isNavigating,
                      mapStyle: _mapStyle,
                      place: place,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Top Header & Turn-by-turn Banner
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Place Title Pill
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.navigation, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Map Style Switcher
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 20,
                        child: IconButton(
                          icon: Icon(
                            _mapStyle == MapStyle.standard
                                ? Icons.layers
                                : _mapStyle == MapStyle.satellite
                                    ? Icons.satellite_alt
                                    : Icons.dark_mode,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_mapStyle == MapStyle.standard) {
                                _mapStyle = MapStyle.satellite;
                              } else if (_mapStyle == MapStyle.satellite) {
                                _mapStyle = MapStyle.dark;
                              } else {
                                _mapStyle = MapStyle.standard;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Active Next Turn Instruction Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.turn_right_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sau 250m, rẽ phải',
                                style: TextStyle(
                                  color: Color(0xFFFDBA74),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _steps.isNotEmpty ? _steps[2].instruction : 'Tiến vào đường dẫn đến ${place.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _getEta(),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _getDistance(),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Travel Mode Selector Floating Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildModeTab(TravelMode.motorcycle, Icons.two_wheeler, 'Xe máy', '11 ph'),
                        _buildModeTab(TravelMode.car, Icons.directions_car, 'Ô tô', '15 ph'),
                        _buildModeTab(TravelMode.walk, Icons.directions_walk, 'Đi bộ', '35 ph'),
                        _buildModeTab(TravelMode.transit, Icons.directions_bus, 'Buýt', '18 ph'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Map Control Buttons on Right Side
          Positioned(
            right: 16,
            bottom: 230,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.add,
                  onTap: () {
                    final m = Matrix4.copy(_transformController.value);
                    m.scaleByDouble(1.2, 1.2, 1.0, 1.0);
                    _transformController.value = m;
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.remove,
                  onTap: () {
                    final m = Matrix4.copy(_transformController.value);
                    m.scaleByDouble(0.83, 0.83, 1.0, 1.0);
                    _transformController.value = m;
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.my_location,
                  color: AppColors.primary,
                  onTap: () {
                    _transformController.value = Matrix4.identity();
                  },
                ),
              ],
            ),
          ),

          // 4. Bottom Draggable Details Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.18,
            maxChildSize: 0.70,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    // Sheet Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Quick Route Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getEta(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${_getDistance()})',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Giao thông thông thoáng',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Tuyến đường nhanh nhất qua đại lộ trung tâm · ${place.location}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 16),

                    // Navigation Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _toggleNavigationSimulation,
                            icon: Icon(_isNavigating ? Icons.stop_circle : Icons.navigation, color: Colors.white, size: 18),
                            label: Text(
                              _isNavigating ? 'Dừng điều hướng' : 'Bắt đầu điều hướng',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isNavigating ? Colors.redAccent : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Đang mở tọa độ ${place.latitude}, ${place.longitude} trên Google Maps...')),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16, color: AppColors.textPrimary),
                            label: const Text(
                              'Maps',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 28),

                    // Turn by turn steps detail
                    const Text(
                      'Chi tiết các chặng di chuyển:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    ..._steps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      final isLast = idx == _steps.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: idx == 0
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : isLast
                                          ? AppColors.secondary.withValues(alpha: 0.15)
                                          : AppColors.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 16,
                                  color: idx == 0
                                      ? AppColors.primary
                                      : isLast
                                          ? AppColors.secondary
                                          : AppColors.textPrimary,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 38,
                                  color: Colors.grey.shade200,
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.instruction,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${step.distance} · ${step.time}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(TravelMode mode, IconData icon, String label, String time) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _updateSteps();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? AppColors.textPrimary, size: 20),
        onPressed: onTap,
      ),
    );
  }
}

// ─── CUSTOM VECTOR MAP PAINTER ───────────────────────────────────────────────

class MapVectorPainter extends CustomPainter {
  final List<Offset> routePoints;
  final double radarValue;
  final double navProgress;
  final bool isNavigating;
  final MapStyle mapStyle;
  final PlaceModel place;

  MapVectorPainter({
    required this.routePoints,
    required this.radarValue,
    required this.navProgress,
    required this.isNavigating,
    required this.mapStyle,
    required this.place,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = mapStyle == MapStyle.dark;
    final isSat = mapStyle == MapStyle.satellite;

    // 1. Map Base Land Color
    final basePaint = Paint()
      ..color = isDark
          ? const Color(0xFF0F172A)
          : isSat
              ? const Color(0xFF1B382B)
              : const Color(0xFFF4F6F8);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // 2. Waterways & Rivers
    final waterPaint = Paint()
      ..color = isDark
          ? const Color(0xFF0284C7).withValues(alpha: 0.25)
          : isSat
              ? const Color(0xFF082F49)
              : const Color(0xFFBFDBFE)
      ..style = PaintingStyle.fill;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.40)
      ..cubicTo(
        size.width * 0.35, size.height * 0.38,
        size.width * 0.60, size.height * 0.55,
        size.width, size.height * 0.45,
      )
      ..lineTo(size.width, size.height * 0.52)
      ..cubicTo(
        size.width * 0.60, size.height * 0.62,
        size.width * 0.35, size.height * 0.46,
        0, size.height * 0.48,
      )
      ..close();
    canvas.drawPath(riverPath, waterPaint);

    // 3. Parks & Greenery Areas
    final parkPaint = Paint()
      ..color = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.3)
          : isSat
              ? const Color(0xFF14532D)
              : const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.15, size.width * 0.25, size.height * 0.18),
        const Radius.circular(16),
      ),
      parkPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.60, size.height * 0.60, size.width * 0.30, size.height * 0.22),
        const Radius.circular(20),
      ),
      parkPaint,
    );

    // 4. Grid of City Streets & Avenues
    final streetPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : isSat
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final roadBorderPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.2)
          : const Color(0xFFCBD5E1)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // Draw background road network
    for (double x = 0.1; x < 1.0; x += 0.18) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x + 40, size.height),
        roadBorderPaint,
      );
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x + 40, size.height),
        streetPaint,
      );
    }
    for (double y = 0.15; y < 1.0; y += 0.20) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y - 30),
        roadBorderPaint,
      );
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y - 30),
        streetPaint,
      );
    }

    // 5. Route Polyline (Glow & Main Path)
    final routePath = Path();
    for (int i = 0; i < routePoints.length; i++) {
      final pt = Offset(routePoints[i].dx * size.width, routePoints[i].dy * size.height);
      if (i == 0) {
        routePath.moveTo(pt.dx, pt.dy);
      } else {
        routePath.lineTo(pt.dx, pt.dy);
      }
    }

    // Route Outer Glow
    final routeGlowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, routeGlowPaint);

    // Route Solid Line
    final routeMainPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, routeMainPaint);

    // 6. Draw Waypoint nodes along the route
    for (int i = 1; i < routePoints.length - 1; i++) {
      final pt = Offset(routePoints[i].dx * size.width, routePoints[i].dy * size.height);
      canvas.drawCircle(pt, 5, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 3, Paint()..color = AppColors.primary);
    }

    // 7. User Current Location Pin (Radar pulse)
    final userPos = Offset(routePoints[0].dx * size.width, routePoints[0].dy * size.height);

    // Animated Radar Wave
    final radarPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: (1.0 - radarValue) * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 16 + (radarValue * 24), radarPaint);

    // User Blue Dot
    canvas.drawCircle(userPos, 10, Paint()..color = Colors.white);
    canvas.drawCircle(userPos, 7, Paint()..color = const Color(0xFF0284C7));

    // 8. Simulated Moving Car/GPS Icon if navigating
    if (isNavigating) {
      final currentPt = _getPointAlongRoute(size, navProgress);
      final carPaint = Paint()..color = AppColors.secondary;
      canvas.drawCircle(currentPt, 12, Paint()..color = Colors.white);
      canvas.drawCircle(currentPt, 9, carPaint);
    }

    // 9. Destination Pin (Custom Badge & Marker)
    final destPos = Offset(routePoints.last.dx * size.width, routePoints.last.dy * size.height);

    // Pin shadow
    canvas.drawOval(
      Rect.fromCenter(center: destPos.translate(0, 4), width: 18, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    // Pin Marker Body
    final pinPath = Path()
      ..moveTo(destPos.dx, destPos.dy)
      ..lineTo(destPos.dx - 12, destPos.dy - 28)
      ..arcToPoint(
        Offset(destPos.dx + 12, destPos.dy - 28),
        radius: const Radius.circular(14),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(pinPath, Paint()..color = AppColors.secondary);
    canvas.drawCircle(destPos.translate(0, -28), 6, Paint()..color = Colors.white);

    // Destination Label Pill
    _drawLabel(canvas, destPos.translate(0, -50), place.name);
  }

  Offset _getPointAlongRoute(Size size, double progress) {
    if (routePoints.isEmpty) return Offset.zero;
    if (progress <= 0) return Offset(routePoints.first.dx * size.width, routePoints.first.dy * size.height);
    if (progress >= 1.0) return Offset(routePoints.last.dx * size.width, routePoints.last.dy * size.height);

    final totalSegments = routePoints.length - 1;
    final scaledProgress = progress * totalSegments;
    final index = scaledProgress.floor().clamp(0, totalSegments - 1);
    final subProgress = scaledProgress - index;

    final p1 = Offset(routePoints[index].dx * size.width, routePoints[index].dy * size.height);
    final p2 = Offset(routePoints[index + 1].dx * size.width, routePoints[index + 1].dy * size.height);

    return Offset(
      p1.dx + (p2.dx - p1.dx) * subProgress,
      p1.dy + (p2.dy - p1.dy) * subProgress,
    );
  }

  void _drawLabel(Canvas canvas, Offset offset, String text) {
    final span = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: offset, width: tp.width + 16, height: tp.height + 8),
      const Radius.circular(8),
    );

    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0F172A));
    tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant MapVectorPainter oldDelegate) {
    return oldDelegate.radarValue != radarValue ||
        oldDelegate.navProgress != navProgress ||
        oldDelegate.isNavigating != isNavigating ||
        oldDelegate.mapStyle != mapStyle;
  }
}
