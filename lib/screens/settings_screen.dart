import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BitcoinService _bitcoinService = BitcoinService();

  AppSettings _settings = AppSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  bool _notificationsEnabled = true;
  double _buyThreshold = 0.005;
  double _sellThreshold = 0.005;
  int _shortMaPeriod = 7;
  int _longMaPeriod = 21;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifEnabled = prefs.getBool('notifications_enabled') ?? true;
      final settings = await _bitcoinService.getSettings();

      if (mounted) {
        setState(() {
          _settings = settings.copyWith(notificationsEnabled: notifEnabled);
          _initializeFields();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final notifEnabled = prefs.getBool('notifications_enabled') ?? true;

        setState(() {
          _settings = AppSettings(notificationsEnabled: notifEnabled);
          _initializeFields();
          _isLoading = false;
        });
      }
    }
  }

  void _initializeFields() {
    _notificationsEnabled = _settings.notificationsEnabled;
    _buyThreshold = _settings.buyThreshold;
    _sellThreshold = _settings.sellThreshold;
    _shortMaPeriod = _settings.shortMaPeriod;
    _longMaPeriod = _settings.longMaPeriod;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final newSettings = AppSettings(
        notificationsEnabled: _notificationsEnabled,
        buyThreshold: _buyThreshold,
        sellThreshold: _sellThreshold,
        shortMaPeriod: _shortMaPeriod,
        longMaPeriod: _longMaPeriod,
      );

      await _bitcoinService.updateSettings(newSettings);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);

      if (mounted) {
        setState(() {
          _settings = newSettings;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _resetToDefaults() {
    setState(() {
      _notificationsEnabled = true;
      _buyThreshold = 0.005;
      _sellThreshold = 0.005;
      _shortMaPeriod = 7;
      _longMaPeriod = 21;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_hasChanges())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading settings...')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        _buildNotificationsSection(),
        const SizedBox(height: 24),
        _buildAlgorithmSection(),
        const SizedBox(height: 24),
        _buildActionsSection(),
        const SizedBox(height: 24),
        _buildInfoSection(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.notifications_outlined, 'Notifications'),
        Container(
          decoration: AppDecorations.glassmorphicCard,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(
              'Push Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                  ),
            ),
            subtitle: Text(
              'Receive alerts for buy/sell signals',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlgorithmSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.tune_rounded, 'Algorithm'),
        Container(
          decoration: AppDecorations.glassmorphicCard,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signal Sensitivity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust buy/sell signal detection thresholds',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              _buildSliderSetting(
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.buy,
                label: 'Buy Threshold',
                value: _buyThreshold,
                min: 0.001,
                max: 0.02,
                divisions: 19,
                onChanged: (value) => setState(() => _buyThreshold = value),
                valueLabel: '${(_buyThreshold * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 20),
              _buildSliderSetting(
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.sell,
                label: 'Sell Threshold',
                value: _sellThreshold,
                min: 0.001,
                max: 0.02,
                divisions: 19,
                onChanged: (value) => setState(() => _sellThreshold = value),
                valueLabel: '${(_sellThreshold * 100).toStringAsFixed(1)}%',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(
                  color: AppColors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
              Text(
                'Moving Average Periods',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Configure short and long MA window sizes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              _buildSliderSetting(
                icon: Icons.speed_rounded,
                iconColor: AppColors.info,
                label: 'Short MA',
                value: _shortMaPeriod.toDouble(),
                min: 3,
                max: 15,
                divisions: 12,
                onChanged: (value) =>
                    setState(() => _shortMaPeriod = value.toInt()),
                valueLabel: '$_shortMaPeriod min',
              ),
              const SizedBox(height: 20),
              _buildSliderSetting(
                icon: Icons.timeline_rounded,
                iconColor: AppColors.warning,
                label: 'Long MA',
                value: _longMaPeriod.toDouble(),
                min: 15,
                max: 30,
                divisions: 15,
                onChanged: (value) =>
                    setState(() => _longMaPeriod = value.toInt()),
                valueLabel: '$_longMaPeriod min',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.cardBorder,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.settings_backup_restore_rounded, 'Actions'),
        Container(
          decoration: AppDecorations.glassmorphicCard,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restore_rounded,
                  color: AppColors.warning, size: 20),
            ),
            title: Text(
              'Reset to Defaults',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                  ),
            ),
            subtitle: Text(
              'Restore all settings to original values',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  title: const Text('Reset to Defaults'),
                  content: const Text(
                    'Are you sure you want to reset all settings to default values?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetToDefaults();
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.info_outline_rounded, 'About'),
        Container(
          decoration: AppDecorations.glassmorphicCard,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.tag_rounded,
                'Version',
                '1.0.0',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Divider(color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              _buildInfoRow(
                Icons.analytics_outlined,
                'Algorithm',
                'MA Crossover',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Divider(color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              _buildInfoRow(
                Icons.cloud_outlined,
                'Data Source',
                'Binance API',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  bool _hasChanges() {
    return _notificationsEnabled != _settings.notificationsEnabled ||
        _buyThreshold != _settings.buyThreshold ||
        _sellThreshold != _settings.sellThreshold ||
        _shortMaPeriod != _settings.shortMaPeriod ||
        _longMaPeriod != _settings.longMaPeriod;
  }
}
