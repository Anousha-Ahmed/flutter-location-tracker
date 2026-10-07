import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _fetching = false;

  double? _lat;
  double? _lng;
  DateTime? _updatedAt;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(30.3753, 69.3451),
    zoom: 4,
  );

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day}/${t.month}/${t.year}  $h:$m $ap';
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ));
  }

  Future<void> _onFabPressed() async {
    if (_fetching) return;
    setState(() => _fetching = true);

    try {
      final position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 16)),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _updatedAt = DateTime.now();
        _markers
          ..clear()
          ..add(Marker(
            markerId: const MarkerId('current_location'),
            position: latLng,
            infoWindow: const InfoWindow(title: 'You are here'),
          ));
      });

      final user = _authService.currentUser;
      if (user != null) {
        await _firestoreService.saveUserLocation(
          uid: user.uid,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }

      if (!mounted) return;
      _showMessage('Location saved successfully');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Widget _userCard() {
    final user = _authService.currentUser;
    final photo = user?.photoURL;

    return SizedBox(
      width: double.infinity,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE3EDFF),
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? const Icon(Icons.person, color: Color(0xFF2979FF))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
                        ? user.displayName!
                        : 'User',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _authService.signOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard() {
    final has = _lat != null && _lng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.pin_drop_rounded,
                  color: Color(0xFF2979FF), size: 20),
              SizedBox(width: 6),
              Text('Current location',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (!has)
            Text(
              'Tap the button to find your location',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            )
          else ...[
            Text('Lat: ${_lat!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text('Lng: ${_lng!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              'Updated: ${_formatTime(_updatedAt!)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            onMapCreated: (c) => _mapController = c,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Top: user card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _userCard(),
            ),
          ),

          // Bottom-left: coordinates card (right gap leaves room for FAB)
          Positioned(
            left: 16,
            right: 96,
            bottom: 24,
            child: SafeArea(top: false, child: _locationCard()),
          ),
        ],
      ),

      // FAB: bottom-right
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        backgroundColor: const Color(0xFF2979FF),
        foregroundColor: Colors.white,
        elevation: 6,
        child: _fetching
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.my_location_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}