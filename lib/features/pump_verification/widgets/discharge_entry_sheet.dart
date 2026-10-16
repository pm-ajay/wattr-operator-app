import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/dummy_data/providers.dart';
import '../../../core/models/discharge_reading.dart';
import '../../../core/models/pump.dart';
import '../../../core/theme/status_colors.dart';

Future<bool> showDischargeEntrySheet(BuildContext context, {required Pump pump}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _DischargeEntryForm(pump: pump),
    ),
  );
  return saved ?? false;
}

enum _LocationStatus { fetching, available, unavailable }

class _DischargeEntryForm extends ConsumerStatefulWidget {
  const _DischargeEntryForm({required this.pump});

  final Pump pump;

  @override
  ConsumerState<_DischargeEntryForm> createState() => _DischargeEntryFormState();
}

class _DischargeEntryFormState extends ConsumerState<_DischargeEntryForm> {
  final _lpsController = TextEditingController();
  Uint8List? _photoBytes;
  _LocationStatus _locationStatus = _LocationStatus.fetching;
  double? _lat;
  double? _lng;
  String? _lpsError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _lpsController.dispose();
    super.dispose();
  }

  /// Best-effort — a technician can still submit the reading if location
  /// isn't available (permission denied, GPS off, etc.), since the LPS
  /// reading and photo are the parts that actually matter.
  Future<void> _fetchLocation() async {
    setState(() => _locationStatus = _LocationStatus.fetching);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationStatus = _LocationStatus.unavailable);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _locationStatus = _LocationStatus.unavailable);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationStatus = _LocationStatus.available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationStatus = _LocationStatus.unavailable);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access the camera or photo library on this device.')),
      );
    }
  }

  Future<void> _submit() async {
    final lps = double.tryParse(_lpsController.text);
    setState(() => _lpsError = (lps == null || lps <= 0) ? 'Enter a discharge rate greater than 0' : null);
    if (_lpsError != null) return;

    setState(() => _isSaving = true);
    final reading = DischargeReading(
      lps: lps!,
      recordedAt: DateTime.now(),
      photoBytes: _photoBytes,
      latitude: _lat,
      longitude: _lng,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(pumpsProvider.notifier).recordDischarge(widget.pump.id, reading);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter Discharge', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Recorded with the current time and, where available, your location.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lpsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: InputDecoration(
                  labelText: 'Discharge Rate',
                  suffixText: 'LPS',
                  isDense: true,
                  errorText: _lpsError,
                ),
              ),
              const SizedBox(height: 20),
              Text('Flow Meter Photo', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_photoBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_photoBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(_photoBytes == null ? 'Take Photo' : 'Retake'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Choose'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Location', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _LocationRow(status: _locationStatus, lat: _lat, lng: _lng, onRetry: _fetchLocation),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Reading'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.status, required this.lat, required this.lng, required this.onRetry});

  final _LocationStatus status;
  final double? lat;
  final double? lng;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return switch (status) {
      _LocationStatus.fetching => Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Fetching location…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      _LocationStatus.available => Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: StatusColors.good),
            const SizedBox(width: 6),
            Expanded(child: Text('${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}')),
          ],
        ),
      _LocationStatus.unavailable => Row(
          children: [
            Icon(Icons.location_off_outlined, size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 6),
            Expanded(child: Text('Location unavailable', style: TextStyle(color: theme.colorScheme.outline))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
    };
  }
}
