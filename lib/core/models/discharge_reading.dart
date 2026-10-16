import 'dart:typed_data';

/// One flow-meter discharge reading recorded by a technician on-site —
/// timestamped and backed by a geo-located photo of the meter as evidence.
class DischargeReading {
  const DischargeReading({
    required this.lps,
    required this.recordedAt,
    this.photoBytes,
    this.latitude,
    this.longitude,
  });

  final double lps;
  final DateTime recordedAt;

  /// Raw image bytes, kept in memory for this session only (no backend to
  /// upload to) — stored as bytes rather than a file path so display works
  /// identically via [Image.memory] on web and on device.
  final Uint8List? photoBytes;

  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;
}
