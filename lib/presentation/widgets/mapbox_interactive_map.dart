import 'dart:math' as math;
import 'package:flutter/material.dart';

class MapboxCustomMarker {
  final String id;
  final double latitude;
  final double longitude;
  final Widget child;
  final VoidCallback? onTap;
  final Offset alignmentOffset;

  const MapboxCustomMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.child,
    this.onTap,
    this.alignmentOffset = const Offset(-0.5, -1.0),
  });
}

class MapboxInteractiveMap extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final String styleId;
  final String token;
  final List<List<double>>? routeCoordinates; // [[lng, lat], ...]
  final String? startTitle;
  final String? destTitle;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final double? navProgress; // 0.0 -> 1.0
  final bool isNavigating;
  final List<MapboxCustomMarker>? customMarkers;
  final VoidCallback? onMapMoved;

  const MapboxInteractiveMap({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialZoom = 14.5,
    this.styleId = 'mapbox/streets-v12',
    this.token =
        'pk.eyJ1IjoiZGluaHRhbnRoYW5oMTkiLCJhIjoiY210bnNsZ2V2MG14NzJ5cHN1ZjhzMjU3MiJ9.qM8oAp0Hb9ThJlBzvn0Qtw',
    this.routeCoordinates,
    this.startTitle = 'Vị trí của bạn',
    this.destTitle = 'Điểm đến',
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.navProgress,
    this.isNavigating = false,
    this.customMarkers,
    this.onMapMoved,
  });

  @override
  State<MapboxInteractiveMap> createState() => MapboxInteractiveMapState();
}

