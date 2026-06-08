import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/ride_document.dart';
import '../services/rides_service.dart';
import 'ride_detail_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key, this.initialFilter});

  final RidesListFilter? initialFilter;

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  final _service = AdminRidesService();
  late RidesListFilter _filter;
  List<RideWithDriver>? _rides;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? RidesListFilter.unverifiedDrivers;
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = _rides == null;
      _error = null;
    });
    try {
      final rides = await _service.loadRides(
        filter: _filter,
        forceRefresh: forceRefresh,
      );
      if (mounted) setState(() => _rides = rides);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
        title: const Text(
          'Rides',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Full refresh',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              'Unverified drivers',
              RidesListFilter.unverifiedDrivers,
              Icons.person_off_outlined,
            ),
            const SizedBox(width: 8),
            _filterChip(
              'Pending rides',
              RidesListFilter.unverifiedRides,
              Icons.pending_outlined,
            ),
            const SizedBox(width: 8),
            _filterChip(
              'All rides',
              RidesListFilter.all,
              Icons.list_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, RidesListFilter value, IconData icon) {
    final selected = _filter == value;
    const primary = Color(0xFF1565C0);
    final background = selected ? Colors.white : Colors.white.withValues(alpha: 0.18);
    final foreground = selected ? primary : Colors.white;
    final border = selected
        ? Border.all(color: Colors.white, width: 1.5)
        : Border.all(color: Colors.white.withValues(alpha: 0.45));

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          if (_filter == value) return;
          setState(() => _filter = value);
          _load();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 48),
              const SizedBox(height: 12),
              Text('Failed to load rides', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final rides = _rides ?? [];
    if (rides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _emptyMessage(),
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(forceRefresh: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _RideCard(
          item: rides[index],
          onTap: () async {
            final updated = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => RideDetailScreen(rideId: rides[index].ride.id),
              ),
            );
            if (updated == true && mounted) _load();
          },
        ),
      ),
    );
  }

  String _emptyMessage() {
    return switch (_filter) {
      RidesListFilter.unverifiedDrivers =>
        'No upcoming rides from unverified drivers.',
      RidesListFilter.unverifiedRides =>
        'No upcoming rides with Pending verification.',
      RidesListFilter.all => 'No upcoming or in-progress rides.',
    };
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.item, required this.onTap});

  final RideWithDriver item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ride = item.ride;
    final dateFmt = DateFormat('MMM d, yyyy · HH:mm');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _driverAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ride.driverName.isNotEmpty
                                ? ride.driverName
                                : 'Unknown driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        _badge(
                          ride.isRideVerified ? 'Verified' : 'Pending',
                          ride.isRideVerified
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ride.routeLabel,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs ${ride.rideFare} · ${ride.availableSeats}/${ride.totalSeats} seats',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (ride.startTimestamp != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateFmt.format(ride.startTimestamp!),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(
                          item.driverIsVerified
                              ? 'Driver verified'
                              : 'Driver unverified',
                          item.driverIsVerified
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF6D4C41),
                        ),
                        if (ride.isCanceled)
                          _badge('Canceled', Colors.red[700]!),
                        if (!ride.isEnable)
                          _badge('Disabled', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverAvatar() {
    final url = item.ride.driverPhotoURL?.trim() ?? '';
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _defaultAvatar(),
        ),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.person, color: Color(0xFF1565C0)),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
}
