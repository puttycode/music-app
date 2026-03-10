import 'package:flutter/material.dart';
import 'package:music_app/core/theme/text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({
    Key? key,
    required this.title,
    this.onSeeAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.headlineMedium),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('查看全部'),
            ),
        ],
      ),
    );
  }
}
