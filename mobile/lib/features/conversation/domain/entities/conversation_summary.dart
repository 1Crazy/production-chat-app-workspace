class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
  });

  final String id;
  final String title;
  final String lastMessagePreview;
}
