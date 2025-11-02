import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BitcoinService _bitcoinService = BitcoinService();
  
  AppSettings _settings = AppSettings();
  bool _isLoading = true;
  bool _isSaving = false;
  
  late bool _notificationsEnabled;
  late double _buyThreshold;
  late double _sellThreshold;
  late int _shortMaPeriod;
  late int _longMaPeriod;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      // Load from local storage first
      final prefs = await SharedPreferences.getInstance();
      final notifEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      // Try to load from backend
      final settings = await _bitcoinService.getSettings();
      
      if (mounted) {
        setState(() {
          _settings = settings.copyWith(notificationsEnabled: notifEnabled);
          _initializeFields();
          _isLoading = false;
        });
      }
    } catch (e) {
      // Use default settings if backend fails
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

      // Save to backend
      await _bitcoinService.updateSettings(newSettings);
      
      // Save notification preference locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      
      if (mounted) {
        setState(() {
          _settings = newSettings;
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
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
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
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
      padding: const EdgeInsets.all(16),
      children: [
        _buildNotificationsSection(),
        const SizedBox(height: 24),
        _buildAlgorithmSection(),
        const SizedBox(height: 24),
        _buildActionsSection(),
        const SizedBox(height: 24),
        _buildInfoSection(),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive push notifications for buy/sell signals'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Algorithm Settings',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust sensitivity of buy/sell signal detection',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSliderSetting(
              label: 'Buy Threshold',
              value: _buyThreshold,
              min: 0.001,
              max: 0.02,
              divisions: 19,
              onChanged: (value) => setState(() => _buyThreshold = value),
              valueLabel: '${(_buyThreshold * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              label: 'Sell Threshold',
              value: _sellThreshold,
              min: 0.001,
              max: 0.02,
              divisions: 19,
              onChanged: (value) => setState(() => _sellThreshold = value),
              valueLabel: '${(_sellThreshold * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              label: 'Short MA Period',
              value: _shortMaPeriod.toDouble(),
              min: 3,
              max: 15,
              divisions: 12,
              onChanged: (value) => setState(() => _shortMaPeriod = value.toInt()),
              valueLabel: '$_shortMaPeriod minutes',
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              label: 'Long MA Period',
              value: _longMaPeriod.toDouble(),
              min: 15,
              max: 30,
              divisions: 15,
              onChanged: (value) => setState(() => _longMaPeriod = value.toInt()),
              valueLabel: '$_longMaPeriod minutes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderSetting({
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset to Defaults'),
                    content: const Text(
                      'Are you sure you want to reset all settings to default values?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetToDefaults();
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Defaults'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardDark,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Version', '1.0.0'),
            const SizedBox(height: 8),
            _buildInfoRow('Algorithm', 'Moving Average Crossover'),
            const SizedBox(height: 8),
            _buildInfoRow('Data Source', 'Binance API'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
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
