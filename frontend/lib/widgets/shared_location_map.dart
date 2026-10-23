import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SharedLocationPin {
  final LatLng point;
  final String label;
  final Color color;
  final IconData icon;

  const SharedLocationPin({
    required this.point,
    required this.label,
    required this.color,
    this.icon = Icons.person_pin_circle,
  });
}

class SharedLocationMap extends StatelessWidget {
  final List<SharedLocationPin> pins;
  final LatLng? selectedPoint;
  final ValueChanged<LatLng>? onTap;
  final double height;
  final String emptyMessage;

  const SharedLocationMap({
    super.key,
    required this.pins,
    this.selectedPoint,
    this.onTap,
    this.height = 260,
    this.emptyMessage = 'No shared locations to show.',
  });

  @override
  Widget build(BuildContext context) {
    final points = [
      ...pins.map((pin) => pin.point),
      if (selectedPoint != null) selectedPoint!,
    ];
    final uniquePoints = points.toSet().toList();
    final center = points.isEmpty
        ? const LatLng(9.5, 76.5)
        : LatLng(
            points.map((point) => point.latitude).reduce((a, b) => a + b) /
                points.length,
            points.map((point) => point.longitude).reduce((a, b) => a + b) /
                points.length,
          );

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 9,
              initialCameraFit: uniquePoints.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(uniquePoints),
                      padding: const EdgeInsets.all(40),
                    )
                  : null,
              minZoom: 3,
              maxZoom: 18,
              onTap: onTap == null ? null : (_, point) => onTap!(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.lifepulse_ai',
              ),
              MarkerLayer(
                markers: [
                  for (final pin in pins)
                    Marker(
                      point: pin.point,
                      width: 42,
                      height: 42,
                      child: Tooltip(
                        message: pin.label,
                        child: Icon(pin.icon, color: pin.color, size: 38),
                      ),
                    ),
                  if (selectedPoint != null)
                    Marker(
                      point: selectedPoint!,
                      width: 42,
                      height: 42,
                      child: const Tooltip(
                        message: 'Selected test pin',
                        child: Icon(
                          Icons.add_location_alt,
                          color: Color(0xFF7C3AED),
                          size: 38,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (points.isEmpty && onTap == null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.white.withValues(alpha: 0.9),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 5,
            top: 5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9, color: Color(0xFF334155)),
                  ),
                ),
              ),
            ),
          ),
          if (onTap != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text(
                      'Tap the map to place or move your test pin',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
