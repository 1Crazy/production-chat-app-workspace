import 'package:flutter/material.dart';
import 'package:production_chat_app/shared/widgets/status_surfaces.dart';

class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      title: title,
      description: description,
      icon: Icons.dashboard_customize_outlined,
    );
  }
}
