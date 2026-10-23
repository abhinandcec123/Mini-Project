import 'package:flutter/material.dart';
import '../models/blood_request.dart';
import '../utils/location_format.dart';

Color priorityColor(String priority) {
  switch (priority) {
    case 'critical':
      return const Color(0xFFE11D48);
    case 'urgent':
      return const Color(0xFFD97706);
    case 'medium':
      return const Color(0xFF0891B2);
    default:
      return const Color(0xFF64748B);
  }
}

/// Displays a BloodRequest (used in Hospital Dashboard's requisitions list).
class RequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onTap;
  final Widget? trailing;

  const RequestCard(
      {super.key, required this.request, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(request.bloodGroup,
                    style: const TextStyle(
                        color: Color(0xFFBE123C), fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${request.unitsNeeded} units  ·  ${request.status}',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      priorityColor(request.priority).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_priorityLabel(request.priority),
                    style: TextStyle(
                        color: priorityColor(request.priority),
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!
              ] else
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _priorityLabel(String priority) => switch (priority) {
      'urgent' => 'HIGH',
      'medium' => 'MEDIUM',
      'normal' => 'ROUTINE',
      _ => 'CRITICAL',
    };

/// Displays a RequestMatch (used in Donor Portal's incoming requests list).
class MatchCard extends StatelessWidget {
  final RequestMatch match;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  const MatchCard(
      {super.key, required this.match, this.onAccept, this.onDecline});

  @override
  Widget build(BuildContext context) {
    final req = match.request;
    final isCriticalPending =
        req?.priority == 'critical' && match.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCriticalPending
              ? const Color(0xFFFDA4AF)
              : const Color(0xFFE2E8F0),
          width: isCriticalPending ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    req?.hospitalName ?? 'Hospital request',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Chip(
                  label: Text(match.status),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      _statusColor(match.status).withValues(alpha: 0.15),
                  labelStyle: TextStyle(color: _statusColor(match.status)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (req != null)
              Text(
                  'Patient: ${req.patientName} • ${req.bloodGroup} • ${req.unitsNeeded} unit(s)'),
            if (match.distanceKm != null)
              Text('${formatDistanceKm(match.distanceKm!)} away',
                  style: const TextStyle(color: Colors.grey)),
            if (req?.priority == 'critical') ...[
              const SizedBox(height: 7),
              const _UrgencyTag(label: 'CRITICAL DISPATCH'),
            ],
            if (match.status == 'pending' &&
                (onAccept != null || onDecline != null)) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: onDecline, child: const Text('Decline')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onAccept,
                      child: const Text('Accept Dispatch & Route Me'),
                    ),
                  ),
                ],
              ),
            ],
            if (match.status == 'accepted') ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Accepted. Waiting for hospital approval after donation.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ],
            if (match.status == 'completed') ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.verified, size: 18, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Donation approved. Your certificate is available to download.',
                      style: TextStyle(color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green.shade700;
      case 'declined':
        return Colors.red.shade700;
      case 'completed':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade700;
    }
  }
}

class _UrgencyTag extends StatefulWidget {
  final String label;

  const _UrgencyTag({required this.label});

  @override
  State<_UrgencyTag> createState() => _UrgencyTagState();
}

class _UrgencyTagState extends State<_UrgencyTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      lowerBound: 0.1,
      upperBound: 0.3,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48).withValues(alpha: _pulse.value),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(widget.label,
            style: const TextStyle(
                color: Color(0xFFBE123C),
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}
