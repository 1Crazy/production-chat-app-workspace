import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/chat/presentation/chat_time_format.dart';

void main() {
  test('formats today as 24 hour time only', () {
    expect(
      formatChatDateLabel(
        DateTime(2026, 4, 25, 9, 5),
        now: DateTime(2026, 4, 25, 12, 0),
      ),
      '09:05',
    );
  });

  test('formats yesterday as yesterday plus 24 hour time', () {
    expect(
      formatChatDateLabel(
        DateTime(2026, 4, 24, 21, 30),
        now: DateTime(2026, 4, 25, 12, 0),
      ),
      '昨天 21:30',
    );
  });

  test('formats earlier dates in current year as month day plus time', () {
    expect(
      formatChatDateLabel(
        DateTime(2026, 4, 23, 15, 32),
        now: DateTime(2026, 4, 25, 12, 0),
      ),
      '4月23日 15:32',
    );
  });

  test('formats dates from previous years as year month day plus time', () {
    expect(
      formatChatDateLabel(
        DateTime(2025, 2, 1, 16, 30),
        now: DateTime(2026, 4, 25, 12, 0),
      ),
      '2025年2月1日 16:30',
    );
  });
}