class MapboxInteractiveMapState extends State<MapboxInteractiveMap>
    with SingleTickerProviderStateMixin {
  late double _centerLat;
  late double _centerLng;
  late double _zoom;
  double _baseZoom = 14.5;

  AnimationController? _animController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;
  Animation<double>? _zoomAnim;

  static const int tileSize = 512;

  @override
  void initState() {
    super.initState();
    _centerLat = widget.initialLat;
    _centerLng = widget.initialLng;
    _zoom = widget.initialZoom;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapboxInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLat != widget.initialLat ||
        oldWidget.initialLng != widget.initialLng ||
        oldWidget.initialZoom != widget.initialZoom) {
      flyTo(widget.initialLat, widget.initialLng, widget.initialZoom, 400);
    }
  }

  void fitBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    required Size screenSize,
  }) {
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    final latDiff = (maxLat - minLat).abs();
    final lngDiff = (maxLng - minLng).abs();

    if (latDiff < 0.0001 && lngDiff < 0.0001) {
      flyTo(centerLat, centerLng, 15.0, 500);
      return;
    }

    final maxDim = math.max(latDiff * 1.2, lngDiff * 1.2);
    double targetZoom = (math.log(360 / maxDim) / math.ln2) - 1.2;
    targetZoom = targetZoom.clamp(4.0, 18.0);

    flyTo(centerLat, centerLng, targetZoom, 600);
  }

  void flyTo(double targetLat, double targetLng, [double? targetZoom, int durationMs = 500]) {
    if (!mounted || _animController == null) return;
    _animController!.stop();
    final startLat = _centerLat;
    final startLng = _centerLng;
    final startZoom = _zoom;
    final endZoom = (targetZoom ?? _zoom).clamp(3.0, 19.0);

    _latAnim = Tween<double>(begin: startLat, end: targetLat).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOutCubic),
    );
    _lngAnim = Tween<double>(begin: startLng, end: targetLng).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOutCubic),
    );
    _zoomAnim = Tween<double>(begin: startZoom, end: endZoom).animate(
      CurvedAnimation(parent: _animController!, curve: Curves.easeInOutCubic),
    );

    _animController!.duration = Duration(milliseconds: durationMs);
    _animController!.reset();
    _animController!.forward();
    _animController!.addListener(_animListener);
  }

  void _animListener() {
    if (!mounted) return;
    if (_latAnim != null && _lngAnim != null && _zoomAnim != null) {
      setState(() {
        _centerLat = _latAnim!.value;
        _centerLng = _lngAnim!.value;
        _zoom = _zoomAnim!.value;
      });
      widget.onMapMoved?.call();
    }
  }

  void setCenter(double lat, double lng, [double? zoom]) {
    flyTo(lat, lng, zoom, 400);
  }

  void zoomIn([double delta = 1.0]) {
    flyTo(_centerLat, _centerLng, (_zoom + delta).clamp(3.0, 19.0), 280);
  }

  void zoomOut([double delta = 1.0]) {
    flyTo(_centerLat, _centerLng, (_zoom - delta).clamp(3.0, 19.0), 280);
  }

  // Convert (Lat, Lng) to World Pixel at Zoom level Z (512px tile size)
  static math.Point<double> latLngToPixel(double lat, double lng, double zoom) {
    final double scale = tileSize * math.pow(2.0, zoom).toDouble();
    final double x = (lng + 180.0) / 360.0 * scale;

    final double latRad = lat * math.pi / 180.0;
    final double sinLat = math.sin(latRad).clamp(-0.9999, 0.9999);
    final double y =
        (0.5 - (math.log((1.0 + sinLat) / (1.0 - sinLat)) / (4.0 * math.pi))) *
            scale;

    return math.Point<double>(x, y);
  }

  // Convert Screen Delta (dx, dy) back to (dLat, dLng)
  void _panMap(double dx, double dy) {
    final double scale = tileSize * math.pow(2.0, _zoom).toDouble();
    final double dLng = -(dx / scale) * 360.0;

    // Mercator inverse for latitude
    final double currentCenterPixelY = latLngToPixel(_centerLat, _centerLng, _zoom).y;
    final double newCenterPixelY = currentCenterPixelY - dy;

    final double n = math.pi - 2.0 * math.pi * (newCenterPixelY / scale);
    final double newLat = (180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)))).clamp(-85.0, 85.0);

    setState(() {
      _centerLng = (_centerLng + dLng).clamp(-180.0, 180.0);
      _centerLat = newLat;
    });
    widget.onMapMoved?.call();
  }

  List<Widget> _buildTilesForZoomLevel({
    required int level,
    required double currentZoom,
    required double centerLat,
    required double centerLng,
    required double screenWidth,
    required double screenHeight,
    required bool isUnderlay,
  }) {
    if (level < 2 || level > 20) return const [];
    final double scaleDiff = math.pow(2.0, currentZoom - level).toDouble();
    final centerPixel = latLngToPixel(centerLat, centerLng, level.toDouble());

    final minScreenX = centerPixel.x - (screenWidth / 2) / scaleDiff;
    final maxScreenX = centerPixel.x + (screenWidth / 2) / scaleDiff;
    final minScreenY = centerPixel.y - (screenHeight / 2) / scaleDiff;
    final maxScreenY = centerPixel.y + (screenHeight / 2) / scaleDiff;

    final int minTileX = (minScreenX / tileSize).floor() - 1;
    final int maxTileX = (maxScreenX / tileSize).floor() + 1;
    final int minTileY = (minScreenY / tileSize).floor() - 1;
    final int maxTileY = (maxScreenY / tileSize).floor() + 1;

    final maxTilesAtLevel = 1 << level;
    final List<Widget> widgets = [];

    for (int tx = minTileX; tx <= maxTileX; tx++) {
      final int wrappedTx = (tx % maxTilesAtLevel + maxTilesAtLevel) % maxTilesAtLevel;
      for (int ty = minTileY; ty <= maxTileY; ty++) {
        if (ty < 0 || ty >= maxTilesAtLevel) continue;

        final tileOriginPixelX = tx * tileSize;
        final tileOriginPixelY = ty * tileSize;

        final double screenPosX = (screenWidth / 2) + (tileOriginPixelX - centerPixel.x) * scaleDiff;
        final double screenPosY = (screenHeight / 2) + (tileOriginPixelY - centerPixel.y) * scaleDiff;
        final double renderedTileSize = tileSize * scaleDiff;

        final tileUrl =
            'https://api.mapbox.com/styles/v1/${widget.styleId}/tiles/$tileSize/$level/$wrappedTx/$ty@2x?access_token=${widget.token}';

        widgets.add(
          Positioned(
            left: screenPosX,
            top: screenPosY,
            width: renderedTileSize + 0.6,
            height: renderedTileSize + 0.6,
            child: Image.network(
              tileUrl,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              cacheWidth: tileSize,
              cacheHeight: tileSize,
              errorBuilder: (ctx, err, stack) => isUnderlay
                  ? const SizedBox.shrink()
                  : Container(color: const Color(0xFFF1F5F9)),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        final int intZoom = _zoom.floor().clamp(2, 20);

        // 1. Underlay tiles from parent zoom (prevents any blank/white flashing during zoom)
        final List<Widget> underlayTiles = (intZoom > 2)
            ? _buildTilesForZoomLevel(
                level: intZoom - 1,
                currentZoom: _zoom,
                centerLat: _centerLat,
                centerLng: _centerLng,
                screenWidth: screenWidth,
                screenHeight: screenHeight,
                isUnderlay: true,
              )
            : [];

        // 2. High-resolution current zoom tiles
        final List<Widget> currentTiles = _buildTilesForZoomLevel(
          level: intZoom,
          currentZoom: _zoom,
          centerLat: _centerLat,
          centerLng: _centerLng,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          isUnderlay: false,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _baseZoom = _zoom;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2) {
              // Pinch zoom
              setState(() {
                _zoom = (_baseZoom + (math.log(details.scale) / math.ln2)).clamp(3.0, 19.0);
              });
            } else {
              // 1 finger pan
              _panMap(details.focalPointDelta.dx, details.focalPointDelta.dy);
            }
          },
          onDoubleTap: () {
            setState(() {
              _zoom = (_zoom + 1.0).clamp(3.0, 19.0);
            });
          },
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 1. Dynamic Infinite Mapbox Tiles Layer (Underlay + Current Zoom)
                ...underlayTiles,
                ...currentTiles,

                // 2. Google Maps Style Polyline Route Overlay
                if (widget.routeCoordinates != null && widget.routeCoordinates!.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePolylinePainter(
                        routeCoordinates: widget.routeCoordinates!,
                        centerLat: _centerLat,
                        centerLng: _centerLng,
                        zoom: _zoom,
                        screenSize: Size(screenWidth, screenHeight),
                      ),
                    ),
                  ),

                // 3. Start Pin (A / Current Location)
                if (widget.originLat != null && widget.originLng != null)
                  _buildMapMarker(
                    lat: widget.originLat!,
                    lng: widget.originLng!,
                    centerLat: _centerLat,
                    centerLng: _centerLng,
                    zoom: _zoom,
                    screenSize: Size(screenWidth, screenHeight),
                    child: _buildStartMarker(),
                  ),

                // 4. Destination Pin (B)
                if (widget.destLat != null && widget.destLng != null)
                  _buildMapMarker(
                    lat: widget.destLat!,
                    lng: widget.destLng!,
                    centerLat: _centerLat,
                    centerLng: _centerLng,
                    zoom: _zoom,
                    screenSize: Size(screenWidth, screenHeight),
                    child: _buildDestMarker(widget.destTitle ?? 'Điểm đến'),
                  ),

                // 5. Active User GPS Navigation Marker (moves along path)
                if (widget.isNavigating &&
                    widget.routeCoordinates != null &&
                    widget.routeCoordinates!.isNotEmpty &&
                    widget.navProgress != null)
                  _buildNavigatingPuck(
                    coords: widget.routeCoordinates!,
                    progress: widget.navProgress!,
                    centerLat: _centerLat,
                    centerLng: _centerLng,
                    zoom: _zoom,
                    screenSize: Size(screenWidth, screenHeight),
                  ),

                // 6. Custom Interactive Place Markers Layer
                if (widget.customMarkers != null && widget.customMarkers!.isNotEmpty)
                  for (final marker in widget.customMarkers!)
                    _buildMapMarker(
                      lat: marker.latitude,
                      lng: marker.longitude,
                      centerLat: _centerLat,
                      centerLng: _centerLng,
                      zoom: _zoom,
                      screenSize: Size(screenWidth, screenHeight),
                      alignmentOffset: marker.alignmentOffset,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: marker.onTap,
                        child: marker.child,
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapMarker({
    required double lat,
    required double lng,
    required double centerLat,
    required double centerLng,
    required double zoom,
    required Size screenSize,
    required Widget child,
    Offset alignmentOffset = const Offset(-0.5, -1.0),
  }) {
    final int intZoom = zoom.floor().clamp(0, 20);
    final double zoomFraction = zoom - intZoom;
    final double tileScale = math.pow(2.0, zoomFraction).toDouble();

    final centerPixel = latLngToPixel(centerLat, centerLng, intZoom.toDouble());
    final markerPixel = latLngToPixel(lat, lng, intZoom.toDouble());

    final double screenX = (screenSize.width / 2) + (markerPixel.x - centerPixel.x) * tileScale;
    final double screenY = (screenSize.height / 2) + (markerPixel.y - centerPixel.y) * tileScale;

    return Positioned(
      left: screenX,
      top: screenY,
      child: FractionalTranslation(
        translation: alignmentOffset,
        child: child,
      ),
    );
  }

  Widget _buildStartMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Vị trí của bạn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDestMarker(String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFE11D48),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white, size: 11),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.location_on,
          size: 32,
          color: Color(0xFFE11D48),
        ),
      ],
    );
  }

  Widget _buildNavigatingPuck({
    required List<List<double>> coords,
    required double progress,
    required double centerLat,
    required double centerLng,
    required double zoom,
    required Size screenSize,
  }) {
    if (coords.isEmpty) return const SizedBox();

    final totalPoints = coords.length;
    final double exactIndex = (totalPoints - 1) * progress.clamp(0.0, 1.0);
    final int lowerIndex = exactIndex.floor().clamp(0, totalPoints - 1);
    final int upperIndex = (lowerIndex + 1).clamp(0, totalPoints - 1);
    final double fraction = exactIndex - lowerIndex;

    final p1 = coords[lowerIndex];
    final p2 = coords[upperIndex];

    final currentLng = p1[0] + (p2[0] - p1[0]) * fraction;
    final currentLat = p1[1] + (p2[1] - p1[1]) * fraction;

    final int intZoom = zoom.floor().clamp(0, 20);
    final double zoomFraction = zoom - intZoom;
    final double tileScale = math.pow(2.0, zoomFraction).toDouble();

    final centerPixel = latLngToPixel(centerLat, centerLng, intZoom.toDouble());
    final puckPixel = latLngToPixel(currentLat, currentLng, intZoom.toDouble());

    final double screenX = (screenSize.width / 2) + (puckPixel.x - centerPixel.x) * tileScale;
    final double screenY = (screenSize.height / 2) + (puckPixel.y - centerPixel.y) * tileScale;

    // Direction angle
    final double angle = math.atan2(p2[1] - p1[1], p2[0] - p1[0]);

    return Positioned(
      left: screenX,
      top: screenY,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: -angle + (math.pi / 2),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  final List<List<double>> routeCoordinates;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final Size screenSize;

  _RoutePolylinePainter({
    required this.routeCoordinates,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routeCoordinates.length < 2) return;

    final int intZoom = zoom.floor().clamp(0, 20);
    final double zoomFraction = zoom - intZoom;
    final double tileScale = math.pow(2.0, zoomFraction).toDouble();

    final centerPixel = MapboxInteractiveMapState.latLngToPixel(centerLat, centerLng, intZoom.toDouble());

    final path = Path();
    bool first = true;

    for (final coord in routeCoordinates) {
      final lng = coord[0];
      final lat = coord[1];

      final pixel = MapboxInteractiveMapState.latLngToPixel(lat, lng, intZoom.toDouble());
      final screenX = (screenSize.width / 2) + (pixel.x - centerPixel.x) * tileScale;
      final screenY = (screenSize.height / 2) + (pixel.y - centerPixel.y) * tileScale;

      if (first) {
        path.moveTo(screenX, screenY);
        first = false;
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    // 1. Route Outer Border (Dark blue shadow for high contrast)
    final borderPaint = Paint()
      ..color = const Color(0xFF1E3A8A)
      ..strokeWidth = 9.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // 2. Route Main Polyline (Google Maps vibrant blue #2563EB)
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 3. Route Inner Highlight (Light blue inner glow)
    final innerPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter oldDelegate) {
    return oldDelegate.centerLat != centerLat ||
        oldDelegate.centerLng != centerLng ||
        oldDelegate.zoom != zoom ||
        oldDelegate.routeCoordinates != routeCoordinates;
  }
}
