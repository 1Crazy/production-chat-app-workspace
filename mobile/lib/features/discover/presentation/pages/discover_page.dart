import 'package:flutter/material.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    const entries = [
      (Icons.palette_outlined, '随友圈', Color(0xFF5B8CFF)),
      (Icons.qr_code_scanner_rounded, '扫一扫', Color(0xFF4FD3A6)),
      (Icons.image_search_rounded, '拍一拍', Color(0xFFFFB547)),
      (Icons.location_on_outlined, '附近的人', Color(0xFF8B7CFF)),
      (Icons.folder_open_outlined, '文件助手', Color(0xFF6ED0FF)),
      (Icons.star_border_rounded, '收藏', Color(0xFFFFA0B5)),
      (Icons.call_outlined, '语音通话', Color(0xFF45C7AA)),
      (Icons.extension_rounded, '小程序', Color(0xFF729BFF)),
      (Icons.auto_awesome_outlined, 'AI 助手', Color(0xFF57C6FF)),
      (Icons.videogame_asset_outlined, '游戏中心', Color(0xFFFFC24D)),
    ];
    const recents = ['设计规范分享', '项目进度汇报群', '每日灵感收集'];

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FAFF), Color(0xFFF7F8FC)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Text('发现', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '先把探索型入口做成参考图那种宫格布局，没有接入的能力先占位。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _DiscoverActionCard(
                  icon: entry.$1,
                  label: entry.$2,
                  color: entry.$3,
                );
              },
            ),
            const SizedBox(height: 24),
            Text('最近使用', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final item in recents) ...[
              _RecentTile(label: item),
              if (item != recents.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiscoverActionCard extends StatelessWidget {
  const _DiscoverActionCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xFF4B5563)),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F2F7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFF2F6BFF)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6BECF)),
        ],
      ),
    );
  }
}
