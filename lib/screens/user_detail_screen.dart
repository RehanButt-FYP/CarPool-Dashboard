import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/car_document.dart';
import '../models/ride_document.dart';
import '../models/user_document.dart';
import '../services/firestore_service.dart';
import 'driver_detail_screen.dart';
import 'ride_detail_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _service = AdminFirestoreService();
  final _formKey = GlobalKey<FormState>();

  UserDocument? _user;
  List<SavedRideReference> _savedRides = [];
  List<RideDocument> _postedRides = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _genderCtrl;
  late final TextEditingController _photoCtrl;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _genderCtrl = TextEditingController();
    _photoCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _genderCtrl.dispose();
    _photoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await _service.getUser(widget.userId);
      if (!mounted) return;
      if (user == null) {
        setState(() => _error = 'User not found');
        return;
      }
      final saved = await _service.getUserSavedRides(widget.userId);
      final posted = await _service.getUserPostedRides(widget.userId);
      if (!mounted) return;
      _applyUser(user);
      setState(() {
        _user = user;
        _savedRides = saved;
        _postedRides = posted;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyUser(UserDocument user) {
    _fullNameCtrl.text = user.fullName;
    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _phoneCtrl.text = user.phoneNumber ?? '';
    _genderCtrl.text = user.gender ?? '';
    _photoCtrl.text = user.photoURL ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.updateUserProfile(
        widget.userId,
        fullName: _fullNameCtrl.text,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        phoneNumber: _phoneCtrl.text,
        gender: _genderCtrl.text,
        photoURL: _photoCtrl.text,
      );
      final refreshed = await _service.getUser(widget.userId);
      if (!mounted) return;
      if (refreshed != null) {
        _applyUser(refreshed);
        setState(() => _user = refreshed);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    try {
      await _service.setUserEnabled(widget.userId, enabled: enabled);
      final refreshed = await _service.getUser(widget.userId);
      if (!mounted) return;
      setState(() => _user = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'User enabled' : 'User disabled'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _user?.displayName ?? 'User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final user = _user!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _profileHeader(user),
          const SizedBox(height: 16),
          _accountCard(user),
          const SizedBox(height: 16),
          _sectionTitle('Profile'),
          _card(
            child: Column(
              children: [
                _field(_fullNameCtrl, label: 'Full name', required: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(_firstNameCtrl, label: 'First name'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(_lastNameCtrl, label: 'Last name'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_phoneCtrl, label: 'Phone'),
                const SizedBox(height: 12),
                _field(_genderCtrl, label: 'Gender'),
                const SizedBox(height: 12),
                _field(_photoCtrl, label: 'Photo URL'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveProfile,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save profile'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ],
            ),
          ),
          if (user.hasSubmittedDocs) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverDetailScreen(user: user),
                ),
              ),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Review driver verification documents'),
            ),
          ],
          if (user.isRegisteredDriver || user.hasRegisteredCar) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserCarsScreen(
                    userId: widget.userId,
                    userName: user.displayName,
                  ),
                ),
              ),
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Manage cars'),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Posted rides (${_postedRides.length})'),
          if (_postedRides.isEmpty)
            _emptyHint('No rides posted by this user.')
          else
            ..._postedRides.take(5).map(_rideTile),
          const SizedBox(height: 20),
          _sectionTitle('Saved rides (${_savedRides.length})'),
          if (_savedRides.isEmpty)
            _emptyHint('No bookmarked rides.')
          else
            ..._savedRides.take(5).map(_savedRideTile),
        ],
      ),
    );
  }

  Widget _profileHeader(UserDocument user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(user),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.id ?? '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (user.isRegisteredDriver) _chip('Driver', const Color(0xFF6D4C41)),
                    if (user.isDriverApproved) _chip('Approved', const Color(0xFF2E7D32)),
                    if (!user.isEnabled) _chip('Disabled', Colors.red[700]!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(UserDocument user) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Account enabled'),
            subtitle: Text(
              user.isEnabled
                  ? 'User can use the app (when app checks isEnabled).'
                  : 'Account is disabled by admin.',
            ),
            value: user.isEnabled,
            onChanged: _toggleEnabled,
          ),
          if (user.createdAt != null)
            Text(
              'Joined ${DateFormat('MMM d, yyyy').format(user.createdAt!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          if (user.lastSeen != null)
            Text(
              'Last seen ${DateFormat('MMM d, yyyy · HH:mm').format(user.lastSeen!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }

  Widget _rideTile(RideDocument ride) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ride.isRideVerified ? Icons.verified : Icons.pending_outlined,
        color: ride.isRideVerified
            ? const Color(0xFF2E7D32)
            : const Color(0xFFE65100),
      ),
      title: Text(ride.routeLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        ride.startTimestamp != null
            ? DateFormat('MMM d · HH:mm').format(ride.startTimestamp!)
            : ride.id,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(rideId: ride.id),
        ),
      ),
    );
  }

  Widget _savedRideTile(SavedRideReference ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.bookmark_outline, color: Color(0xFF1565C0)),
      title: Text('Ride ${ref.rideId}'),
      subtitle: ref.savedAt != null
          ? Text('Saved ${DateFormat('MMM d, yyyy').format(ref.savedAt!)}')
          : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RideDetailScreen(rideId: ref.rideId),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _avatar(UserDocument user) {
    if (user.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CachedNetworkImage(
          imageUrl: user.photoURL!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(Icons.person, color: Color(0xFF1565C0), size: 28),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return _card(
      child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

/// Lists all cars for a user; tap one to edit.
class UserCarsScreen extends StatefulWidget {
  const UserCarsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<UserCarsScreen> createState() => _UserCarsScreenState();
}

class _UserCarsScreenState extends State<UserCarsScreen> {
  final _service = AdminFirestoreService();
  List<CarDocument>? _cars;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cars = await _service.getUserCars(widget.userId);
    if (mounted) {
      setState(() {
        _cars = cars;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Text(
          '${widget.userName} — Cars',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : (_cars == null || _cars!.isEmpty)
              ? Center(
                  child: Text(
                    'No cars found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cars!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final car = _cars![i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: const Icon(
                          Icons.directions_car,
                          color: Color(0xFF6D4C41),
                        ),
                        title: Text(car.name),
                        subtitle: Text(
                          [
                            if (car.year != null) '${car.year}',
                            '${car.seats} seats',
                            if (car.registrationNumber != null)
                              car.registrationNumber!,
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserCarEditScreen(
                                userId: widget.userId,
                                carId: car.id,
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class UserCarEditScreen extends StatefulWidget {
  const UserCarEditScreen({
    super.key,
    required this.userId,
    required this.carId,
  });

  final String userId;
  final String carId;

  @override
  State<UserCarEditScreen> createState() => _UserCarEditScreenState();
}

class _UserCarEditScreenState extends State<UserCarEditScreen> {
  final _service = AdminFirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _registrationCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '4');

  CarDocument? _car;
  bool _isFavourite = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    _registrationCtrl.dispose();
    _seatsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final car = await _service.getCar(widget.carId);
      if (!mounted) return;
      if (car == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Car not found')),
        );
        Navigator.pop(context);
        return;
      }
      _nameCtrl.text = car.name;
      _yearCtrl.text = car.year?.toString() ?? '';
      _registrationCtrl.text = car.registrationNumber ?? '';
      _seatsCtrl.text = car.seats.toString();
      setState(() {
        _car = car;
        _isFavourite = car.isFavourite;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _car == null) return;
    setState(() => _saving = true);
    try {
      await _service.updateCar(
        widget.carId,
        CarDocument(
          id: _car!.id,
          name: _nameCtrl.text.trim(),
          year: int.tryParse(_yearCtrl.text.trim()),
          registrationNumber: _registrationCtrl.text.trim(),
          seats: (int.tryParse(_seatsCtrl.text.trim()) ?? 4).clamp(2, 10),
          ownerId: widget.userId,
          isFavourite: _isFavourite,
          createdAt: _car!.createdAt,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Car updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('Edit car', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Car name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _yearCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _registrationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Registration number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _seatsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seats',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 2 || n > 10) return 'Enter 2–10';
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Favourite car'),
                    value: _isFavourite,
                    onChanged: (v) => setState(() => _isFavourite = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(_saving ? 'Saving…' : 'Save car'),
                  ),
                ],
              ),
            ),
    );
  }
}
