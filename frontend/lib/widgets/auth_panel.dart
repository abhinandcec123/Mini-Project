import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

enum AuthPortal { donor, hospital, admin }

Route<void> authModalRoute(Widget screen) {
  return PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
  );
}

class AuthPanel extends StatelessWidget {
  final AuthPortal portal;
  final bool isLogin;
  final bool allowRegistration;
  final String signInLabel;
  final String registrationLabel;
  final String sectionTitle;
  final String sectionDescription;
  final String footerMessage;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<AuthPortal> onPortalChanged;
  final Widget child;

  const AuthPanel({
    super.key,
    required this.portal,
    required this.isLogin,
    required this.allowRegistration,
    required this.signInLabel,
    required this.registrationLabel,
    required this.sectionTitle,
    required this.sectionDescription,
    required this.footerMessage,
    required this.onModeChanged,
    required this.onPortalChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: const ColoredBox(color: Color(0x99111A31)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width =
                    math.max(0.0, math.min(840.0, constraints.maxWidth - 24));
                final height =
                    math.max(0.0, math.min(760.0, constraints.maxHeight - 24));
                final accent = _portalColor(portal);

                return Center(
                  child: Container(
                    width: width,
                    height: height,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD8E1EA)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x400B1220),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _PanelHeader(
                            onClose: () => Navigator.of(context).maybePop()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                          child: _PortalSelector(
                            selectedPortal: portal,
                            onSelected: onPortalChanged,
                          ),
                        ),
                        if (allowRegistration)
                          _ModeTabs(
                            isLogin: isLogin,
                            accent: accent,
                            signInLabel: signInLabel,
                            registrationLabel: registrationLabel,
                            onModeChanged: onModeChanged,
                          )
                        else
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                          child: _SectionHeading(
                            title: sectionTitle,
                            description: sectionDescription,
                            accent: accent,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 650),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                        _PanelFooter(
                          message: footerMessage,
                          onCancel: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111A31),
      padding: const EdgeInsets.fromLTRB(22, 15, 12, 15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE50046),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authentication & Clinical Access',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Secure role-based access to the LifePulse network',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFB6C2D4), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close sign in',
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: const Color(0xFFB6C2D4),
          ),
        ],
      ),
    );
  }
}

class _PortalSelector extends StatelessWidget {
  final AuthPortal selectedPortal;
  final ValueChanged<AuthPortal> onSelected;

  const _PortalSelector({
    required this.selectedPortal,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Row(
          children: AuthPortal.values.map((portal) {
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: portal == AuthPortal.admin ? 0 : 8),
                child: _PortalOption(
                  portal: portal,
                  selected: portal == selectedPortal,
                  compact: compact,
                  onTap: () => onSelected(portal),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PortalOption extends StatelessWidget {
  final AuthPortal portal;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _PortalOption({
    required this.portal,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _portalColor(portal);
    final title = switch (portal) {
      AuthPortal.donor => compact ? 'Donor' : '1. Blood Donor',
      AuthPortal.hospital => compact ? 'Hospital' : '2. Hospital ER',
      AuthPortal.admin => compact ? 'Admin' : '3. Central Admin',
    };
    final subtitle = switch (portal) {
      AuthPortal.donor => 'Volunteer Portal',
      AuthPortal.hospital => 'Medical Facility',
      AuthPortal.admin => 'Triage Command',
    };
    final icon = switch (portal) {
      AuthPortal.donor => Icons.person_outline,
      AuthPortal.hospital => Icons.local_hospital_outlined,
      AuthPortal.admin => Icons.shield_outlined,
    };

    return Material(
      color: selected ? accent : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: compact ? 54 : 58,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : const Color(0xFFDCE4EC),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 17, color: selected ? Colors.white : accent),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFF263449),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon,
                        size: 19, color: selected ? Colors.white : accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF263449),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.82)
                                  : const Color(0xFF8190A3),
                              fontSize: 11,
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

class _ModeTabs extends StatelessWidget {
  final bool isLogin;
  final Color accent;
  final String signInLabel;
  final String registrationLabel;
  final ValueChanged<bool> onModeChanged;

  const _ModeTabs({
    required this.isLogin,
    required this.accent,
    required this.signInLabel,
    required this.registrationLabel,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          _ModeTab(
            label: signInLabel,
            icon: Icons.login,
            selected: isLogin,
            accent: accent,
            onTap: () => onModeChanged(true),
          ),
          _ModeTab(
            label: registrationLabel,
            icon: Icons.person_add_alt_1_outlined,
            selected: !isLogin,
            accent: accent,
            onTap: () => onModeChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17, color: selected ? accent : const Color(0xFF8290A2)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? accent : const Color(0xFF68778A),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String description;
  final Color accent;

  const _SectionHeading({
    required this.title,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.045),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Color(0xFF243449),
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF627187), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PanelFooter extends StatelessWidget {
  final String message;
  final VoidCallback onCancel;

  const _PanelFooter({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 7, 14, 7),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF008F7A)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF68778A), fontSize: 12),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

Color _portalColor(AuthPortal portal) {
  return switch (portal) {
    AuthPortal.donor => const Color(0xFF008F7A),
    AuthPortal.hospital => const Color(0xFFE50046),
    AuthPortal.admin => const Color(0xFF5145E5),
  };
}
