import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final BitcoinService _bitcoinService = BitcoinService();

  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final notifications = await _bitcoinService.getSignalHistory(limit: 100);

      if (mounted) {
        setState(() {
          _notifications = notifications;
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

  // Group notifications by date label
  Map<String, List<NotificationItem>> _groupByDate() {
    final groups = <String, List<NotificationItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final n in _notifications) {
      final nDate =
          DateTime(n.timestamp.year, n.timestamp.month, n.timestamp.day);
      String label;
      if (nDate == today) {
        label = 'Today';
      } else if (nDate == yesterday) {
        label = 'Yesterday';
      } else {
        label = Formatters.formatFullDateTime(
          DateTime(nDate.year, nDate.month, nDate.day),
        ).split('•').first.trim();
      }
      groups.putIfAbsent(label, () => []);
      groups[label]!.add(n);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHistory();
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
      return const LoadingIndicator(message: 'Loading signal history...');
    }

    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _error = null;
          });
          _loadHistory();
        },
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    final groups = _groupByDate();
    final groupKeys = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: groupKeys.length,
        itemBuilder: (context, sectionIndex) {
          final dateLabel = groupKeys[sectionIndex];
          final items = groups[dateLabel]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionIndex > 0) const SizedBox(height: 8),
              // Date header
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
              ...items.map((n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildNotificationCard(n),
                  )),
            ],
          );
        },
      ),
    );
  }

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
                  color: AppColors.cardBorder.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Signals Yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Signal notifications will appear here when\nthe algorithm detects opportunities.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final signalColor = _getSignalColor(notification.signalType);
    final signalIcon = _getSignalIcon(notification.signalType);

    return GestureDetector(
      onTap: () => _showNotificationDetails(notification),
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
              // Colored accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: signalColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: signalColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          signalIcon,
                          color: signalColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${notification.signalType.displayName} Signal',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontSize: 15),
                                  ),
                                ),
                                SignalBadge(
                                  signalType: notification.signalType,
                                  size: 10,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Formatters.formatPrice(notification.price),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.formatTime(notification.timestamp),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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

  void _showNotificationDetails(NotificationItem notification) {
    final signalColor = _getSignalColor(notification.signalType);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: signalColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: signalColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSignalIcon(notification.signalType),
                        color: signalColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Signal Details',
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.cardBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Type', ''),
                      SignalBadge(
                          signalType: notification.signalType, size: 14),
                      const SizedBox(height: 16),
                      Divider(
                          color: AppColors.cardBorder.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'Price', Formatters.formatPrice(notification.price)),
                      const SizedBox(height: 12),
                      Divider(
                          color: AppColors.cardBorder.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      _buildDetailRow('Message', notification.message),
                      const SizedBox(height: 12),
                      Divider(
                          color: AppColors.cardBorder.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                          'Time',
                          Formatters.formatFullDateTime(
                              notification.timestamp)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (value.isNotEmpty)
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.right,
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
