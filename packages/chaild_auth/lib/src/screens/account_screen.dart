import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chaild_auth_config.dart';
import '../config/chaild_constants.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../services/biometric_service.dart';
import '../services/two_factor_service.dart';
import '../widgets/chaild_button.dart';
import 'two_factor_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSignedOut;

  const AccountScreen({super.key, this.onSignedOut});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _twoFactorEnrolled = false;
  bool _sectionSecurityOpen = false;
  bool _sectionSubOpen = true;
  bool _sectionAboutOpen = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
    _loadTwoFactorState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.instance.isAvailable();
    final enabled = await BiometricService.instance.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _loadTwoFactorState() async {
    final enrolled = await TwoFactorService.instance.isEnrolled();
    if (mounted) setState(() => _twoFactorEnrolled = enrolled);
  }

  Future<void> _toggleBiometric(bool value) async {
    await BiometricService.instance.setEnabled(value);
    setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final sub = ref.watch(subscriptionControllerProvider);
    final user = auth.user;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ChailConstants.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: ChailColors.primary.withOpacity(0.15),
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            (user.name?.isNotEmpty == true
                                    ? user.name![0]
                                    : user.email[0])
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: ChailColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  if (user.name != null && user.name!.isNotEmpty)
                    Text(user.name!,
                        style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          )),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Subscription (collapsible) ─────────────────────────────────
            _CollapsibleSection(
              title: 'Subscription',
              icon: Icons.bolt_rounded,
              isOpen: _sectionSubOpen,
              onToggle: () => setState(() => _sectionSubOpen = !_sectionSubOpen),
              children: [
                _Row(
                  icon: Icons.bolt_rounded,
                  iconColor: ChailColors.primary,
                  label: 'Status',
                  trailing: sub.isActive
                      ? _Badge('Active', ChailColors.success)
                      : _Badge('Inactive', ChailColors.error),
                ),
                if (sub.subscription?.expiresAt != null)
                  _Row(
                    icon: Icons.calendar_today_outlined,
                    label: 'Renews',
                    trailing: Text(
                      _formatDate(sub.subscription!.expiresAt!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (sub.subscription?.plan != null)
                  _Row(
                    icon: Icons.receipt_long_outlined,
                    label: 'Plan',
                    trailing: Text(
                      sub.subscription!.plan![0].toUpperCase() +
                          sub.subscription!.plan!.substring(1),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Security (collapsible) ─────────────────────────────────────
            _CollapsibleSection(
              title: 'Security',
              icon: Icons.shield_outlined,
              isOpen: _sectionSecurityOpen,
              onToggle: () => setState(() => _sectionSecurityOpen = !_sectionSecurityOpen),
              children: [
                if (_biometricAvailable)
                  ListTile(
                    leading: Icon(
                      Icons.fingerprint,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                    title: Text('Biometric Unlock',
                        style: Theme.of(context).textTheme.bodyMedium),
                    trailing: Switch(
                      value: _biometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                  ),
                _Row(
                  icon: Icons.qr_code_scanner_rounded,
                  label: _twoFactorEnrolled
                      ? 'Two-Factor Auth (enabled)'
                      : 'Set Up Two-Factor Auth',
                  iconColor: _twoFactorEnrolled ? ChailColors.success : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TwoFactorSetupScreen(
                        onDone: () {
                          Navigator.pop(context);
                          _loadTwoFactorState();
                        },
                      ),
                    ),
                  ),
                ),
                if (ChailAuth.appLockTimeout != null)
                  _Row(
                    icon: Icons.timer_outlined,
                    label: 'App Lock Timeout',
                    trailing: Text(
                      _formatTimeout(ChailAuth.appLockTimeout!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── About (collapsible) ────────────────────────────────────────
            _CollapsibleSection(
              title: 'About',
              icon: Icons.info_outline_rounded,
              isOpen: _sectionAboutOpen,
              onToggle: () => setState(() => _sectionAboutOpen = !_sectionAboutOpen),
              children: [
                _Row(
                  icon: Icons.language_rounded,
                  label: 'Chaild Website',
                  onTap: () {},
                ),
                _Row(
                  icon: Icons.code_rounded,
                  label: 'Developer Portal',
                  onTap: () {},
                ),
                _Row(
                  icon: Icons.tag_rounded,
                  label: 'Version',
                  trailing: Text(
                    '1.0.0',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Account Actions ────────────────────────────────────────────
            _SectionCard(
              children: [
                _Row(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).signOut();
                    widget.onSignedOut?.call();
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Danger Zone ────────────────────────────────────────────────
            _SectionCard(
              children: [
                _Row(
                  icon: Icons.delete_outline_rounded,
                  iconColor: ChailColors.error,
                  label: 'Delete Account',
                  labelColor: ChailColors.error,
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),

            const SizedBox(height: 32),

            Center(
              child: Text(
                'chaild auth sdk',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.25),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This is permanent. All your data will be deleted and cannot be recovered.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: ChailColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';

  String _formatTimeout(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}

// ── Small internal widgets ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ChailConstants.radiusL),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: children
            .expand((w) => [w, const Divider(height: 1, indent: 52)])
            .toList()
          ..removeLast(),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({
    required this.icon,
    this.iconColor,
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon,
          color: iconColor ??
              Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          size: 20),
      title: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: labelColor)),
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.3))
          : null),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isOpen;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.icon,
    required this.isOpen,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(ChailConstants.radiusL),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(ChailConstants.radiusL),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Icon(
                    isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1),
            ...children
                .expand((w) => [w, const Divider(height: 1, indent: 52)])
                .toList()
              ..removeLast(),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(ChailConstants.radiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}


