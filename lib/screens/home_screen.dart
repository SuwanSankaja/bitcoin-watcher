import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final BitcoinService _bitcoinService = BitcoinService();

  BtcPrice? _currentPrice;
  Signal? _currentSignal;
  List<BtcPrice> _priceHistory = [];

  bool _isLoading = true;
  String? _error;

  // Time interval for chart
  String _selectedInterval = '1h';
  final Map<String, double> _intervalHours = {
    '5m': 5 / 60,
    '15m': 15 / 60,
    '1h': 1,
    '4h': 4,
    '24h': 24,
  };
  final Map<String, String> _intervalLabels = {
    '5m': '5 Min Trend',
    '15m': '15 Min Trend',
    '1h': '1 Hour Trend',
    '4h': '4 Hour Trend',
    '24h': '24 Hour Trend',
  };

  late AnimationController _pulseController;
  final ScrollController _chartScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadData();
    Future.delayed(const Duration(seconds: 30), _autoRefresh);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chartScrollController.dispose();
    super.dispose();
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
      final hours = _intervalHours[_selectedInterval] ?? 1;
      final history = await _bitcoinService.getPriceHistory(
          hours: hours.ceil() == 0 ? 1 : hours.ceil());

      if (mounted) {
        setState(() {
          _currentPrice = priceData['price'];
          _currentSignal = priceData['signal'];
          _priceHistory = history;
          _isLoading = false;
          _error = null;
        });
        _scrollChartToEnd();
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

  Future<void> _loadChartData() async {
    try {
      final hours = _intervalHours[_selectedInterval] ?? 1;
      final history = await _bitcoinService.getPriceHistory(
          hours: hours.ceil() == 0 ? 1 : hours.ceil());
      if (mounted) {
        setState(() {
          _priceHistory = history;
        });
        _scrollChartToEnd();
      }
    } catch (_) {}
  }

  void _scrollChartToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.animateTo(
          _chartScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppDecorations.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/images/bitcoin-watcher-logo.png',
                height: 22,
                width: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Bitcoin Watcher'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
          const SizedBox(width: 4),
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
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      decoration: AppDecorations.accentGlowCard,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.currency_bitcoin_rounded,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Current BTC Price',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppDecorations.primaryGradient.createShader(bounds),
            child: Text(
              _currentPrice != null
                  ? Formatters.formatPrice(_currentPrice!.price)
                  : '--',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentPrice != null
                  ? '⏱ Updated ${Formatters.formatDateTime(_currentPrice!.timestamp)}'
                  : '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard() {
    if (_currentSignal == null) return const SizedBox.shrink();

    final signal = _currentSignal!;
    final signalColor = _getSignalColor(signal.type);
    final signalIcon = _getSignalIcon(signal.type);

    return Container(
      decoration: AppDecorations.signalCard(signalColor),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(signalIcon, color: signalColor, size: 24),
              const SizedBox(width: 10),
              Text(
                'Current Signal',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: signalColor.withValues(
                          alpha: 0.15 + _pulseController.value * 0.15),
                      blurRadius: 16 + _pulseController.value * 8,
                      spreadRadius: _pulseController.value * 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: SignalBadge(signalType: signal.type, size: 22),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildSignalMetric(
                'Confidence',
                signal.confidence,
                signalColor,
              )),
              Container(
                width: 1,
                height: 44,
                color: AppColors.cardBorder,
              ),
              Expanded(
                  child: _buildSignalInfo(
                'Signal Price',
                Formatters.formatPrice(signal.price),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalMetric(String label, double confidence, Color color) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Column(
            children: [
              Text(
                Formatters.formatPercentage(confidence),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: confidence / 100,
                  backgroundColor: AppColors.cardBorder,
                  color: color,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignalInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  Widget _buildChartCard() {
    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _intervalLabels[_selectedInterval] ?? '1 Hour Trend',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _buildIntervalSelector(),
          const SizedBox(height: 18),
          _priceHistory.isEmpty
              ? SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'No data available',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              : _buildScrollableChart(),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    final intervals = ['5m', '15m', '1h', '4h', '24h'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: intervals.map((interval) {
          final isSelected = _selectedInterval == interval;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedInterval != interval) {
                  setState(() => _selectedInterval = interval);
                  _loadChartData();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Text(
                  interval,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textTertiary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Nice intervals in minutes for readable time labels
  static const List<int> _niceIntervals = [
    1,
    2,
    5,
    10,
    15,
    30,
    60,
    120,
    180,
    240,
    360,
    720,
    1440
  ];

  /// Calculate the best label interval based on total data time span
  int _computeNiceLabelIntervalMinutes() {
    if (_priceHistory.length < 2) return 5;
    final firstTime = _priceHistory.first.timestamp;
    final lastTime = _priceHistory.last.timestamp;
    final totalMinutes = lastTime.difference(firstTime).inMinutes.abs();
    if (totalMinutes == 0) return 1;
    // Aim for ~6-8 labels
    final rawInterval = totalMinutes / 7.0;
    for (final nice in _niceIntervals) {
      if (nice >= rawInterval) return nice;
    }
    return _niceIntervals.last;
  }

  /// Check if data point at [index] crosses a time bucket boundary
  bool _isTimeBoundary(int index, int intervalMinutes) {
    if (index <= 0 || index >= _priceHistory.length - 1) return false;
    final time = _priceHistory[index].timestamp;
    final prevTime = _priceHistory[index - 1].timestamp;
    // Use epoch-based minutes so day crossings work correctly
    final currentBucket =
        time.millisecondsSinceEpoch ~/ (60000 * intervalMinutes);
    final prevBucket =
        prevTime.millisecondsSinceEpoch ~/ (60000 * intervalMinutes);
    return currentBucket != prevBucket;
  }

  /// Format time label: "HH:mm" or "MM/DD" when date changes
  String _formatChartTime(int index, Set<int> labelIndices) {
    final time = _priceHistory[index].timestamp;
    final hourMin =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    // Check if date changed from previous shown label
    if (index > 0) {
      DateTime? prevShownTime;
      for (int i = index - 1; i >= 0; i--) {
        if (labelIndices.contains(i) || i == 0) {
          prevShownTime = _priceHistory[i].timestamp;
          break;
        }
      }
      prevShownTime ??= _priceHistory[0].timestamp;
      if (time.day != prevShownTime.day) {
        return '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
      }
    }
    return hourMin;
  }

  /// Pre-compute which data indices should get time labels
  List<int> _computeLabelIndices() {
    final intervalMin = _computeNiceLabelIntervalMinutes();
    final indices = <int>[];
    for (int i = 1; i < _priceHistory.length - 1; i++) {
      if (_isTimeBoundary(i, intervalMin)) {
        indices.add(i);
      }
    }
    return indices;
  }

  Widget _buildScrollableChart() {
    final dataLen = _priceHistory.length;

    // Calculate dimensions
    final availableWidth = MediaQuery.of(context).size.width - 120;
    const pixelsPerPoint = 5.0;
    final desiredWidth = dataLen * pixelsPerPoint;
    final chartWidth =
        desiredWidth > availableWidth ? desiredWidth : availableWidth;

    // Y-axis calculations
    final minPrice =
        _priceHistory.map((p) => p.price).reduce((a, b) => a < b ? a : b);
    final maxPrice =
        _priceHistory.map((p) => p.price).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;
    final yPadding = priceRange > 0 ? priceRange * 0.1 : maxPrice * 0.01;
    final chartMinY = minPrice - yPadding;
    final chartMaxY = maxPrice + yPadding;
    final displayRange = chartMaxY - chartMinY;
    final horizontalInterval = displayRange / 4;
    final yMin = (chartMinY / horizontalInterval).floor() * horizontalInterval;
    final yMax = (chartMaxY / horizontalInterval).ceil() * horizontalInterval;

    // Color
    final isPositive = dataLen > 1
        ? _priceHistory.last.price >= _priceHistory.first.price
        : true;
    final lineColor =
        isPositive ? AppColors.chartPositive : AppColors.chartNegative;

    // Pre-compute which indices get labels
    final labelIndices = _computeLabelIndices().toSet();

    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Y-axis
          SizedBox(
            width: 56,
            height: 220,
            child: _buildYAxis(yMin, yMax, horizontalInterval),
          ),
          const SizedBox(width: 4),
          // Scrollable chart
          Expanded(
            child: SingleChildScrollView(
              controller: _chartScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: chartWidth,
                height: 260,
                child: _buildChartContent(
                  yMin: yMin,
                  yMax: yMax,
                  horizontalInterval: horizontalInterval,
                  lineColor: lineColor,
                  labelIndices: labelIndices,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYAxis(double yMin, double yMax, double horizontalInterval) {
    // Generate y-axis labels from bottom to top
    final labels = <double>[];
    for (double v = yMin + horizontalInterval;
        v < yMax;
        v += horizontalInterval) {
      labels.add(v);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = constraints.maxHeight;
          final range = yMax - yMin;

          return Stack(
            children: labels.map((v) {
              final fraction = (v - yMin) / range;
              // Bottom = yMin, top = yMax
              final top = chartHeight * (1 - fraction);
              final priceK = v / 1000;
              return Positioned(
                top: top - 7,
                left: 0,
                right: 4,
                child: Text(
                  '\$${priceK.toStringAsFixed(1)}K',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                  textAlign: TextAlign.right,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildChartContent({
    required double yMin,
    required double yMax,
    required double horizontalInterval,
    required Color lineColor,
    required Set<int> labelIndices,
  }) {
    final spots = _priceHistory
        .asMap()
        .entries
        .map((entry) => FlSpot(
              entry.key.toDouble(),
              entry.value.price,
            ))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: horizontalInterval,
          verticalInterval: 1,
          checkToShowVerticalLine: (value) {
            return labelIndices.contains(value.toInt());
          },
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.chartGrid.withValues(alpha: 0.4),
              strokeWidth: 0.5,
              dashArray: [4, 4],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: AppColors.chartGrid.withValues(alpha: 0.15),
              strokeWidth: 0.5,
              dashArray: [4, 4],
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
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                // Only show labels at time-boundary indices
                if (!labelIndices.contains(index)) {
                  return const SizedBox();
                }
                final label = _formatChartTime(index, labelIndices);
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: spots.length - 1.0,
        minY: yMin,
        maxY: yMax,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _priceHistory.length) {
                  final priceData = _priceHistory[index];
                  final time = priceData.timestamp;
                  final timeStr =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  final dateStr =
                      '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
                  return LineTooltipItem(
                    '${Formatters.formatPrice(priceData.price)}\n$dateStr  $timeStr',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                // Vertical crosshair line
                FlLine(
                  color: AppColors.textTertiary.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [3, 3],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: lineColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withValues(alpha: 0.2),
                  lineColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Card ──────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Signal Guide',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.trending_up_rounded, 'BUY',
              'Strong upward momentum', AppColors.buy),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          _buildInfoRow(Icons.trending_down_rounded, 'SELL',
              'Strong downward momentum', AppColors.sell),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
              height: 1,
              color: AppColors.cardBorder.withValues(alpha: 0.5),
            ),
          ),
          _buildInfoRow(Icons.trending_flat_rounded, 'HOLD',
              'No clear trend, wait', AppColors.hold),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String description, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                    ),
              ),
              const SizedBox(height: 2),
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
        return Icons.trending_up_rounded;
      case SignalType.sell:
        return Icons.trending_down_rounded;
      case SignalType.hold:
        return Icons.trending_flat_rounded;
    }
  }
}
