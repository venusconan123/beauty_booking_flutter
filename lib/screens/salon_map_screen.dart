import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/sample_salons.dart';
import '../models/salon.dart';
import 'salon_detail_screen.dart';

class SalonMapScreen extends StatefulWidget {
  const SalonMapScreen({super.key});

  @override
  State<SalonMapScreen> createState() {
    return _SalonMapScreenState();
  }
}

class _SalonMapScreenState extends State<SalonMapScreen> {
  static const LatLng _daNangCenter = LatLng(16.0544, 108.2022);

  late final MapController _mapController;

  LatLng? _currentLocation;
  String? _locationMessage;

  bool _isLoadingLocation = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();

    _mapController = MapController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation({bool moveCamera = true}) async {
    if (_isLoadingLocation) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showLocationMessage(
          'Dịch vụ vị trí đang tắt. '
          'Hãy bật định vị trên thiết bị.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showLocationMessage(
          'Bạn chưa cho phép ứng dụng '
          'truy cập vị trí.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Quyền vị trí đã bị từ chối vĩnh viễn. '
          'Hãy bật lại trong cài đặt trình duyệt '
          'hoặc thiết bị.',
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final LatLng currentPoint = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = currentPoint;
        _locationMessage = null;
      });

      if (moveCamera && _isMapReady) {
        _mapController.move(currentPoint, 15);
      }
    } catch (_) {
      _showLocationMessage(
        'Không thể lấy vị trí hiện tại. '
        'Hãy kiểm tra GPS và quyền vị trí.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _locationMessage = message;
    });
  }

  void _moveToCurrentLocation() {
    final LatLng? currentLocation = _currentLocation;

    if (currentLocation == null) {
      _loadCurrentLocation();
      return;
    }

    _mapController.move(currentLocation, 15);
  }

  void _moveToSalonArea() {
    _mapController.move(_daNangCenter, 13);
  }

  String _distanceFromUser(Salon salon) {
    final LatLng? currentLocation = _currentLocation;

    if (currentLocation == null) {
      return '${salon.distance} km ước tính';
    }

    final double distanceInMeters = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      salon.latitude,
      salon.longitude,
    );

    final double distanceInKilometers = distanceInMeters / 1000;

    if (distanceInKilometers < 1) {
      return '${distanceInMeters.round()} m';
    }

    return '${distanceInKilometers.toStringAsFixed(1)} km';
  }

  void _showSalonInformation(BuildContext context, Salon salon) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFFE1ECFF),
                      child: Icon(Icons.content_cut, color: Color(0xFF1E3A5F)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        salon.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF1E3A5F),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(salon.address)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text('${salon.rating}'),
                    const SizedBox(width: 20),
                    const Icon(
                      Icons.near_me_outlined,
                      color: Color(0xFF1E3A5F),
                    ),
                    const SizedBox(width: 6),
                    Text(_distanceFromUser(salon)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(bottomSheetContext).pop();

                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) {
                            return SalonDetailScreen(salon: salon);
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Xem chi tiết salon'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Marker _buildSalonMarker(BuildContext context, Salon salon) {
    return Marker(
      point: LatLng(salon.latitude, salon.longitude),
      width: 60,
      height: 60,
      alignment: Alignment.topCenter,
      child: Tooltip(
        message: salon.name,
        child: GestureDetector(
          onTap: () {
            _showSalonInformation(context, salon);
          },
          child: const Icon(
            Icons.location_pin,
            size: 54,
            color: Color(0xFF1E3A5F),
            shadows: [
              Shadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: _currentLocation!,
      width: 54,
      height: 54,
      child: Tooltip(
        message: 'Vị trí của bạn',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
          ),
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    final List<Marker> markers = sampleSalons.map((salon) {
      return _buildSalonMarker(context, salon);
    }).toList();

    if (_currentLocation != null) {
      markers.add(_buildCurrentLocationMarker());
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Salon tại Đà Nẵng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _daNangCenter,
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 18,
              onMapReady: () {
                _isMapReady = true;

                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 15);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.venusconan.'
                    'beauty_booking_app',
              ),
              MarkerLayer(markers: _buildMarkers(context)),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
                alignment: Alignment.bottomLeft,
              ),
            ],
          ),
          if (_locationMessage != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationMessage!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () {
                          setState(() {
                            _locationMessage = null;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'salon_area',
            tooltip: 'Xem các salon',
            onPressed: _moveToSalonArea,
            child: const Icon(Icons.store_mall_directory),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'current_location',
            tooltip: 'Vị trí của tôi',
            onPressed: _isLoadingLocation ? null : _moveToCurrentLocation,
            child: _isLoadingLocation
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
