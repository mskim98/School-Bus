import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// 로딩 자리표시자.
///
/// 전체화면 스피너 대신 쓴다(`docs/DESIGN_SYSTEM.md` §6). 스피너는 "뭔가
/// 돌고 있다"만 알려주지만, 스켈레톤은 **곧 무엇이 어디에 나타날지**를 미리
/// 보여줘서 화면이 바뀔 때 눈이 다시 훑을 필요가 없다. 정차 30초 안에
/// 판단해야 하는 화면에서 이 차이가 크다.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.phase = 0,
  });

  final double height;
  final double? width;

  /// 0~1 위상. 여러 개를 세로로 쌓을 때 조금씩 어긋나게 해 물결처럼 보이게 한다.
  /// 전부 같은 박자로 깜빡이면 화면 전체가 명멸해 오히려 산만하다.
  final double phase;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // 삼각파: 0 → 1 → 0. 위상을 더해 나머지 연산으로 감아 돌린다.
        // 타이머를 쓰지 않으니 dispose 타이밍에 어긋난 콜백이 남지 않는다.
        final t = (_controller.value + widget.phase) % 1.0;
        final wave = t < 0.5 ? t * 2 : (1 - t) * 2;

        return Opacity(
          opacity: 0.45 + 0.45 * wave,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
      },
    );
  }
}

/// 목록 로딩용 스켈레톤 묶음.
///
/// [itemCount] 기본값이 3인 건 시드 데이터의 학생 수와 맞춘 것이다 —
/// 실제로 나타날 개수와 자리표시자 개수가 다르면 로딩이 끝나는 순간 화면이 튄다.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 3,
    this.itemHeight = 64,
    this.header,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final int itemCount;
  final double itemHeight;

  /// 목록 위에 요약 카드 같은 게 있는 화면이면 그 높이를 준다.
  final double? header;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final header = this.header;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            SkeletonBox(height: header),
            const SizedBox(height: AppSpacing.smd),
          ],
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.smd),
            SkeletonBox(height: itemHeight, phase: i * 0.107),
          ],
        ],
      ),
    );
  }
}
