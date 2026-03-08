import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final BitcoinService _service = BitcoinService();
  PortfolioSummary? _portfolio;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _service.getPortfolio();
      if (mounted)
        setState(() {
          _portfolio = p;
          _isLoading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _load();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading)
      return const LoadingIndicator(message: 'Loading portfolio...');
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_portfolio == null || _portfolio!.isEmpty) return _buildEmpty();

    final p = _portfolio!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStackHero(p),
            const SizedBox(height: 16),
            _buildPnlCard(p),
            const SizedBox(height: 16),
            _buildMetricsGrid(p),
            if (p.tradeHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildAccumulationChart(p),
              const SizedBox(height: 16),
              _buildTradeList(p),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Hero — total BTC ────────────────────────────────────────────────────────
  Widget _buildStackHero(PortfolioSummary p) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                AppDecorations.primaryGradient.createShader(b),
            child: const Icon(Icons.currency_bitcoin_rounded,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text('Total BTC Stack',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (b) =>
                AppDecorations.primaryGradient.createShader(b),
            child: Text(
              '${p.totalBtcAccumulated.toStringAsFixed(8)} BTC',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '≈ ${Formatters.formatPrice(p.currentValue)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.tradeCount} DCA buy${p.tradeCount != 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  // ── PnL Card ─────────────────────────────────────────────────────────────
  Widget _buildPnlCard(PortfolioSummary p) {
    final isProfit = p.isProfit;
    final pnlColor = isProfit ? AppColors.buy : AppColors.error;
    final pnlIcon =
        isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final pnlPrefix = isProfit ? '+' : '';
    final unrealizedPnl = p.currentValue - p.totalUsdtSpent;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pnlColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: pnlColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(pnlIcon, color: pnlColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unrealized P&L',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  '$pnlPrefix${Formatters.formatPrice(unrealizedPnl)}',
                  style: TextStyle(
                    color: pnlColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: pnlColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pnlColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              '$pnlPrefix${p.unrealizedPnlPercent.toStringAsFixed(2)}%',
              style: TextStyle(
                color: pnlColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Metrics Grid ─────────────────────────────────────────────────────────
  Widget _buildMetricsGrid(PortfolioSummary p) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _metricTile(
          icon: Icons.price_change_rounded,
          label: 'Avg Cost Basis',
          value: Formatters.formatPrice(p.averageCostBasis),
          color: AppColors.info,
        ),
        _metricTile(
          icon: Icons.currency_bitcoin_rounded,
          label: 'Current BTC Price',
          value: Formatters.formatPrice(p.currentBtcPrice),
          color: AppColors.primary,
        ),
        _metricTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Total Invested',
          value: Formatters.formatPrice(p.totalUsdtSpent),
          color: AppColors.textSecondary,
        ),
        _metricTile(
          icon: Icons.savings_rounded,
          label: 'Portfolio Value',
          value: Formatters.formatPrice(p.currentValue),
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Accumulation Chart ────────────────────────────────────────────────────
  Widget _buildAccumulationChart(PortfolioSummary p) {
    final points = p.tradeHistory;
    if (points.isEmpty) return const SizedBox.shrink();

    final spots = points.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.cumulativeBtc);
    }).toList();

    final maxBtc = points.last.cumulativeBtc;

    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stacked_line_chart_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('BTC Accumulation',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.chartGrid.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) => Text(
                        val.toStringAsFixed(4),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 8),
                      ),
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: 0,
                maxY: maxBtc * 1.15,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3, color: AppColors.primary, strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
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
        ],
      ),
    );
  }

  // ── Trade history list ────────────────────────────────────────────────────
  Widget _buildTradeList(PortfolioSummary p) {
    return Container(
      decoration: AppDecorations.glassmorphicCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  color: AppColors.buy, size: 18),
              const SizedBox(width: 8),
              Text('Buy History',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          ...p.tradeHistory.reversed.take(10).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.buy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.buy, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${t.btcAcquired.toStringAsFixed(6)} BTC',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            '@ ${Formatters.formatPrice(t.averagePrice)}'
                            '${t.accumulationScore != null ? ' · Score ${t.accumulationScore!.toStringAsFixed(0)}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.formatDateTime(t.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )),
          if (p.tradeHistory.length > 10) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '... and ${p.tradeHistory.length - 10} more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: ShaderMask(
                shaderCallback: (b) =>
                    AppDecorations.primaryGradient.createShader(b),
                child: const Icon(Icons.savings_rounded,
                    size: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text('Stack Is Empty',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'When the accumulation score hits your threshold '
              'and trading is enabled, your BTC stack will grow here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
