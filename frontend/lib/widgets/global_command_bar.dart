import 'package:flutter/material.dart';

class GlobalCommandBar extends StatelessWidget implements PreferredSizeWidget {
  final String role;
  final String profileName;
  final VoidCallback? onNewRequest;
  final ValueChanged<String>? onSwitchRole;
  final VoidCallback onLogout;
  final VoidCallback? onShowAlgorithm;

  const GlobalCommandBar({
    super.key,
    required this.role,
    required this.profileName,
    this.onSwitchRole,
    required this.onLogout,
    this.onNewRequest,
    this.onShowAlgorithm,
  });

  @override
  Size get preferredSize => const Size.fromHeight(112);

  @override
  Widget build(BuildContext context) {
    final activeColor = switch (role) {
      'donor' => const Color(0xFF059669),
      'admin' => const Color(0xFF0F172A),
      _ => const Color(0xFFE11D48),
    };
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final mobile = constraints.maxWidth < 440;
                    return Row(
                      children: [
                        const Icon(Icons.water_drop,
                            color: Color(0xFFE11D48), size: 25),
                        SizedBox(width: mobile ? 6 : 8),
                        const Text('LifePulse',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: Color(0xFF0F172A))),
                        if (!mobile) ...[
                          const SizedBox(width: 8),
                          Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle)),
                        ],
                        const Spacer(),
                        if (!compact && onNewRequest != null) ...[
                          FilledButton.icon(
                            onPressed: onNewRequest,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New Emergency Request'),
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE11D48)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                compact ? (mobile ? 88 : 180) : double.infinity,
                          ),
                          child: Chip(
                            avatar: Icon(Icons.security,
                                color: activeColor, size: mobile ? 15 : 17),
                            label: Text(
                              mobile
                                  ? roleLabel(role)
                                      .replaceAll(' Portal', '')
                                      .replaceAll(' Oversight', '')
                                      .replaceAll(' ER', '')
                                  : profileName.isEmpty
                                      ? roleLabel(role)
                                      : profileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            visualDensity: VisualDensity.compact,
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        if (compact)
                          IconButton(
                              tooltip: 'Sign out',
                              onPressed: onLogout,
                              icon: const Icon(Icons.logout, size: 19),
                              constraints: mobile
                                  ? const BoxConstraints.tightFor(
                                      width: 40, height: 40)
                                  : null,
                              padding: mobile ? EdgeInsets.zero : null)
                        else
                          IconButton(
                              tooltip: 'Sign out',
                              onPressed: onLogout,
                              icon: const Icon(Icons.logout, size: 19)),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (onShowAlgorithm != null)
                      _CommandTab(
                          label: 'AI Algorithm',
                          icon: Icons.auto_awesome_outlined,
                          onTap: onShowAlgorithm!),
                    if (onNewRequest != null)
                      TextButton.icon(
                          onPressed: onNewRequest,
                          icon: const Icon(Icons.add, size: 17),
                          label: const Text('New Request')),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        ),
      ),
    );
  }

  static String roleLabel(String role) => switch (role) {
        'donor' => 'Donor Portal',
        'admin' => 'Admin Oversight',
        _ => 'Hospital ER',
      };
}

class _CommandTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CommandTab(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF475569);
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: const TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}
