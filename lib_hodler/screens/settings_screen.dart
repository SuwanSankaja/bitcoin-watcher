import 'package:flutter/material.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _bitcoinService.getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _bitcoinService.updateSettings(_settings);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Settings saved'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _resetDefaults() {
    setState(() => _settings = AppSettings());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reset to defaults (save to apply)'),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _resetDefaults,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading)
      return const LoadingIndicator(message: 'Loading settings...');
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadSettings();
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            children: [
              _buildSwitch(
                label: 'Push Notifications',
                subtitle: 'Get notified when buy zones are detected',
                value: _settings.notificationsEnabled,
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(notificationsEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── DCA Buy Settings ────────────────────────────────────────────
          _buildSection(
            icon: Icons.savings_rounded,
            title: 'DCA Buy Settings',
            accentColor: AppColors.buy,
            children: [
              _buildSlider(
                label: 'Min Accumulation Score',
                subtitle: 'Only buy when score ≥ this value',
                value: _settings.minScoreThreshold.toDouble(),
                min: 40,
                max: 90,
                divisions: 50,
                suffix: '/100',
                onChanged: (v) => setState(() => _settings =
                    _settings.copyWith(minScoreThreshold: v.round())),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'DCA Scale Factor',
                subtitle: 'Multiplier for high-score buys',
                value: _settings.dcaScaleFactor,
                min: 1.0,
                max: 3.0,
                divisions: 20,
                suffix: 'x',
                decimals: 1,
                onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(dcaScaleFactor: v)),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'Max Single Buy',
                subtitle: 'Cap per trade in USDT',
                value: _settings.maxSingleTradeUsdt,
                min: 10,
                max: 1000,
                divisions: 99,
                suffix: ' USDT',
                decimals: 0,
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(maxSingleTradeUsdt: v)),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'Base Buy Amount',
                subtitle: 'Minimum USDT per trade',
                value: _settings.tradeAmountUsdt,
                min: 5,
                max: 200,
                divisions: 39,
                suffix: ' USDT',
                decimals: 0,
                onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(tradeAmountUsdt: v)),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'Lookback Hours',
                subtitle: 'Price history window for dip calculation',
                value: _settings.lookbackHours.toDouble(),
                min: 1,
                max: 24,
                divisions: 23,
                suffix: 'h',
                decimals: 0,
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(lookbackHours: v.round())),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Algorithm Settings ─────────────────────────────────────────
          _buildSection(
            icon: Icons.tune_rounded,
            title: 'Algorithm Settings',
            children: [
              _buildSlider(
                label: 'MA Sensitivity',
                subtitle: 'Threshold for MA crossover signal',
                value: _settings.buyThreshold,
                min: 0.0001,
                max: 0.01,
                divisions: 99,
                suffix: '',
                decimals: 4,
                onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(buyThreshold: v)),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'Short MA Period',
                subtitle: 'Fast moving average period',
                value: _settings.shortMaPeriod.toDouble(),
                min: 3,
                max: 20,
                divisions: 17,
                suffix: '',
                decimals: 0,
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(shortMaPeriod: v.round())),
              ),
              _buildDivider(),
              _buildSlider(
                label: 'Long MA Period',
                subtitle: 'Slow moving average period',
                value: _settings.longMaPeriod.toDouble(),
                min: 10,
                max: 50,
                divisions: 40,
                suffix: '',
                decimals: 0,
                onChanged: (v) => setState(() =>
                    _settings = _settings.copyWith(longMaPeriod: v.round())),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Trading ────────────────────────────────────────────────────
          _buildSection(
            icon: Icons.swap_horiz_rounded,
            title: 'Trading',
            accentColor: _settings.tradingEnabled ? AppColors.buy : null,
            children: [
              _buildSwitch(
                label: 'Enable Auto-Trading',
                subtitle: 'Execute DCA buys when score exceeds threshold',
                value: _settings.tradingEnabled,
                onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(tradingEnabled: v)),
              ),
              if (_settings.tradingEnabled) ...[
                _buildDivider(),
                _buildModePicker(),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // ── Save Button ────────────────────────────────────────────────
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section builder ─────────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    int decimals = 2,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${value.toStringAsFixed(decimals)}$suffix',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildModePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trading Mode', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 2),
          Text('Choose testnet (paper trading) or production',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildModeChip('testnet', 'Testnet', Icons.science_rounded),
              const SizedBox(width: 10),
              _buildModeChip(
                  'production', 'Production', Icons.rocket_launch_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String mode, String label, IconData icon) {
    final isSelected = _settings.tradingMode == mode;
    final isProd = mode == 'production';
    final color = isProd ? AppColors.warning : AppColors.info;

    return Expanded(
      child: GestureDetector(
        onTap: () =>
            setState(() => _settings = _settings.copyWith(tradingMode: mode)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : AppColors.textTertiary, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? color : AppColors.textTertiary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 24, color: AppColors.cardBorder.withValues(alpha: 0.5));
}
