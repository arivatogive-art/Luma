// Pfad: lib/presentation/screens/security_settings_screen.dart
//
// Luma Core Rebuild 2.0 - Sicherheit & Anmeldung, Phase C1.
// Bestehende Settings, echte Geräte-Dokumente, Remote-Logout und
// read-only Sicherheitsereignisse aus users/{uid}/security_events.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../application/settings_state.dart';
import '../../data/settings_repository.dart';
import '../../features/security/application/security_devices_controller.dart';
import '../../features/security/application/security_events_controller.dart';
import '../../features/security/application/security_remote_logout_service.dart';
import '../../features/security/domain/security_device_model.dart';
import '../../features/security/domain/security_event_model.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SettingsRepository _settingsRepository = SettingsRepository();
  late final SecurityDevicesController _devicesController;
  late final SecurityEventsController _eventsController;
  late final SecurityRemoteLogoutService _remoteLogoutService;

  SettingsState? _settings;
  User? _user;
  bool _isLoading = true;
  bool _isEndingOtherSessions = false;
  String? _currentDeviceId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _devicesController = SecurityDevicesController();
    _eventsController = SecurityEventsController();
    _remoteLogoutService = SecurityRemoteLogoutService();
    _devicesController.addListener(_onDevicesChanged);
    _eventsController.addListener(_onEventsChanged);
    _load();
  }

  @override
  void dispose() {
    _devicesController.removeListener(_onDevicesChanged);
    _eventsController.removeListener(_onEventsChanged);
    _devicesController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  void _onDevicesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onEventsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final currentUser = _auth.currentUser;
      final userId = currentUser?.uid.trim() ?? '';

      if (currentUser == null || userId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _user = null;
          _settings = null;
          _isLoading = false;
          _errorMessage =
              'Deine Sicherheitsinformationen konnten nicht geladen werden, '
              'weil keine aktive Anmeldung gefunden wurde.';
        });
        return;
      }

      try {
        await currentUser.reload();
      } catch (_) {
        // Die bestehende Sitzung bleibt die read-only Datenquelle.
      }

      final refreshedUser = _auth.currentUser ?? currentUser;

      final results = await Future.wait<Object?>([
        _settingsRepository.loadSettings(userId),
        _devicesController.load(userId: userId),
        _eventsController.load(userId: userId),
        _remoteLogoutService.loadCurrentDeviceId(),
      ]);

      final remoteSettings = results.first;
      final resolvedSettings = remoteSettings is SettingsRemoteSnapshot
          ? remoteSettings.state
          : const SettingsState.initial();
      final currentDeviceId = results.length > 3 && results[3] is String
          ? (results[3] as String).trim()
          : '';

      if (!mounted) return;
      setState(() {
        _user = refreshedUser;
        _settings = resolvedSettings;
        _currentDeviceId = currentDeviceId.isEmpty ? null : currentDeviceId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Die Sicherheitsinformationen konnten gerade nicht geladen werden.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? LumaTheme.darkBackground
        : const Color(0xFFF8F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Sicherheit & Anmeldung',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.25),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: LumaTheme.lumaOrange,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const _ScrollableCenter(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(LumaTheme.lumaOrange),
        ),
      );
    }

    if (_errorMessage != null) {
      return _ScrollableCenter(
        child: _ErrorCard(message: _errorMessage!, onRetry: _load),
      );
    }

    final user = _user;
    final settings = _settings;

    if (user == null || settings == null) {
      return _ScrollableCenter(
        child: _ErrorCard(
          message: 'Für diese Sitzung konnten keine Sicherheitsdaten gefunden werden.',
          onRetry: _load,
        ),
      );
    }

    final signInMethods = _providerLabels(user);
    final timeline = settings.securityTimelineSummary;
    final deviceSummary = settings.securityDeviceSummary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
      children: [
        _SecurityIntro(
          emailVerified: user.emailVerified,
          twoFactorEnabled: settings.hasConfiguredTwoFactor,
          loginAlertsEnabled: settings.loginAlertsEnabled,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.lock_person_outlined,
          title: 'Kontoschutz',
          subtitle:
              'Die wichtigsten Schutzinformationen deiner aktuellen Anmeldung.',
        ),
        const SizedBox(height: 12),
        _SecurityCard(
          children: [
            _StatusRow(
              icon: Icons.login_rounded,
              title: 'Anmeldemethode',
              value: signInMethods.isEmpty
                  ? 'Nicht eindeutig erkannt'
                  : signInMethods.join(', '),
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.alternate_email_rounded,
              title: 'E-Mail',
              value: _emailLabel(user),
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.verified_user_outlined,
              title: 'Zwei-Faktor-Schutz',
              value: settings.hasConfiguredTwoFactor
                  ? _twoFactorLabel(settings.twoFactorMethod)
                  : 'Nicht eingerichtet',
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.notifications_active_outlined,
              title: 'Login-Warnungen',
              value: settings.loginAlertsEnabled ? 'Aktiv' : 'Deaktiviert',
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Anmeldeaktivität',
          subtitle:
              'Zeitpunkte, die Luma bereits zuverlässig für dein Konto kennt.',
        ),
        const SizedBox(height: 12),
        _SecurityCard(
          children: [
            _StatusRow(
              icon: Icons.check_circle_outline_rounded,
              title: 'Letzte erfolgreiche Anmeldung',
              value: _formatDateTime(timeline.lastSuccessfulLoginAt),
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.shield_outlined,
              title: 'Letzte Sicherheitsaktivität',
              value: _formatDateTime(timeline.lastSecurityEventAt),
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.password_rounded,
              title: 'Letzte Passwortänderung',
              value: _formatDateTime(timeline.lastPasswordChangedAt),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.security_update_good_outlined,
          title: 'Sicherheitsaktivitäten',
          subtitle: 'Echte Sicherheitsereignisse, die bereits für dein Konto gespeichert wurden.',
        ),
        const SizedBox(height: 12),
        _buildSecurityEvents(),
        const SizedBox(height: 24),
        const _SectionHeader(
          icon: Icons.devices_outlined,
          title: 'Geräte & Sitzungen',
          subtitle:
              'Geräte, die bereits im Sicherheitsbereich deines Kontos '
              'gespeichert sind.',
        ),
        const SizedBox(height: 12),
        _SecurityCard(
          children: [
            _StatusRow(
              icon: Icons.phonelink_lock_outlined,
              title: 'Gespeicherte Zusammenfassung',
              value: _countLabel(
                deviceSummary.activeSessionCount,
                singular: 'aktive Sitzung',
                plural: 'aktive Sitzungen',
              ),
            ),
            const _CardDivider(),
            _StatusRow(
              icon: Icons.verified_outlined,
              title: 'Vertrauenswürdige Geräte',
              value: _countLabel(
                deviceSummary.trustedDeviceCount,
                singular: 'Gerät',
                plural: 'Geräte',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDeviceList(),
        const SizedBox(height: 14),
        _buildRemoteLogoutAction(),
      ],
    );
  }

  Widget _buildSecurityEvents() {
    if (_eventsController.isLoading) {
      return const _SecurityCard(
        children: [
          Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(LumaTheme.lumaOrange),
              ),
            ),
          ),
        ],
      );
    }

    final error = _eventsController.errorMessage;
    if (error != null) {
      return _InlineInfoCard(
        icon: Icons.info_outline_rounded,
        title: 'Sicherheitsaktivitäten nicht verfügbar',
        text: error,
      );
    }

    final events = _eventsController.events;

    if (events.isEmpty) {
      return const _InlineInfoCard(
        icon: Icons.history_toggle_off_rounded,
        title: 'Noch keine Sicherheitsereignisse',
        text: 'Für dieses Konto wurden bisher keine einzelnen Sicherheitsereignisse gespeichert.',
      );
    }

    return Column(
      children: [
        for (final event in events) ...[
          _SecurityEventCard(event: event),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDeviceList() {
    if (_devicesController.isLoading) {
      return const _SecurityCard(
        children: [
          Padding(
            padding: EdgeInsets.all(18),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(LumaTheme.lumaOrange),
              ),
            ),
          ),
        ],
      );
    }

    final error = _devicesController.errorMessage;
    if (error != null) {
      return _InlineInfoCard(
        icon: Icons.info_outline_rounded,
        title: 'Geräteliste nicht verfügbar',
        text: error,
      );
    }

    final devices = _devicesController.devices;

    if (devices.isEmpty) {
      return const _InlineInfoCard(
        icon: Icons.devices_other_rounded,
        title: 'Noch keine Geräte gespeichert',
        text:
            'Für dieses Konto wurden bisher keine einzelnen Geräte-Dokumente '
            'gefunden.',
      );
    }

    return Column(
      children: [
        for (final device in devices) ...[
          _DeviceCard(
            device: device,
            isCurrentDevice:
                _currentDeviceId != null &&
                device.id.trim() == _currentDeviceId,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildRemoteLogoutAction() {
    final activeDevices = _devicesController.activeDevices;
    final currentDeviceId = _currentDeviceId?.trim() ?? '';

    final currentDeviceIsKnown =
        currentDeviceId.isNotEmpty &&
        activeDevices.any((device) => device.id.trim() == currentDeviceId);

    final otherActiveDeviceCount = currentDeviceIsKnown
        ? activeDevices
              .where((device) => device.id.trim() != currentDeviceId)
              .length
        : 0;

    if (!currentDeviceIsKnown) {
      return const _InlineInfoCard(
        icon: Icons.shield_outlined,
        title: 'Aktuelles Gerät noch nicht eindeutig erkannt',
        text:
            'Luma zeigt die gespeicherten Geräte an, führt aber keine Fernabmeldung '
            'aus, solange dieses Gerät nicht sicher zugeordnet werden kann.',
      );
    }

    if (otherActiveDeviceCount <= 0) {
      return const _InlineInfoCard(
        icon: Icons.verified_user_outlined,
        title: 'Keine weiteren aktiven Sitzungen',
        text: 'Neben diesem Gerät ist derzeit keine weitere aktive Luma-Sitzung gespeichert.',
      );
    }

    return _RemoteLogoutCard(
      otherActiveDeviceCount: otherActiveDeviceCount,
      isBusy: _isEndingOtherSessions,
      onPressed: _isEndingOtherSessions ? null : _startRemoteLogout,
    );
  }

  Future<void> _startRemoteLogout() async {
    if (_isEndingOtherSessions) return;

    final currentDeviceId = _currentDeviceId?.trim() ?? '';
    if (currentDeviceId.isEmpty) {
      _showMessage(
        'Dieses Gerät konnte nicht eindeutig erkannt werden.',
        isError: true,
      );
      return;
    }

    final confirmed = await _showRemoteLogoutConfirmation();
    if (!confirmed || !mounted) return;

    String? password;

    switch (_remoteLogoutService.reauthenticationMethod) {
      case SecurityReauthenticationMethod.password:
        password = await _requestCurrentPassword();
        if (password == null || !mounted) return;
        break;

      case SecurityReauthenticationMethod.google:
        break;

      case SecurityReauthenticationMethod.unsupported:
        _showMessage(
          'Für diese Anmeldemethode ist das sichere Abmelden anderer Sitzungen '
          'derzeit noch nicht verfügbar.',
          isError: true,
        );
        return;
    }

    setState(() {
      _isEndingOtherSessions = true;
    });

    try {
      final result = await _remoteLogoutService.revokeOtherSessions(
        currentPassword: password,
      );

      if (!mounted) return;

      await _devicesController.load(
        userId: _auth.currentUser?.uid.trim() ?? '',
      );

      if (!mounted) return;

      final count = result.deactivatedDeviceCount;
      _showMessage(
        count == 1
            ? '1 andere Sitzung wurde abgemeldet.'
            : '$count andere Sitzungen wurden abgemeldet.',
      );
    } on SecurityRemoteLogoutException catch (error) {
      if (!mounted) return;
      _showMessage(error.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Die anderen Sitzungen konnten gerade nicht sicher abgemeldet werden.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isEndingOtherSessions = false;
        });
      }
    }
  }

  Future<bool> _showRemoteLogoutConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Andere Sitzungen abmelden?'),
          content: const Text(
            'Alle anderen aktiven Luma-Sitzungen werden beendet. '
            'Dieses Gerät soll angemeldet bleiben. Zur Sicherheit musst du '
            'deine Anmeldung noch einmal bestätigen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Weiter'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<String?> _requestCurrentPassword() async {
    final controller = TextEditingController();
    var obscureText = true;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final canSubmit = controller.text.isNotEmpty;

              return AlertDialog(
                title: const Text('Anmeldung bestätigen'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscureText,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) => setDialogState(() {}),
                  onSubmitted: canSubmit
                      ? (_) => Navigator.of(dialogContext).pop(controller.text)
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Aktuelles Passwort',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setDialogState(() {
                          obscureText = !obscureText;
                        });
                      },
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: canSubmit
                        ? () => Navigator.of(dialogContext).pop(controller.text)
                        : null,
                    child: const Text('Bestätigen'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : null,
        ),
      );
  }

  static List<String> _providerLabels(User user) {
    final values = <String>[];

    for (final provider in user.providerData) {
      final providerId = provider.providerId.trim().toLowerCase();
      final label = switch (providerId) {
        'password' => 'E-Mail & Passwort',
        'google.com' => 'Google',
        'phone' => 'Telefon',
        'apple.com' => 'Apple',
        'facebook.com' => 'Facebook',
        _ => providerId.isEmpty ? null : providerId,
      };

      if (label != null && !values.contains(label)) {
        values.add(label);
      }
    }

    return values;
  }

  static String _emailLabel(User user) {
    final email = user.email?.trim();

    if (email == null || email.isEmpty) {
      return 'Keine E-Mail hinterlegt';
    }

    return user.emailVerified
        ? '$email · bestätigt'
        : '$email · nicht bestätigt';
  }

  static String _twoFactorLabel(TwoFactorMethod method) {
    return switch (method) {
      TwoFactorMethod.sms => 'SMS',
      TwoFactorMethod.authenticator => 'Authenticator-App',
      TwoFactorMethod.none => 'Nicht eingerichtet',
    };
  }

  static String _countLabel(
    int count, {
    required String singular,
    required String plural,
  }) {
    final safeCount = count < 0 ? 0 : count;
    return '$safeCount ${safeCount == 1 ? singular : plural}';
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Noch keine Angabe';
    }

    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute Uhr';
  }
}

class _SecurityEventCard extends StatelessWidget {
  const _SecurityEventCard({required this.event});

  final SecurityEventModel event;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    final createdAt = event.createdAt;
    final deviceText = <String>[
      if (event.deviceName?.trim().isNotEmpty == true) event.deviceName!.trim(),
      if (event.platformLabel?.trim().isNotEmpty == true)
        event.platformLabel!.trim(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _severityColor(event.severity)
                  .withValues(alpha: isDark ? 0.12 : 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _eventIcon(event.type),
              color: _severityColor(event.severity),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14.8,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (event.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, left: 8),
                        decoration: const BoxDecoration(
                          color: LumaTheme.lumaOrange,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  event.description,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.3,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (deviceText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.devices_other_rounded,
                        size: 14,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          deviceText,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DeviceBadge(text: _severityLabel(event.severity)),
                    if (createdAt != null)
                      Text(
                        _SecuritySettingsScreenState._formatDateTime(createdAt),
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _severityColor(SecurityEventSeverity severity) {
    return switch (severity) {
      SecurityEventSeverity.low => const Color(0xFF4F7D61),
      SecurityEventSeverity.medium => LumaTheme.lumaOrange,
      SecurityEventSeverity.high => const Color(0xFFC45A3C),
      SecurityEventSeverity.critical => const Color(0xFFB33A3A),
      SecurityEventSeverity.unknown => const Color(0xFF756D65),
    };
  }

  static String _severityLabel(SecurityEventSeverity severity) {
    return switch (severity) {
      SecurityEventSeverity.low => 'Niedrig',
      SecurityEventSeverity.medium => 'Hinweis',
      SecurityEventSeverity.high => 'Wichtig',
      SecurityEventSeverity.critical => 'Kritisch',
      SecurityEventSeverity.unknown => 'Sicherheit',
    };
  }

  static IconData _eventIcon(String type) {
    return switch (type.trim().toLowerCase()) {
      'successful_login' => Icons.login_rounded,
      'device_registered' => Icons.add_to_home_screen_rounded,
      'device_trusted' => Icons.verified_user_outlined,
      'device_deactivated' => Icons.phonelink_erase_rounded,
      'remote_logout' => Icons.logout_rounded,
      'phone_changed' || 'phone_verified' => Icons.phone_android_rounded,
      'two_factor_enabled' || 'two_factor_disabled' => Icons.security_rounded,
      'backup_codes_generated' ||
      'backup_codes_reset' => Icons.password_rounded,
      'password_reset_requested' || 'password_changed' => Icons.key_rounded,
      _ => Icons.shield_outlined,
    };
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.isCurrentDevice});

  final SecurityDeviceModel device;
  final bool isCurrentDevice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    final activity = device.lastSeenAt ?? device.lastLoginAt;
    final stateLabel = device.active ? 'Aktiv' : 'Nicht aktiv';
    final trustLabel = device.trusted
        ? 'Vertrauenswürdig'
        : 'Nicht als vertrauenswürdig markiert';

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.10 : 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _deviceIcon(device.platformType),
              color: LumaTheme.lumaOrange,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14.8,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  device.platformLabel,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isCurrentDevice)
                      const _DeviceBadge(text: 'Dieses Gerät'),
                    _DeviceBadge(text: stateLabel),
                    _DeviceBadge(text: trustLabel),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  activity == null
                      ? 'Keine letzte Aktivität gespeichert'
                      : 'Zuletzt aktiv: ${_SecuritySettingsScreenState._formatDateTime(activity)}',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _deviceIcon(String platformType) {
    return switch (platformType.trim().toLowerCase()) {
      'android' || 'ios' => Icons.smartphone_rounded,
      'windows' || 'macos' || 'linux' => Icons.computer_rounded,
      'web' => Icons.language_rounded,
      _ => Icons.devices_other_rounded,
    };
  }
}

class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF625A52);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LumaTheme.lumaOrange.withValues(alpha: isDark ? 0.08 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LumaTheme.lumaOrange, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.2,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          ),
        );
      },
    );
  }
}

class _SecurityIntro extends StatelessWidget {
  const _SecurityIntro({
    required this.emailVerified,
    required this.twoFactorEnabled,
    required this.loginAlertsEnabled,
  });

  final bool emailVerified;
  final bool twoFactorEnabled;
  final bool loginAlertsEnabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    final protectedCount = <bool>[
      emailVerified,
      twoFactorEnabled,
      loginAlertsEnabled,
    ].where((value) => value).length;

    final title = protectedCount == 3
        ? 'Dein Kontoschutz ist gut aufgestellt.'
        : 'Behalte deinen Kontoschutz im Blick.';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.13 : 0.15,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: LumaTheme.lumaOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17.2,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hier siehst du Sicherheitsdaten und die bereits '
                  'gespeicherten Geräte deines Luma-Kontos.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.11 : 0.14,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: LumaTheme.lumaOrange, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    letterSpacing: -0.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.6,
                    fontWeight: FontWeight.w500,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: LumaTheme.lumaOrange.withValues(
                alpha: isDark ? 0.10 : 0.12,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: LumaTheme.lumaOrange, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEDE5DD);

    return Divider(height: 1, thickness: 1, indent: 64, color: color);
  }
}

class _RemoteLogoutCard extends StatelessWidget {
  const _RemoteLogoutCard({
    required this.otherActiveDeviceCount,
    required this.isBusy,
    required this.onPressed,
  });

  final int otherActiveDeviceCount;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    final sessionLabel = otherActiveDeviceCount == 1
        ? '1 weitere aktive Sitzung'
        : '$otherActiveDeviceCount weitere aktive Sitzungen';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: LumaTheme.lumaOrange.withValues(
                    alpha: isDark ? 0.10 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: LumaTheme.lumaOrange,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Andere Sitzungen abmelden',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sessionLabel. Dieses Gerät bleibt als aktuelle '
                      'Sitzung vorgesehen.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12.3,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: isBusy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(
                isBusy ? 'Sitzungen werden beendet …' : 'Andere abmelden',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? LumaTheme.darkSurfaceSoft
        : const Color(0xFFFFFCF8);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE8DCCE);
    final textPrimary = isDark
        ? LumaTheme.darkTextPrimary
        : const Color(0xFF102033);
    final textSecondary = isDark
        ? LumaTheme.darkTextSecondary
        : const Color(0xFF756D65);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: LumaTheme.lumaOrange,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              'Sicherheitsdaten nicht verfügbar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Erneut laden'),
            ),
          ],
        ),
      ),
    );
  }
}
