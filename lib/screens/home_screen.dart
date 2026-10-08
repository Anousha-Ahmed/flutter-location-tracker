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
  bool _fetching = false;

  LatLng? _current;
  DateTime? _updatedAt;
  double? _accuracy;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(30.3753, 69.3451),
    zoom: 5,
  );

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '${t.day}/${t.month}/${t.year}  $h:$m $ap';
  }

  /// Naam na mile to email ka pehla hissa dikhata hai
  String _displayName() {
    final user = _authService.currentUser;
    final name = user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name;

    for (final p in user?.providerData ?? []) {
      final n = p.displayName;
      if (n != null && n.trim().isNotEmpty) return n;
    }

    final email = user?.email ?? '';
    if (email.contains('@')) {
      final part = email.split('@').first;
      return part.isEmpty ? 'User' : part[0].toUpperCase() + part.substring(1);
    }
    return 'User';
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 150),
        content: Text(msg),
      ));
  }

  Future<void> _onFabPressed() async {
    if (_fetching) return;
    setState(() => _fetching = true);

    try {
      // 1. permission + current location
      final position = await _locationService.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      // 2. marker + camera
      setState(() {
        _current = latLng;
        _updatedAt = DateTime.now();
        _accuracy = position.accuracy;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: latLng, zoom: 16)),
      );

      // 3. save / update in Firestore
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

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: child,
    );
  }

  Widget _userCard() {
    final user = _authService.currentUser;
    final photo = user?.photoURL;
    return _card(
      child: Row(
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
                Text(_displayName(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                Text(user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _authService.signOut,
          ),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pin_drop_rounded, color: Color(0xFF2979FF), size: 20),
              SizedBox(width: 6),
              Text('Current location',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          if (_current == null)
            Text('Tap the button to find your location',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else ...[
            Text('Lat: ${_current!.latitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Text('Lng: ${_current!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text('Updated: ${_formatTime(_updatedAt!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      if (_current != null)
        Marker(
          markerId: const MarkerId('current_location'),
          position: _current!,
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
    };

    final circles = <Circle>{
      if (_current != null && _accuracy != null)
        Circle(
          circleId: const CircleId('accuracy'),
          center: _current!,
          radius: _accuracy!,
          fillColor: const Color(0xFF2979FF).withValues(alpha: 0.15),
          strokeColor: const Color(0xFF2979FF).withValues(alpha: 0.4),
          strokeWidth: 1,
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: markers,
            circles: circles,
            myLocationEnabled: _current != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _mapController = c,
          ),

          // Top: user card
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _userCard(),
              ),
            ),
          ),

          // Bottom-left: location card
          Positioned(
            left: 16,
            right: 96,
            bottom: 24,
            child: SafeArea(top: false, child: _locationCard()),
          ),
        ],
      ),
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