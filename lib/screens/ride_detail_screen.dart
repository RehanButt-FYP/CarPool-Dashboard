import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/ride_document.dart';
import '../services/rides_service.dart';

class RideDetailScreen extends StatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _service = AdminRidesService();
  final _formKey = GlobalKey<FormState>();

  RideWithDriver? _item;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final TextEditingController _stopsCtrl;
  late final TextEditingController _driverNameCtrl;
  late final TextEditingController _carNameCtrl;
  late final TextEditingController _carIdCtrl;
  late final TextEditingController _carYearCtrl;
  late final TextEditingController _startTimeCtrl;
  late final TextEditingController _endTimeCtrl;
  late final TextEditingController _fareCtrl;
  late final TextEditingController _totalSeatsCtrl;
  late final TextEditingController _availableSeatsCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _driverIdCtrl;

  DateTime? _rideDate;
  String _driverVerificationStatus = RideDriverVerificationStatus.pending;
  bool _isEnable = true;
  bool? _isActive;
  String? _rideStatus;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController();
    _toCtrl = TextEditingController();
    _stopsCtrl = TextEditingController();
    _driverNameCtrl = TextEditingController();
    _carNameCtrl = TextEditingController();
    _carIdCtrl = TextEditingController();
    _carYearCtrl = TextEditingController();
    _startTimeCtrl = TextEditingController();
    _endTimeCtrl = TextEditingController();
    _fareCtrl = TextEditingController();
    _totalSeatsCtrl = TextEditingController();
    _availableSeatsCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _whatsappCtrl = TextEditingController();
    _driverIdCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _stopsCtrl.dispose();
    _driverNameCtrl.dispose();
    _carNameCtrl.dispose();
    _carIdCtrl.dispose();
    _carYearCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _fareCtrl.dispose();
    _totalSeatsCtrl.dispose();
    _availableSeatsCtrl.dispose();
    _notesCtrl.dispose();
    _whatsappCtrl.dispose();
    _driverIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await _service.getRide(widget.rideId);
      if (!mounted) return;
      if (item == null) {
        setState(() => _error = 'Ride not found');
        return;
      }
      _applyRide(item);
      setState(() => _item = item);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyRide(RideWithDriver item) {
    final ride = item.ride;
    _fromCtrl.text = ride.fromLocation;
    _toCtrl.text = ride.toLocation;
    _stopsCtrl.text = ride.otherStopsText;
    _driverNameCtrl.text = ride.driverName;
    _driverIdCtrl.text = ride.driverId ?? '';
    _carNameCtrl.text = ride.carName;
    _carIdCtrl.text = ride.carId ?? '';
    _carYearCtrl.text = ride.carYear?.toString() ?? '';
    _startTimeCtrl.text = ride.startTimeWall;
    _endTimeCtrl.text = ride.endTimeWall;
    _fareCtrl.text = ride.rideFare;
    _totalSeatsCtrl.text = ride.totalSeats.toString();
    _availableSeatsCtrl.text = ride.availableSeats.toString();
    _notesCtrl.text = ride.driverNotes ?? '';
    _whatsappCtrl.text = ride.whatsappPhone ?? '';
    _rideDate = ride.rideDate ?? ride.startTimestamp ?? DateTime.now();
    _driverVerificationStatus = ride.driverVerificationStatus;
    _isEnable = ride.isEnable;
    _isActive = ride.isActive;
    _rideStatus = ride.rideStatus;
  }

  Future<void> _pickRideDate() async {
    final initial = _rideDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _rideDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final total = int.tryParse(_totalSeatsCtrl.text.trim());
    final available = int.tryParse(_availableSeatsCtrl.text.trim());
    if (total == null || total < 1) {
      _snack('Enter valid total seats', success: false);
      return;
    }
    if (available == null || available < 0 || available > total) {
      _snack('Available seats must be between 0 and $total', success: false);
      return;
    }
    if (_rideDate == null) {
      _snack('Select a ride date', success: false);
      return;
    }

    final carYear = int.tryParse(_carYearCtrl.text.trim());

    setState(() => _saving = true);
    try {
      await _service.saveRideEdits(
        rideId: widget.rideId,
        from: _fromCtrl.text,
        to: _toCtrl.text,
        otherStopsText: _stopsCtrl.text,
        driverName: _driverNameCtrl.text,
        carName: _carNameCtrl.text,
        carId: _carIdCtrl.text,
        carYear: carYear,
        rideDate: _rideDate!,
        startTimeWall: _startTimeCtrl.text.trim(),
        endTimeWall: _endTimeCtrl.text.trim(),
        rideFare: _fareCtrl.text,
        totalSeats: total,
        availableSeats: available,
        notes: _notesCtrl.text,
        whatsappPhone: _whatsappCtrl.text,
        rideStatus: _rideStatus,
        isEnable: _isEnable,
        isActive: _isActive,
        driverVerificationStatus: _driverVerificationStatus,
      );
      if (mounted) {
        _snack('Ride updated', success: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack('Save failed: $e', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red[700],
      ),
    );
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
          'Edit ride',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : _error != null
              ? _buildError()
              : Form(
                  key: _formKey,
                  child: _buildContent(),
                ),
      bottomNavigationBar: _item == null || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final item = _item!;
    final dateFmt = DateFormat('EEE, MMM d yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      item.ride.driverVerificationStatus,
                      item.ride.isRideVerified
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                    _statusChip(
                      item.driverIsVerified
                          ? 'Verified driver'
                          : 'Unverified driver',
                      item.driverIsVerified
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF6D4C41),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is the ride\'s driverVerificationStatus field (Pending / Verified), '
                  'separate from the user account. A ride posted before approval stays Pending until you set it here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Driver verification status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: RideDriverVerificationStatus.pending,
                      label: Text('Pending'),
                      icon: Icon(Icons.pending_outlined),
                    ),
                    ButtonSegment(
                      value: RideDriverVerificationStatus.verified,
                      label: Text('Verified'),
                      icon: Icon(Icons.verified_outlined),
                    ),
                  ],
                  selected: {_driverVerificationStatus},
                  onSelectionChanged: (s) => setState(
                    () => _driverVerificationStatus = s.first,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only Verified rides appear on Explore in the carpool app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Route'),
          _card(
            child: Column(
              children: [
                _field(_fromCtrl, label: 'From', required: true),
                const SizedBox(height: 12),
                _field(_toCtrl, label: 'To', required: true),
                const SizedBox(height: 12),
                _field(
                  _stopsCtrl,
                  label: 'Other stops',
                  hint: 'Comma or hyphen separated',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Schedule'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ride date'),
                  subtitle: Text(
                    _rideDate != null
                        ? dateFmt.format(_rideDate!)
                        : 'Not set',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickRideDate,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _startTimeCtrl,
                        label: 'Start time',
                        hint: 'HH:mm (24h)',
                        required: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _endTimeCtrl,
                        label: 'End time',
                        hint: 'HH:mm (24h)',
                        required: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Driver & vehicle'),
          _card(
            child: Column(
              children: [
                _field(_driverNameCtrl, label: 'Driver name', required: true),
                const SizedBox(height: 12),
                _field(
                  _driverIdCtrl,
                  label: 'Driver ID',
                  readOnly: true,
                ),
                const SizedBox(height: 12),
                _field(_carNameCtrl, label: 'Car name', required: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _field(_carIdCtrl, label: 'Car ID (optional)'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _carYearCtrl,
                        label: 'Year',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Pricing & capacity'),
          _card(
            child: Column(
              children: [
                _field(
                  _fareCtrl,
                  label: 'Fare (Rs)',
                  required: true,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _totalSeatsCtrl,
                        label: 'Total seats',
                        required: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _availableSeatsCtrl,
                        label: 'Available seats',
                        required: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Contact & notes'),
          _card(
            child: Column(
              children: [
                _field(
                  _whatsappCtrl,
                  label: 'WhatsApp phone',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  _notesCtrl,
                  label: 'Driver notes',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionTitle('Platform'),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  subtitle: const Text('When off, ride is hidden from listings'),
                  value: _isEnable,
                  onChanged: (v) => setState(() => _isEnable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active flag'),
                  subtitle: const Text('Optional isActive field on document'),
                  value: _isActive ?? false,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _rideStatus,
                  decoration: const InputDecoration(
                    labelText: 'Ride status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Active')),
                    DropdownMenuItem(
                      value: 'canceled',
                      child: Text('Canceled'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _rideStatus = v),
                ),
                if (item.ride.requestCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${item.ride.requestCount} passenger request(s) on this ride',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          letterSpacing: 0.3,
        ),
      ),
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

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            }
          : null,
    );
  }
}
