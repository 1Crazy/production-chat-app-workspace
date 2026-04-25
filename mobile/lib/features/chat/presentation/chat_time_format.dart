String formatChatDateLabel(DateTime dateTime, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;
  final timeLabel =
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';

  if (difference == 0) {
    return timeLabel;
  }

  if (difference == 1) {
    return '昨天 $timeLabel';
  }

  if (dateTime.year == reference.year) {
    return '${dateTime.month}月${dateTime.day}日 $timeLabel';
  }

  return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 $timeLabel';
}
