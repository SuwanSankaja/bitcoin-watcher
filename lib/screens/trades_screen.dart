import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with SingleTickerProviderStateMixin {
  final BitcoinService _bitcoinService = BitcoinService();

  List<TradeItem> _trades = [];
  bool _isLoading = true;
  String? _error;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadTrades();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadTrades() async {
    try {
      final trades = await _bitcoinService.getTradesHistory(limit: 100);
      if (mounted) {
        setState(() {
          _trades = trades;
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

  // ── Stats ──────────────────────────────────────────────────────────────────

  int get _filledCount => _trades.where((t) => t.isFilled).length;
  int get _failedCount => _trades.where((t) => !t.isFilled).length;
  int get _buyCount => _trades.where((t) => t.isBuy && t.isFilled).length;
  int get _sellCount => _trades.where((t) => !t.isBuy && t.isFilled).length;

  double get _totalVolume => _trades
      .where((t) => t.isFilled)
      .fold(0.0, (sum, t) => sum + t.notionalValue);

  // ── Group by date ──────────────────────────────────────────────────────────

  Map<String, List<TradeItem>> _groupByDate() {
    final groups = <String, List<TradeItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final t in _trades) {
      final d = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
      String label;
      if (d == today) {
        label = 'Today';
      } else if (d == yesterday) {
        label = 'Yesterday';
      } else {
        label = Formatters.formatFullDateTime(d).split('•').first.trim();
      }
      groups.putIfAbsent(label, () => []);
      groups[label]!.add(t);
    }
    return groups;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trades'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadTrades();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading trade history...');
    }

    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadTrades();
        },
      );
    }

    if (_trades.isEmpty) {
      return _buildEmptyState();
    }

    final groups = _groupByDate();
    final keys = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadTrades,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: keys.length + 1, // +1 for summary card
        itemBuilder: (context, index) {
          if (index == 0) return _buildSummaryCard();
          final dateLabel = keys[index - 1];
          final items = groups[dateLabel]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
                child: Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              ...items.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildTradeCard(t),
                  )),
            ],
          );
        },
      ),
    );
  }

  // ── Summary Card ───────────────────────────────────────────────────────────

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: AppDecorations.accentGlowCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppDecorations.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text('Overview',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'Total Trades',
                  value: '$_filledCount',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Volume',
                  value: '\$${_formatCompactK(_totalVolume)}',
                  icon: Icons.show_chart_rounded,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  label: 'Buy Orders',
                  value: '$_buyCount',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.buy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  label: 'Sell Orders',
                  value: '$_sellCount',
                  icon: Icons.trending_down_rounded,
                  color: AppColors.sell,
                ),
              ),
            ],
          ),
          if (_failedCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_failedCount failed trade${_failedCount > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trade Card ─────────────────────────────────────────────────────────────

  Widget _buildTradeCard(TradeItem trade) {
    final sideColor = trade.isBuy ? AppColors.buy : AppColors.sell;
    final statusColor = trade.isFilled ? AppColors.success : AppColors.warning;

    return GestureDetector(
      onTap: () => _showTradeDetails(trade),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder.withValues(alpha: 0.4),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Side accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: sideColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Side icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sideColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          trade.isBuy
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: sideColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Main info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${trade.side} ${trade.symbol}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontSize: 14),
                                ),
                                const Spacer(),
                                _buildStatusBadge(trade.status, statusColor),
                              ],
                            ),
                            const SizedBox(height: 5),
                            if (trade.isFilled) ...[
                              Text(
                                Formatters.formatPrice(trade.averagePrice),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${trade.executedQty.toStringAsFixed(5)} BTC',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSlippageBadge(trade),
                                ],
                              ),
                            ] else ...[
                              Text(
                                'Signal @ ${Formatters.formatPrice(trade.signalPrice)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                trade.errorMessage ?? 'Failed',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.warning),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              Formatters.formatTime(trade.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _buildSlippageBadge(TradeItem trade) {
    final pct = trade.slippagePct;
    final isPositiveSlippage = trade.isBuy ? pct < 0 : pct > 0;
    final color =
        isPositiveSlippage ? AppColors.success : AppColors.textTertiary;
    final prefix = pct >= 0 ? '+' : '';
    return Text(
      '$prefix${pct.toStringAsFixed(3)}% slip',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 10,
          ),
    );
  }

  // ── Detail Sheet ───────────────────────────────────────────────────────────

  void _showTradeDetails(TradeItem trade) {
    final sideColor = trade.isBuy ? AppColors.buy : AppColors.sell;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: sideColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      trade.isBuy
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: sideColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Trade Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    _detailRow('Side', trade.side, valueColor: sideColor),
                    _divider(),
                    _detailRow('Symbol', trade.symbol),
                    _divider(),
                    _detailRow('Status', trade.status,
                        valueColor: trade.isFilled
                            ? AppColors.success
                            : AppColors.warning),
                    _divider(),
                    _detailRow('Signal Price',
                        Formatters.formatPrice(trade.signalPrice)),
                    if (trade.isFilled) ...[
                      _divider(),
                      _detailRow('Execution Price',
                          Formatters.formatPrice(trade.averagePrice)),
                      _divider(),
                      _detailRow('Quantity',
                          '${trade.executedQty.toStringAsFixed(6)} BTC'),
                      _divider(),
                      _detailRow('Notional Value',
                          Formatters.formatPrice(trade.notionalValue)),
                      _divider(),
                      _detailRow(
                        'Slippage',
                        '${trade.slippagePct >= 0 ? '+' : ''}${trade.slippagePct.toStringAsFixed(4)}%',
                        valueColor: trade.slippagePct.abs() < 0.1
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      _divider(),
                      _detailRow('Confidence',
                          '${trade.signalConfidence.toStringAsFixed(1)}%'),
                    ] else ...[
                      _divider(),
                      _detailRow('Error', trade.errorMessage ?? 'Unknown',
                          valueColor: AppColors.warning),
                    ],
                    _divider(),
                    _detailRow('Time',
                        Formatters.formatFullDateTime(trade.timestamp)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
      height: 1, color: AppColors.cardBorder.withValues(alpha: 0.5));

  // ── Empty State ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.cardBorder.withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  size: 40, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            Text('No Trades Yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Executed trades will appear here\nonce trading is enabled.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatCompactK(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}
