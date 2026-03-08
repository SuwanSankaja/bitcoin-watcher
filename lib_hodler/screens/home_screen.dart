import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
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
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;
  final ScrollController _chartScrollController = ScrollController();

  double _displayedScore = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );

    _loadData();
    Future.delayed(const Duration(seconds: 30), _autoRefresh);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scoreController.dispose();
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
        final newScore =
            (priceData['signal'] as Signal?)?.accumulationScore ?? 0;
        _animateScore(newScore);
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

  void _animateScore(double targetScore) {
    _scoreAnimation = Tween<double>(
      begin: _displayedScore,
      end: targetScore,
    ).animate(
        CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic));
    _scoreAnimation.addListener(() {
      if (mounted) setState(() => _displayedScore = _scoreAnimation.value);
    });
    _scoreController
      ..reset()
      ..forward();
  }

  Future<void> _loadChartData() async {
    try {
      final hours = _intervalHours[_selectedInterval] ?? 1;
      final history = await _bitcoinService.getPriceHistory(
          hours: hours.ceil() == 0 ? 1 : hours.ceil());
      if (mounted) {
        setState(() => _priceHistory = history);
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
            const Text('Bitcoin Hodler'),
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
              _buildAccumulationScoreCard(),
              const SizedBox(height: 16),
              _buildMarketSentimentRow(),
              const SizedBox(height: 16),
              _buildChartCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Price Card ──────────────────────────────────────────────────────────────
  Widget _buildPriceCard() {
    return Container(
      decoration: AppDecorations.accentGlowCard,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.currency_bitcoin_rounded,
                  color: AppColors.primary.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 6),
              Text('Current BTC Price',
                  style: Theme.of(context).textTheme.labelMedium),
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
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(color: Colors.white, fontSize: 38),
            ),
          ),
          const SizedBox(height: 10),
          if (_currentPrice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '⏱ Updated ${Formatters.formatDateTime(_currentPrice!.timestamp)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Accumulation Score Gauge ────────────────────────────────────────────────
  Widget _buildAccumulationScoreCard() {
    final score = _displayedScore;
    final signal = _currentSignal;
    final isBuyZone = signal?.buyZone ?? false;

    // Color shifts: red (0) → yellow (50) → green (80+)
    final Color gaugeColor;
    if (score >= 80) {
      gaugeColor = AppColors.buy;
    } else if (score >= 60) {
      gaugeColor = const Color(0xFF84CC16); // lime
    } else if (score >= 40) {
      gaugeColor = AppColors.hold;
    } else {
      gaugeColor = AppColors.error;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gaugeColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_rounded,
                  color: AppColors.textTertiary, size: 16),
              const SizedBox(width: 8),
              Text('Accumulation Score',
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 20),
          // Circular gauge
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _ScoreGaugePainter(
                score: score,
                color: gaugeColor,
                backgroundColor: AppColors.cardBorder,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: gaugeColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/100',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Buy zone badge with pulse animation
          if (isBuyZone)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gaugeColor.withValues(
                          alpha: 0.15 + _pulseController.value * 0.2),
                      blurRadius: 16 + _pulseController.value * 10,
                      spreadRadius: _pulseController.value * 2,
                    ),
                  ],
                ),
                child: child,
              ),
              child: SignalBadge(
                signalType: signal!.type.displayName,
                accumulationScore: signal.accumulationScore,
                size: 18,
              ),
            )
          else
            SignalBadge(
              signalType: _currentSignal?.type.displayName ?? 'HOLD',
              accumulationScore: _currentSignal?.accumulationScore,
              size: 18,
            ),
        ],
      ),
    );
  }

  // ── Market Sentiment Row ────────────────────────────────────────────────────
  Widget _buildMarketSentimentRow() {
    final signal = _currentSignal;
    return Row(
      children: [
        Expanded(
            child: _buildSentimentTile(
          icon: Icons.show_chart_rounded,
          label: 'RSI',
          value: signal?.rsi != null ? signal!.rsi!.toStringAsFixed(1) : '--',
          subLabel: _rsiLabel(signal?.rsi),
          color: _rsiColor(signal?.rsi),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _buildSentimentTile(
          icon: Icons.sentiment_neutral_rounded,
          label: 'Fear & Greed',
          value: signal?.fearGreedIndex?.toString() ?? '--',
          subLabel: signal?.fearGreedLabel ?? 'Unknown',
          color: _fearGreedColor(signal?.fearGreedIndex),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _buildSentimentTile(
          icon: Icons.arrow_downward_rounded,
          label: 'Dip from High',
          value: signal?.dipDepth != null
              ? '${signal!.dipDepth!.toStringAsFixed(2)}%'
              : '--',
          subLabel: _dipLabel(signal?.dipDepth),
          color: _dipColor(signal?.dipDepth),
        )),
      ],
    );
  }

  Widget _buildSentimentTile({
    required IconData icon,
    required String label,
    required String value,
    required String subLabel,
    required Color color,
  }) {
    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(subLabel,
              style:
                  Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _rsiLabel(double? rsi) {
    if (rsi == null) return '';
    if (rsi < 30) return 'Oversold ✅';
    if (rsi < 50) return 'Neutral';
    if (rsi < 70) return 'Neutral';
    return 'Overbought ⚠️';
  }

  Color _rsiColor(double? rsi) {
    if (rsi == null) return AppColors.textTertiary;
    if (rsi < 30) return AppColors.buy;
    if (rsi > 70) return AppColors.error;
    return AppColors.hold;
  }

  Color _fearGreedColor(int? fg) {
    if (fg == null) return AppColors.textTertiary;
    if (fg <= 25) return AppColors.buy;
    if (fg <= 50) return AppColors.hold;
    return AppColors.error;
  }

  String _dipLabel(double? dip) {
    if (dip == null) return '';
    if (dip >= 5) return 'Big Dip 🟢';
    if (dip >= 2) return 'Moderate';
    return 'Shallow';
  }

  Color _dipColor(double? dip) {
    if (dip == null) return AppColors.textTertiary;
    if (dip >= 5) return AppColors.buy;
    if (dip >= 2) return AppColors.hold;
    return AppColors.textSecondary;
  }

  // ── Chart ───────────────────────────────────────────────────────────────────
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
              ? const SizedBox(
                  height: 220, child: Center(child: Text('No data available')))
              : _buildScrollableChart(),
        ],
      ),
    );
  }

  Widget _buildIntervalSelector() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ['5m', '15m', '1h', '4h', '24h'].map((interval) {
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
                          color: AppColors.primary.withValues(alpha: 0.3))
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

  Widget _buildScrollableChart() {
    final dataLen = _priceHistory.length;
    final availableWidth = MediaQuery.of(context).size.width - 120;
    const pixelsPerPoint = 5.0;
    final desiredWidth = dataLen * pixelsPerPoint;
    final chartWidth =
        desiredWidth > availableWidth ? desiredWidth : availableWidth;

    final minPrice = _priceHistory.map((p) => p.price).reduce(math.min);
    final maxPrice = _priceHistory.map((p) => p.price).reduce(math.max);
    final priceRange = maxPrice - minPrice;
    final yPadding = priceRange > 0 ? priceRange * 0.1 : maxPrice * 0.01;
    final chartMinY = minPrice - yPadding;
    final chartMaxY = maxPrice + yPadding;
    final displayRange = chartMaxY - chartMinY;
    final horizontalInterval = displayRange / 4;
    final yMin = (chartMinY / horizontalInterval).floor() * horizontalInterval;
    final yMax = (chartMaxY / horizontalInterval).ceil() * horizontalInterval;

    final isPositive = dataLen > 1
        ? _priceHistory.last.price >= _priceHistory.first.price
        : true;
    final lineColor =
        isPositive ? AppColors.chartPositive : AppColors.chartNegative;

    final spots = _priceHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.price))
        .toList();

    return SizedBox(
      height: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed Y-axis
          SizedBox(
            width: 56,
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final labels = <double>[];
                  for (double v = yMin + horizontalInterval;
                      v < yMax;
                      v += horizontalInterval) {
                    labels.add(v);
                  }
                  return Stack(
                    children: labels.map((v) {
                      final fraction = (v - yMin) / (yMax - yMin);
                      final top = constraints.maxHeight * (1 - fraction);
                      return Positioned(
                        top: top - 7,
                        left: 0,
                        right: 4,
                        child: Text(
                          '\$${(v / 1000).toStringAsFixed(1)}K',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontSize: 10, color: AppColors.textTertiary),
                          textAlign: TextAlign.right,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _chartScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: chartWidth,
                height: 260,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: horizontalInterval,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.chartGrid.withValues(alpha: 0.4),
                        strokeWidth: 0.5,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: spots.length - 1.0,
                    minY: yMin,
                    maxY: yMax,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score Gauge Painter ───────────────────────────────────────────────────────
class _ScoreGaugePainter extends CustomPainter {
  final double score;
  final Color color;
  final Color backgroundColor;

  _ScoreGaugePainter({
    required this.score,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 12.0;
    const startAngle = math.pi * 0.75; // 135°
    const sweepAngle = math.pi * 1.5; // 270° arc

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Score arc
    final fraction = (score / 100).clamp(0.0, 1.0);
    if (fraction > 0) {
      final scorePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * fraction,
        false,
        scorePaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * fraction,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreGaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
