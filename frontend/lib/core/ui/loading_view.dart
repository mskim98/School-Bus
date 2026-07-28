import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// 로딩 중 표시. 화면마다 `Center(child: CircularProgressIndicator())` 를
/// 새로 쓰지 않는다(컨벤션 §7-3).
///
/// [label] 은 **기다림이 왜 생겼는지 사용자가 모를 때만** 준다
/// (예: "노선을 불러오는 중"). 짧게 끝나는 로딩에 문구를 붙이면 깜빡여서 더 산만하다.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
