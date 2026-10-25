import 'package:flutter/material.dart';
import '../models/donor.dart';
import '../utils/location_format.dart';

/// A ranked donor row with score, distance, and automated queue status.
class DonorRankCard extends StatelessWidget {
  final Donor donor;
  final double score;
  final double? distanceKm;
  final String? matchStatus;

  const DonorRankCard({
    super.key,
    required this.donor,
    required this.score,
    required this.distanceKm,
    this.matchStatus,
  });

  Color get _scoreColor {
    if (score >= 75) return Colors.green.shade700;
    if (score >= 50) return Colors.orange.shade700;
    return Colors.blueGrey;
  }

  String get _queueLabel {
    switch (matchStatus) {
      case 'pending':
        return 'Awaiting response';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'completed':
        return 'Completed';
      default:
        return 'Up next in queue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _scoreColor.withValues(alpha: 0.15),
              child: Text(score.toStringAsFixed(1),
                  style: TextStyle(
                      color: _scoreColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(donor.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${donor.bloodGroup} • ${donor.totalDonations} donations'
                    '${distanceKm != null ? ' • ${formatDistanceKm(distanceKm!)} away' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(_queueLabel),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
