import 'package:flutter/material.dart';
import '../models/donor.dart';
import '../utils/location_format.dart';

/// A ranked donor row in the AI Recommendation view, with score + distance
/// and a "Send Request" action (mirrors the original AIRecommendationView).
class DonorRankCard extends StatelessWidget {
  final Donor donor;
  final double score;
  final double? distanceKm;
  final bool alreadyDispatched;
  final VoidCallback onDispatch;

  const DonorRankCard({
    super.key,
    required this.donor,
    required this.score,
    required this.distanceKm,
    required this.alreadyDispatched,
    required this.onDispatch,
  });

  Color get _scoreColor {
    if (score >= 75) return Colors.green.shade700;
    if (score >= 50) return Colors.orange.shade700;
    return Colors.blueGrey;
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
              child: Text(score.toStringAsFixed(0),
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
                  Text(
                    'Reliability ${donor.reliabilityScore.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            alreadyDispatched
                ? const Chip(
                    label: Text('Sent'), visualDensity: VisualDensity.compact)
                : FilledButton(
                    onPressed: onDispatch, child: const Text('Send')),
          ],
        ),
      ),
    );
  }
}
