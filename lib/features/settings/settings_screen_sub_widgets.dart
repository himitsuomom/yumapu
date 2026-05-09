part of 'settings_screen.dart';

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ── 通知設定セクション ────────────────────────────────────────────────────────

class _NotificationSettingsSection extends ConsumerStatefulWidget {
  const _NotificationSettingsSection();

  @override
  ConsumerState<_NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<_NotificationSettingsSection>
    with WidgetsBindingObserver {
  bool? _isEnabled;
  bool _isDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final svc = NotificationService.instance;
    final enabled = await svc.isNotificationEnabled();
    final denied = await svc.isNotificationDenied();
    if (!mounted) return;
    setState(() {
      _isEnabled = enabled;
      _isDenied = denied;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_isDenied) {
      await _openAppSettings();
      return;
    }
    final svc = NotificationService.instance;
    if (value) {
      await svc.requestPermissionLazily();
    } else {
      await _openAppSettings();
      return;
    }
    await _loadStatus();
  }

  Future<void> _openAppSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定アプリを開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEnabled == null) {
      return const ListTile(
        leading: Icon(Icons.notifications_outlined),
        title: Text('プッシュ通知'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_isDenied) {
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_off_outlined,
                color: Color(0xFF9E9E9E)),
            title: const Text('プッシュ通知'),
            subtitle: const Text('通知が拒否されています'),
            trailing: Switch(
              value: false,
              onChanged: (_) => _openAppSettings(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF757575)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'アプリの設定から通知を許可できます',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(140),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openAppSettings,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('設定を開く',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SwitchListTile(
      secondary: Icon(
        _isEnabled!
            ? Icons.notifications_active_outlined
            : Icons.notifications_outlined,
      ),
      title: const Text('プッシュ通知'),
      subtitle: Text(
        _isEnabled! ? 'チェックイン・バッジ・フォロー通知が届きます' : 'オフになっています',
      ),
      value: _isEnabled!,
      onChanged: _toggle,
    );
  }
}

// ── テーマ選択ウィジェット ─────────────────────────────────────────────────────

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.brightness_medium_outlined, color: Color(0xFF757575)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'テーマ',
              style: TextStyle(fontSize: 16),
            ),
          ),
          SegmentedButton<ThemeMode>(
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('自動', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.brightness_auto, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('ライト', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.light_mode, size: 16),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('ダーク', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.dark_mode, size: 16),
              ),
            ],
            selected: {currentMode},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(selected.first);
              }
            },
          ),
        ],
      ),
    );
  }
}
