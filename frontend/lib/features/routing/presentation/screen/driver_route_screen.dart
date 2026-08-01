import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/skeleton_box.dart';
import '../../../location/application/driver_location_controller.dart';
import '../../../location/presentation/widget/driver_location_card.dart';
import '../../../rideevent/application/driver_roster_controller.dart';
import '../../../rideevent/domain/roster_student.dart';
import '../../application/driver_route_controller.dart';
import '../../domain/route_plan.dart';
import '../../domain/route_stop_group.dart';
import '../widget/route_stop_group_tile.dart';

/// 기사: 오늘의 노선 — 지도(경로·정차) + 정차 순서 시트.
///
/// 운전석에서 잠깐 보는 화면이라 "지금 어디로 가야 하는지"를 위쪽에 크게 둔다
/// (`docs/DESIGN_BRIEF_DRIVER_MOBILE.md` §5.3, 시안 `기사앱 MVP.dc.html` 257~369줄).
///
/// ⚠️ **이 화면은 노선(routing)과 명단(rideevent) 두 상태를 같이 읽는다.**
/// 진행률(`0/2명`)과 `남은 정차` 는 노선의 정차와 명단의 처리 상태를 맞춰야 나오는
/// 값인데, `driver_route_controller`(application)가 명단을 직접 읽으면 feature 간
/// 의존이 생긴다(컨벤션 C-1). 그래서 두 provider 를 **presentation 에서만** 읽어
/// 값으로 합친다 — `DriverLocationCard(mockPath:)` 가 같은 이유로 같은 방식을 쓴다
/// (`lib/features/location/presentation/widget/driver_location_card.dart:18-19`).
class DriverRouteScreen extends ConsumerWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(driverRouteControllerProvider);

    return AsyncSection(
      value: routeState,
      onRetry: () => ref.read(driverRouteControllerProvider.notifier).refresh(),
      // 스피너 대신 스켈레톤 — **지도 자리를 큰 박스로 남겨** 로딩이 끝나도
      // 화면이 튀지 않게 한다(디자인 시스템 §6).
      loading: () => const SkeletonList(header: 200, itemHeight: 72),
      data: (state) {
        // "버스가 없다"와 "노선이 없다"를 나눠 안내한다 — 기사가 할 행동이 다르다.
        // 전자는 관리자에게 요청해야 하고, 후자는 기다리면 된다.
        if (!state.hasBus) {
          return const EmptyView(
            icon: Icons.no_transfer_outlined,
            title: '배차된 버스가 없습니다',
            description: '관리자에게 버스 배차를 요청해 주세요.',
          );
        }

        final content = state.isEmpty
            ? EmptyView(
                icon: Icons.route_outlined,
                title: '오늘 배포된 노선이 없습니다',
                description: '관리자가 배차를 확정하면 이곳에 노선이 표시됩니다.',
                action: AppActionButton(
                  label: '새로고침',
                  tone: AppTone.neutral,
                  outlined: true,
                  onPressed: () => ref
                      .read(driverRouteControllerProvider.notifier)
                      .refresh(),
                ),
              )
            : _RouteView(state: state);

        // 위치 보고 패널(C8)은 노선 유무와 상관없이 항상 위에 둔다 —
        // 노선이 없어도 실 GPS 로는 보고할 수 있고, 무엇보다 기사가
        // "내 위치가 나가고 있는지"를 항상 확인할 수 있어야 한다.
        return Column(
          children: [
            DriverLocationCard(mockPath: state.current?.path ?? const []),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

/// 정차 그룹 한 개 + 그 정차의 명단 진행 상태.
///
/// 노선만으로는 "몇 명 남았는가"를 알 수 없고, 명단만으로는 "몇 번째 정차인가"를
/// 알 수 없다. 두 값을 여기서 한 덩어리로 묶어 아래 위젯들에 넘긴다.
class _StopGroupView {
  const _StopGroupView({required this.group, this.doneCount, this.memberCount});

  final RouteStopGroup group;

  /// 이 정차에서 처리가 끝난 인원. **운행 전에는 null** 이다 — 명단이 없으면
  /// "0명 처리됨"이 아니라 "셀 수 없음"이다. 0 으로 채우면 시작도 안 한 운행이
  /// 전부 `0/2명` 으로 보여 기사가 이미 시작한 줄 안다.
  final int? doneCount;

  /// 이 정차에서 **오늘 실제로 태울** 인원. 운행 전에는 null.
  ///
  /// ⚠️ 노선의 [RouteStopGroup.studentCount] 와 다를 수 있다. 노선은 배차 시점에
  /// 만들어지고 결석 신고는 그 뒤에 들어오므로, 결석한 학생은 **노선에는 남아 있고
  /// 명단에서만 빠진다**. 분모를 노선 인원으로 잡으면 그 정차는 아무리 처리해도
  /// `1/2명` 에서 멈춰 [isDone] 이 영원히 false 가 되고, "다음 정차"가 거기서
  /// 멈춰 그 뒤 정차들이 지도에 안 뜬다.
  final int? memberCount;

  /// 진행률의 분모. 명단을 알면 명단 기준, 모르면 노선 기준이다.
  int get total => memberCount ?? group.studentCount;

  /// 명단을 아는데 태울 사람이 하나도 없는 정차(전원 결석).
  bool get isEmptyStop => memberCount == 0;

  bool get isDone {
    final done = doneCount;
    // 명단이 없으면 판단하지 않는다. 전원 결석이면 `0 >= 0` 으로 즉시 완료다 —
    // 갈 이유가 없는 정차를 "아직 안 감"으로 두면 다음 정차가 거기서 멈춘다.
    return done != null && done >= total;
  }

  /// 카드 우하단 표기. 명단이 없으면 인원수만 낸다.
  String get progressLabel {
    if (doneCount == null) return '${group.studentCount}명';
    // `0/0명` 은 "아직 아무도 안 태웠다"로 읽힌다. 태울 사람이 없다는 뜻을 글자로 낸다.
    if (isEmptyStop) return '대상 없음';
    return '$doneCount/$total명';
  }
}

class _RouteView extends ConsumerStatefulWidget {
  const _RouteView({required this.state});

  final DriverRouteState state;

  @override
  ConsumerState<_RouteView> createState() => _RouteViewState();
}

class _RouteViewState extends ConsumerState<_RouteView> {
  /// 시트가 덮는 화면 비율. 지도와 목록이 서로를 가리지 않게 한 곳에서 정한다 —
  /// 카메라 버튼도 이 값을 기준으로 시트 위에 놓는다.
  static const double _sheetRatio = 0.55;

  /// 지도 위쪽을 "다음 정차" 카드가 덮는 높이(대략).
  ///
  /// 카드는 글자 크기에 따라 늘어나므로 정확한 값을 빌드 중에 알 수 없다. 정확히
  /// 재려면 카드에 `GlobalKey` 를 달고 한 프레임 뒤에 읽어야 하는데, 그 복잡도를
  /// 감수할 만큼 정확도가 필요한 값이 아니다 — **모자라면 경로가 카드에 살짝
  /// 가리고, 넘치면 여백이 조금 남을 뿐**이라 넉넉한 쪽으로 잡는다.
  static const double _nextCardInset = 96;

  /// 지도가 준비되면 어댑터가 한 번 넘겨주는 카메라 손잡이(§5.3).
  ///
  /// `setState` 를 하지 않는다 — 이 값이 바뀌었다고 다시 그릴 게 없고, 지도
  /// 준비 콜백은 빌드 도중에 올 수 있어 여기서 재빌드를 부르면 위험하다.
  MapCameraController? _camera;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final plan = state.current!;
    final adapter = ref.watch(mapViewAdapterProvider);
    final directions = state.availableDirections;

    // 명단은 운행을 시작해야 생긴다. 없으면 진행률 없이 노선만 그린다.
    final rosterState = ref.watch(driverRosterControllerProvider).value;
    final views = _mergeRoster(plan, rosterState);

    // 다음 정차 = 아직 안 끝난 첫 정차. 명단이 없으면 첫 정차다.
    // 전부 끝났으면 -1 — 그때는 "다음 정차" 카드를 띄우지 않는다.
    final nextIndex = views.indexWhere((view) => !view.isDone);

    // 내 위치 버튼이 쓸 좌표. 아직 한 번도 안 보냈으면 null 이다.
    final myPoint = ref.watch(
      driverLocationControllerProvider.select((s) => s.lastPoint),
    );

    return Column(
      children: [
        // 등원/하원이 둘 다 배포됐을 때만 전환 탭을 보여준다.
        if (directions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<RouteDirection>(
                // 기본 높이가 40 이라 터치 최소값(48)에 미달한다 — 흔들리는 차
                // 안에서 쓰는 화면이라 여기서 줄이지 않는다(§3.3).
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppTouch.min),
                ),
                segments: [
                  for (final d in directions)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {plan.direction},
                onSelectionChanged: (selection) => ref
                    .read(driverRouteControllerProvider.notifier)
                    .select(selection.first),
              ),
            ),
          ),

        // 지도가 화면의 절반 정도를 쓰고, 정차 시트가 그 위로 올라온다 —
        // 목록만으로는 방향 감각이 안 잡히고, 지도만으로는 순서를 못 읽는다.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sheetHeight = constraints.maxHeight * _sheetRatio;

              return Stack(
                children: [
                  Positioned.fill(
                    child: adapter.build(
                      routes: [MapRouteSpec(points: plan.path)],
                      markers: _markersOf(plan, views, nextIndex, myPoint),
                      // 지도는 화면 전체를 쓰지만 아래는 정차 시트가, 위는 다음
                      // 정차 카드가 덮는다. 그 넓이를 알려줘야 `전체 경로` 가
                      // **보이는 영역의 한가운데**에 경로를 놓는다.
                      obscured: EdgeInsets.only(
                        top: nextIndex >= 0 ? _nextCardInset : 0,
                        bottom: sheetHeight,
                      ),
                      onReady: (camera) => _camera = camera,
                    ),
                  ),

                  // 지도 위 최상단 — 화면을 스크롤하지 않아도 다음 목적지가 보인다.
                  if (nextIndex >= 0)
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _NextStopCard(view: views[nextIndex]),
                    ),

                  // 카메라 버튼은 시트 바로 위, 오른손이 닿는 자리에 둔다
                  // (시안 308~317줄).
                  Positioned(
                    right: AppSpacing.md,
                    bottom: sheetHeight + AppSpacing.md,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 확대/축소는 손가락 두 개나 휠 없이도 돼야 한다 —
                        // 운전석에서 한 손으로, 장갑 낀 채로 쓰는 화면이다.
                        _MapCameraButton(
                          icon: Icons.add,
                          label: '확대',
                          onPressed: () => _camera?.zoomBy(1),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MapCameraButton(
                          icon: Icons.remove,
                          label: '축소',
                          onPressed: () => _camera?.zoomBy(-1),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // 좌표가 없으면 **숨긴다.** 회색 버튼으로 남기면
                        // "고장"으로 읽히고, 눌러도 아무 일이 없는 이유를
                        // 기사가 알 방법이 없다.
                        if (myPoint case final point?) ...[
                          _MapCameraButton(
                            icon: Icons.my_location,
                            label: '내 위치',
                            onPressed: () => _camera?.moveTo(point),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        _MapCameraButton(
                          icon: Icons.fit_screen,
                          label: '전체 경로',
                          onPressed: () => _camera?.fitAll(),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: sheetHeight,
                    child: _StopSheet(
                      plan: plan,
                      views: views,
                      nextIndex: nextIndex,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 정차 마커 + 학원(출발·도착지) 마커.
  ///
  /// **그룹 단위로 찍는다.** `plan.stops` 를 그대로 쓰면 같은 정류장에서 타는
  /// 학생 수만큼 마커가 겹쳐 찍힌다(실측: 정차 2곳에 마커 6개).
  ///
  /// 학원 좌표를 따로 주는 API 가 없다. 노선 경로가 학원에서 시작하므로
  /// 경로의 첫 점을 학원으로 본다.
  List<MapMarkerSpec> _markersOf(
    RoutePlan plan,
    List<_StopGroupView> views,
    int nextIndex,
    GeoPoint? myPoint,
  ) {
    return [
      if (plan.path.isNotEmpty)
        MapMarkerSpec(point: plan.path.first, kind: MapMarkerKind.depot),
      for (final (index, view) in views.indexed)
        MapMarkerSpec(
          point: view.group.point,
          // 다음 정차만 채운 원이다 — 채운 원이 여럿이면 지도만 봐서는
          // 어디로 먼저 가는지 안 읽힌다(§5.3).
          kind: view.isDone
              ? MapMarkerKind.visitedStop
              : index == nextIndex
              ? MapMarkerKind.stop
              : MapMarkerKind.upcomingStop,
          label: '${view.group.seq}',
        ),
      // 내 버스. **정차 마커보다 뒤에 넣어야 위에 그려진다** — 정류장에 붙어
      // 정차했을 때 버스가 정차 마커에 가리면 "지금 어디쯤인가"가 안 보인다.
      //
      // 관리자 관제 지도에는 있는데 정작 기사 화면에는 없었다. 기사도 자기가
      // 경로 위 어디에 있는지를 봐야 다음 정차까지 얼마나 남았는지 가늠한다.
      // 위치 전송이 꺼져 있으면 좌표 자체가 없어 마커도 없다(위 패널이 그 사실을
      // 이미 글자로 알리므로 여기서 또 안내하지 않는다).
      if (myPoint != null)
        MapMarkerSpec(point: myPoint, kind: MapMarkerKind.bus),
    ];
  }

  /// 노선 정차 그룹에 명단의 이름·진행 상태를 얹는다.
  ///
  /// **운행 시작 전에는 아무것도 얹지 않는다.** 노선 응답에 정류장명이 없어
  /// `1번 정차` 로 보이는 게 정상이다 — 이름을 지어내면 다른 학원에서 틀린
  /// 이름이 뜬다(`RouteStopGroup` 주석).
  List<_StopGroupView> _mergeRoster(
    RoutePlan plan,
    DriverRosterState? rosterState,
  ) {
    final groups = RouteStopGroup.group(plan.stops);
    final direction = rosterState?.direction;
    final students = rosterState?.students ?? const <RosterStudent>[];

    // 등원 계획을 보는 중에 하원 운행이 돌고 있으면 두 값은 남남이다 —
    // 그대로 겹치면 엉뚱한 정차가 완료로 보인다.
    final matched =
        direction != null &&
        students.isNotEmpty &&
        direction.wireName == plan.direction.wireName;
    if (!matched) {
      return [for (final group in groups) _StopGroupView(group: group)];
    }

    final byId = {for (final student in students) student.studentId: student};
    final views = <_StopGroupView>[];

    for (final group in groups) {
      // 노선에는 있는데 명단에 없는 학생은 그냥 빠진다 — 억지로 채우면
      // 진행률이 실제와 어긋난다.
      final members = <RosterStudent>[
        for (final id in group.studentIds) ?byId[id],
      ];

      // 정류장명은 명단에만 있다. 같은 좌표라 어느 학생 것을 써도 같지만,
      // 서버가 비워 보낼 수 있으니 값이 있는 첫 학생을 고른다.
      String? label;
      for (final member in members) {
        if (member.location case final place?) {
          label = place;
          break;
        }
      }

      views.add(
        _StopGroupView(
          group: group.withRoster(
            label: label,
            studentNames: [for (final member in members) member.name],
          ),
          // 분모는 노선 인원이 아니라 **명단에 실제로 있는 인원**이다.
          // 결석 학생은 노선에 남아 있고 명단에서만 빠지기 때문이다.
          memberCount: members.length,
          // "끝났다"의 기준은 `nextActionFor` 하나뿐이다 — 여기서 다시
          // 정의하면 명단 화면의 `✓ 완료` 표시와 진행률이 어긋난다.
          doneCount: members
              .where((member) => member.nextActionFor(direction) == null)
              .length,
        ),
      );
    }

    return views;
  }
}

/// 지도 우하단 카메라 버튼(시안 308~317줄).
///
/// 시안은 그림자를 썼지만 우리는 **elevation 0 + `outlineVariant` 테두리**로 둔다
/// (§3.4 — 그림자는 지도 위 마커에만).
class _MapCameraButton extends StatelessWidget {
  const _MapCameraButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  /// 시안이 정한 크기(§5.3). 48 최소값보다 크게 잡은 건 지도 위에서 조준하는
  /// 버튼이라 여유가 더 필요해서다.
  static const double _size = 52;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          // 아이콘만 두지 않는다 — 무엇을 하는 버튼인지 글자로도 읽혀야 한다
          // (§0-1). 글자가 커지면 최소 크기만 지키고 버튼이 같이 자란다.
          constraints: const BoxConstraints(minWidth: _size, minHeight: _size),
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: scheme.onSurface),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지도 위에 떠 있는 "다음 정차" 카드(시안 296~306줄).
///
/// 시안은 그림자를 썼지만 우리는 **elevation 0 + `outlineVariant` 테두리**로 둔다
/// (§3.4 — 그림자는 지도 위 마커에만).
class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.view});

  /// 이 폭을 넘으면 제목과 ETA 가 한 줄에 안 들어간다(§7-5).
  static const double _stackAboveTextScale = 1.15;

  /// 배지 지름(글자 배율 100% 기준). 지도 위 카드라 목록의 32 보다 한 단 크다.
  static const double _badgeSize = 34;

  final _StopGroupView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = view.group;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final badge = Container(
      // 글자를 키우면 배지도 같이 키운다 — `RouteStopGroupTile` ·
      // `RosterStopGroupCard` 의 순번 배지와 같은 계산이다.
      width: _badgeSize * scale,
      height: _badgeSize * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTone.primary.solid(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${group.seq}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: AppTone.primary.onSolid(context),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '다음 정차',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        // 제목·보조줄 문구는 도메인이 정한다 — 운행 전에는 `1번 정차`·`2명`,
        // 운행 중에는 정류장명·학생 이름이 온다.
        Text(group.title, style: theme.textTheme.titleMedium),
        Text(
          group.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    // ETA 는 서버가 초로 주므로 사람이 읽는 형태로 바꿔 보여준다(§7-8).
    final eta = Text(
      group.etaLabel,
      style: theme.textTheme.titleMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    final stacked = scale > _stackAboveTextScale;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: scheme.surface,
        // 지도 위에 떠 있는 카드라 20 이다(§3.2). 정차 목록의 행(12)과
        // 같은 모서리면 카드와 항목이 같은 위계로 읽힌다.
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    badge,
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(child: body),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                eta,
              ],
            )
          : Row(
              children: [
                badge,
                const SizedBox(width: AppSpacing.smd),
                Expanded(child: body),
                const SizedBox(width: AppSpacing.sm),
                eta,
              ],
            ),
    );
  }
}

/// 지도 아래에서 올라오는 정차 순서 시트(시안 325~366줄).
class _StopSheet extends ConsumerWidget {
  const _StopSheet({
    required this.plan,
    required this.views,
    required this.nextIndex,
  });

  /// 시트 손잡이 폭. 높이는 `AppSpacing.xs` 다.
  ///
  /// 토큰에 없는 값이라 이름을 붙여 둔다 — 끌 수 있는 시트가 아니라 "아래는 목록"을
  /// 알리는 표식이라, 손가락에 맞출 필요 없이 M3 드래그 핸들 관행값을 그대로 쓴다.
  static const double _handleWidth = 44;

  final RoutePlan plan;
  final List<_StopGroupView> views;
  final int nextIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        children: [
          // 지도와 시트의 경계를 알려주는 손잡이. 실제로 끌 수는 없지만
          // "아래는 목록"이라는 구분이 없으면 지도가 잘린 것처럼 보인다.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Container(
              width: _handleWidth,
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _RouteSummary(plan: plan, views: views),
          ),
          const SizedBox(height: AppSpacing.smd),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '정차 순서',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${views.length}곳',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(driverRouteControllerProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                itemCount: views.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.smd),
                itemBuilder: (context, index) {
                  final view = views[index];
                  return RouteStopGroupTile(
                    group: view.group,
                    isNext: index == nextIndex,
                    isLast: index == views.length - 1,
                    isDone: view.isDone,
                    // 명단이 없으면(운행 전) 넘기지 않는다 — 타일이 인원수를 낸다.
                    progressLabel: view.doneCount == null
                        ? null
                        : view.progressLabel,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 총 거리·총 소요·남은 정차 — 운행 전체 감을 한 줄로 준다(시안 329~342줄).
///
/// 방향(등원/하원)은 여기 두지 않는다. 앱바 부제에 이미 나오고, 세 칸이
/// 네 칸보다 운전 중에 훨씬 빨리 읽힌다.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.plan, required this.views});

  final RoutePlan plan;
  final List<_StopGroupView> views;

  /// 이 배율을 넘으면 세 칸이 한 줄에 안 들어간다.
  ///
  /// 폰 폭 412 기준 칸당 약 90dp 인데, `12.4km`·`약 1시간 5분` 처럼 줄바꿈
  /// 지점이 없는 값이 200% 로 커지면 가로로 넘쳐 **잘린다**. 2 + 1 로 접는다.
  /// 같은 화면의 `RosterStudentTile` 이 쓰는 것과 같은 방식이다(§7-5).
  static const double _foldAboveTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    // 운행 전에는 "몇 곳이 남았는가"를 셀 수 없다 — 명단이 없기 때문이다.
    // 그때는 정차 수를 그대로 낸다(빈 칸으로 두지 않는다).
    final tracked = views.any((view) => view.doneCount != null);
    final remaining = tracked
        ? views.where((view) => !view.isDone).length
        : views.length;

    final metrics = [
      _Metric(label: '총 거리', value: plan.distanceLabel),
      _Metric(label: '총 소요', value: plan.durationLabel),
      _Metric(label: tracked ? '남은 정차' : '정차', value: '$remaining곳'),
    ];

    if (MediaQuery.textScalerOf(context).scale(1) <= _foldAboveTextScale) {
      return Row(children: _spaced(metrics));
    }
    return Column(
      children: [
        Row(children: _spaced(metrics.sublist(0, 2))),
        const SizedBox(height: AppSpacing.sm),
        Row(children: _spaced(metrics.sublist(2))),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> items) => [
    for (final (index, item) in items.indexed) ...[
      if (index > 0) const SizedBox(width: AppSpacing.sm),
      item,
    ],
  ];
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 숫자 폭이 흔들리지 않게 자릿수를 고정한다(§2.2 Mono 대체).
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
