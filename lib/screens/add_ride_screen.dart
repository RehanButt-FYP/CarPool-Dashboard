import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/rides_service.dart';
class AddRideScreen extends StatefulWidget {
  const AddRideScreen({super.key});

  @override
  State<AddRideScreen> createState() => _AddRideScreenState();
}

class _AddRideScreenState extends State<AddRideScreen> {
  final _service = AdminRidesService();
  final _formKey = GlobalKey<FormState>();

  final _whatsappCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _stopsCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController(text: '09:00');
  final _endTimeCtrl = TextEditingController(text: '10:00');
  final _carNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _rideDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _whatsappCtrl.dispose();
    _driverNameCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _stopsCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _carNameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _rideDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _rideDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.createRide(
        from: _fromCtrl.text,
        to: _toCtrl.text,
        otherStopsText: _stopsCtrl.text,
        rideDate: _rideDate,
        startTimeWall: _startTimeCtrl.text.trim(),
        endTimeWall: _endTimeCtrl.text.trim(),
        driverName: _driverNameCtrl.text.trim().isEmpty
            ? AdminRidesService.defaultDriverName
            : _driverNameCtrl.text.trim(),
        carName: _carNameCtrl.text.trim().isEmpty
            ? AdminRidesService.defaultCarName
            : _carNameCtrl.text.trim(),
        whatsappPhone: _whatsappCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride added — approve it in Review Rides for Explore'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add ride: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(_rideDate, DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Add Ride',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Quick entry from WhatsApp. Ride is saved as unverified — '
              'approve it later in Review Rides.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            _field(
              _whatsappCtrl,
              label: 'WhatsApp number',
              hint: '03xx…',
              required: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(
              _driverNameCtrl,
              label: 'Driver name (optional)',
              hint: AdminRidesService.defaultDriverName,
            ),
            const SizedBox(height: 12),
            _field(_fromCtrl, label: 'From', required: true),
            const SizedBox(height: 12),
            _field(_toCtrl, label: 'To', required: true),
            const SizedBox(height: 12),
            _field(
              _stopsCtrl,
              label: 'Stops (optional)',
              hint: 'Comma separated',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                isToday
                    ? 'Today · ${DateFormat('EEE, MMM d').format(_rideDate)}'
                    : DateFormat('EEE, MMM d yyyy').format(_rideDate),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _startTimeCtrl,
                    label: 'Start',
                    hint: 'HH:mm',
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
                    label: 'End',
                    hint: 'HH:mm',
                    required: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              _carNameCtrl,
              label: 'Car name (optional)',
              hint: AdminRidesService.defaultCarName,
            ),
            const SizedBox(height: 12),
            _field(
              _notesCtrl,
              label: 'Notes (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_saving ? 'Saving…' : 'Add ride'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
