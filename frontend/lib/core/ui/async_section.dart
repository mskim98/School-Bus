import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'error_message.dart';
import 'loading_view.dart';

/// [AsyncValue] 의 loading / error / data **세 갈래를 빠짐없이** 그린다(컨벤션 §7-3).
///
/// 화면에서 `value.when(...)` 을 직접 쓰면 로딩·에러 모양이 화면마다 갈라진다.
/// 더 나쁜 건 급할 때 `value.value` 나 `maybeWhen` 으로 한 갈래를 빼먹는 것인데,
/// 그러면 실패가 "영원한 로딩"으로 보여 사용자도 개발자도 원인을 못 찾는다.
/// 이 위젯을 거치면 세 갈래를 뺄 방법이 없다.
///
/// [onRetry] 는 웬만하면 준다 — 재시도 버튼이 없으면 사용자가 할 수 있는 일이
/// 앱을 다시 켜는 것뿐이다.
///
/// [loading] 에 `SkeletonList(...)` 를 주면 스피너 대신 스켈레톤이 나온다.
/// 디자인 시스템은 목록·카드 화면에서 **스켈레톤을 우선**한다
/// (`docs/DESIGN_SYSTEM.md` §6) — 곧 무엇이 어디 나타날지 미리 보여줘서
/// 화면이 바뀔 때 눈이 다시 훑을 필요가 없다.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingLabel,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingLabel;

  /// 로딩 자리에 그릴 것. 주지 않으면 [LoadingView](스피너).
  final Widget Function()? loading;

  @override
  Widget build(BuildContext context) {
    final loading = this.loading;

    return value.when(
      loading: () =>
          loading != null ? loading() : LoadingView(label: loadingLabel),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
      data: data,
    );
  }
}
