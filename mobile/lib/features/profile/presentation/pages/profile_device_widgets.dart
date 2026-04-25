part of 'profile_page.dart';

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyStateCard(
      title: '暂无设备',
      description: '登录后会在这里显示当前账号的设备列表。',
      icon: Icons.devices_other_rounded,
    );
  }
}

class _DeviceSessionCard extends StatelessWidget {
  const _DeviceSessionCard({
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
    required this.onRemove,
  });

  final String deviceName;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCurrent;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              color: Color(0xFF2F6BFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '创建于 ${_formatDate(createdAt)}\n最近活跃 ${_formatDate(lastSeenAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          isCurrent
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '当前设备',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF2F6BFF),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () async {
                    await onRemove?.call();
                  },
                  child: const Text('移除此设备'),
                ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
