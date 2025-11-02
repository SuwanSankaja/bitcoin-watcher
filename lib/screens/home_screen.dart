import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BitcoinService _bitcoinService = BitcoinService();
  
  BtcPrice? _currentPrice;
  Signal? _currentSignal;
  List<BtcPrice> _priceHistory = [];
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Refresh data every 30 seconds
    Future.delayed(const Duration(seconds: 30), _autoRefresh);
  }

  void _autoRefresh() {
    if (mounted) {
      _loadData();
      Future.delayed(const Duration(seconds: 30), _autoRefresh);
    }
  }

  Future<void> _loadData() async {
    try {
      final priceData = await _bitcoinService.getCurrentPrice();
      final history = await _bitcoinService.getPriceHistory(hours: 24);
      
      if (mounted) {
        setState(() {
          _currentPrice = priceData['price'];
          _currentSignal = priceData['signal'];
          _priceHistory = history;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitcoin Watcher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _currentPrice == null) {
      return const LoadingIndicator(message: 'Loading Bitcoin data...');
    }

    if (_error != null && _currentPrice == null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadData();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPriceCard(),
              const SizedBox(height: 16),
              _buildSignalCard(),
              const SizedBox(height: 16),
              _buildChartCard(),
              const SizedBox(height: 16),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Current BTC Price',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _currentPrice != null
                  ? Formatters.formatPrice(_currentPrice!.price)
                  : '--',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentPrice != null
                  ? 'Updated ${Formatters.formatDateTime(_currentPrice!.timestamp)}'
                  : '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalCard() {
    if (_currentSignal == null) return const SizedBox.shrink();

    final signal = _currentSignal!;
    final signalColor = _getSignalColor(signal.type);
    final signalIcon = _getSignalIcon(signal.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(signalIcon, color: signalColor, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Current Signal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SignalBadge(
              signalType: signal.type,
              size: 24,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSignalInfo(
                  'Confidence',
                  Formatters.formatPercentage(signal.confidence),
                ),
                _buildSignalInfo(
                  'Signal Price',
                  Formatters.formatPrice(signal.price),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24 Hour Trend',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _priceHistory.isEmpty
                  ? const Center(child: Text('No data available'))
                  : _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final spots = _priceHistory
        .asMap()
        .entries
        .map((entry) => FlSpot(
              entry.key.toDouble(),
              entry.value.price,
            ))
        .toList();

    final minPrice = _priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxPrice = _priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxPrice - minPrice) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.chartGrid,
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: spots.length / 4,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= _priceHistory.length) return const Text('');
                final time = _priceHistory[value.toInt()].timestamp;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    Formatters.formatTime(time),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text(
                  Formatters.formatCompact(value),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.length - 1.0,
        minY: minPrice * 0.999,
        maxY: maxPrice * 1.001,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.chartLine,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartLine.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Signals',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.trending_up, 'BUY', 'Strong upward momentum detected', AppColors.buy),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.trending_down, 'SELL', 'Strong downward momentum detected', AppColors.sell),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.trending_flat, 'HOLD', 'No clear trend, wait for better opportunity', AppColors.hold),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String description, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getSignalColor(SignalType type) {
    switch (type) {
      case SignalType.buy:
        return AppColors.buy;
      case SignalType.sell:
        return AppColors.sell;
      case SignalType.hold:
        return AppColors.hold;
    }
  }

  IconData _getSignalIcon(SignalType type) {
    switch (type) {
      case SignalType.buy:
        return Icons.trending_up;
      case SignalType.sell:
        return Icons.trending_down;
      case SignalType.hold:
        return Icons.trending_flat;
    }
  }
}
