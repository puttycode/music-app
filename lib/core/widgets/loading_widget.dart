import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/colors.dart';

class LoadingWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const LoadingWidget({
    Key? key,
    this.width,
    this.height,
    this.borderRadius = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLightMode = Theme.of(context).brightness == Brightness.light;
    return Shimmer.fromColors(
      baseColor: isLightMode ? Colors.grey.shade300 : AppColors.surfaceVariant,
      highlightColor: isLightMode ? Colors.grey.shade100 : AppColors.secondary,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isLightMode ? Colors.grey.shade300 : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class LoadingList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const LoadingList({
    Key? key,
    this.itemCount = 5,
    this.itemHeight = 60,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: LoadingWidget(height: itemHeight),
      ),
    );
  }
}
