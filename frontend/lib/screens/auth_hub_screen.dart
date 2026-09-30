import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'admin_login_screen.dart';
import 'donor_auth_screen.dart';
import 'hospital_auth_screen.dart';
import '../widgets/auth_panel.dart';

class AuthHubView extends StatelessWidget {
  const AuthHubView({super.key});

  Widget _authScreen(BuildContext context, AuthPortal portal) {
    void selectPortal(AuthPortal nextPortal) {
      Navigator.of(context).pushReplacement(
        authModalRoute(_authScreen(context, nextPortal)),
      );
    }

    return switch (portal) {
      AuthPortal.donor => DonorAuthScreen(onPortalChanged: selectPortal),
      AuthPortal.hospital => HospitalAuthScreen(onPortalChanged: selectPortal),
      AuthPortal.admin => AdminLoginScreen(onPortalChanged: selectPortal),
    };
  }

  void _open(BuildContext context, AuthPortal portal) {
    Navigator.of(context).push(authModalRoute(_authScreen(context, portal)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _PortalHeader(
              onDonorTap: () => _open(context, AuthPortal.donor),
              onHospitalTap: () => _open(context, AuthPortal.hospital),
              onAdminTap: () => _open(context, AuthPortal.admin),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth >= 760 ? 32.0 : 18.0;
                  final contentWidth = math.min(
                    constraints.maxWidth - horizontalPadding * 2,
                    1500.0,
                  );
                  final cardWidth = contentWidth >= 900
                      ? (contentWidth - 36) / 3
                      : contentWidth;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: constraints.maxWidth >= 760 ? 48 : 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _IntroPanel(),
                            const SizedBox(height: 34),
                            Text(
                              'PORTAL ACCESS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: const Color(0xFF637181),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 18,
                              runSpacing: 18,
                              alignment: WrapAlignment.center,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _PortalCard(
                                    number: 'PORTAL 1: DONOR',
                                    icon: Icons.person_pin_circle_outlined,
                                    title: 'Blood Donor Portal',
                                    subtitle:
                                        'For volunteer donors responding to emergency blood requests.',
                                    actionLabel: 'Continue as donor',
                                    accent: const Color(0xFF00A98F),
                                    tint: const Color(0xFFE7F8F4),
                                    onTap: () =>
                                        _open(context, AuthPortal.donor),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _PortalCard(
                                    number: 'PORTAL 2: HOSPITAL',
                                    icon: Icons.local_hospital_outlined,
                                    title: 'Hospital & ER Portal',
                                    subtitle:
                                        'Create urgent blood requests and coordinate donor matches.',
                                    actionLabel: 'Continue as hospital',
                                    accent: const Color(0xFFE50046),
                                    tint: const Color(0xFFFFEAF0),
                                    onTap: () =>
                                        _open(context, AuthPortal.hospital),
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _PortalCard(
                                    number: 'PORTAL 3: ADMIN',
                                    icon: Icons.shield_outlined,
                                    title: 'Triage Command Admin',
                                    subtitle:
                                        'Oversee network activity, donor accounts, hospitals, and requests.',
                                    actionLabel: 'Continue as admin',
                                    accent: const Color(0xFF5145E5),
                                    tint: const Color(0xFFEFEEFF),
                                    onTap: () =>
                                        _open(context, AuthPortal.admin),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalHeader extends StatelessWidget {
  final VoidCallback onDonorTap;
  final VoidCallback onHospitalTap;
  final VoidCallback onAdminTap;

  const _PortalHeader({
    required this.onDonorTap,
    required this.onHospitalTap,
    required this.onAdminTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final brand = _BrandLockup(compact: !isWide);
        final navigation = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E7EF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HeaderItem(
                icon: Icons.grid_view_rounded,
                label: '3 Portals Hub',
                selected: true,
                color: Color(0xFFE50046),
              ),
              _HeaderItem(
                icon: Icons.person_outline,
                label: 'Donor',
                color: const Color(0xFF008C78),
                onTap: onDonorTap,
              ),
              _HeaderItem(
                icon: Icons.local_hospital_outlined,
                label: 'Hospital',
                color: const Color(0xFFE50046),
                onTap: onHospitalTap,
              ),
              _HeaderItem(
                icon: Icons.shield_outlined,
                label: 'Admin',
                color: const Color(0xFF5145E5),
                onTap: onAdminTap,
              ),
            ],
          ),
        );

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE3E9F0))),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 18,
                  vertical: 14,
                ),
                child: isWide
                    ? Row(
                        children: [
                          brand,
                          const Spacer(),
                          navigation,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          brand,
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: navigation,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandLockup extends StatelessWidget {
  final bool compact;

  const _BrandLockup({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFE50046),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.monitor_heart_outlined,
              color: Colors.white, size: 29),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                const Text(
                  'LifePulse AI',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!compact)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAFBF8),
                      border: Border.all(color: const Color(0xFF9CE5D8)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 13, color: Color(0xFF007F70)),
                        SizedBox(width: 5),
                        Text(
                          'Weighted AI Engine',
                          style: TextStyle(
                            color: Color(0xFF007F70),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              const Text(
                'Emergency multi-donor matching & weighted recommendations',
                style: TextStyle(color: Color(0xFF718096), fontSize: 13),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeaderItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _HeaderItem({
    required this.icon,
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: const Color(0xFFD6E0E9)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF172033) : color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  const _IntroPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 36,
            vertical: isCompact ? 32 : 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDDE6EE)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A24364B),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAF0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, color: Color(0xFFB32657), size: 16),
                    SizedBox(width: 7),
                    Text(
                      'Dedicated Emergency Medical Portals',
                      style: TextStyle(
                        color: Color(0xFF9D214C),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Secure LifePulse Access Hub',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  'Choose your clinical role to register or sign in. Hospitals can create requests, donors can respond, and administrators can oversee the network.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF526174),
                        height: 1.5,
                      ),
                ),
              ),
              const SizedBox(height: 20),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 9,
                runSpacing: 9,
                children: [
                  _InfoPill(
                    icon: Icons.lock_outline,
                    label: 'Role-based sign-in',
                  ),
                  _InfoPill(
                    icon: Icons.storage_outlined,
                    label: 'Shared donor network',
                  ),
                  _InfoPill(
                    icon: Icons.location_on_outlined,
                    label: 'Location-aware matching',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF526174)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF526174), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color accent;
  final Color tint;
  final VoidCallback onTap;

  const _PortalCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 286),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(17),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.22)),
                          ),
                          child: Icon(icon, color: accent, size: 27),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              number,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF172033),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF526174),
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: onTap,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: Text(actionLabel),
                        style: FilledButton.styleFrom(
                          foregroundColor: accent,
                          backgroundColor: tint,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
