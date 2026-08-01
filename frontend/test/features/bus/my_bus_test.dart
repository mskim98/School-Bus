import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/bus/data/dto/my_bus_dto.dart';
import 'package:school_bus/features/bus/domain/my_bus.dart';

MyBus busOf({String? name, String? plateNumber, String? routeName}) =>
    MyBus.fromDto(
      MyBusDto(
        id: 3,
        seatCapacity: 25,
        onboard: 3,
        name: name,
        plateNumber: plateNumber,
        routeName: routeName,
      ),
    );

void main() {
  group('displayName — 호차 표기', () {
    test('서버 이름이 있으면 그대로 쓴다', () {
      expect(busOf(name: '3호차').displayName, '3호차');
    });

    test('★ 이름이 없으면 id 로 만든다 — 제목 자리를 비워두지 않는다', () {
      expect(busOf().displayName, '3호차');
    });

    test('빈 문자열·공백도 없는 것으로 본다', () {
      expect(busOf(name: '').displayName, '3호차');
      expect(busOf(name: '   ').displayName, '3호차');
    });

    test('앞뒤 공백은 다듬는다', () {
      expect(busOf(name: ' 5호차 ').displayName, '5호차');
    });
  });

  group('plateLabel · routeLabel — 없는 값은 null 로 접는다', () {
    test('값이 있으면 다듬어서 준다', () {
      final bus = busOf(plateNumber: ' 서울12가3456 ', routeName: '하원 A노선');

      expect(bus.plateLabel, '서울12가3456');
      expect(bus.routeLabel, '하원 A노선');
    });

    test('null 이면 null', () {
      expect(busOf().plateLabel, isNull);
      expect(busOf().routeLabel, isNull);
    });

    test('★ 빈 문자열을 이름으로 취급하지 않는다', () {
      // 화면이 "노선 미배정"과 "이름 없는 노선"을 구별할 수 있어야 한다.
      expect(busOf(routeName: '').routeLabel, isNull);
      expect(busOf(plateNumber: '  ').plateLabel, isNull);
    });
  });

  group('titleParts — 앱바 부제 조각', () {
    test('노선이 있으면 호차 + 노선', () {
      expect(busOf(name: '3호차', routeName: '하원 A노선').titleParts, [
        '3호차',
        '하원 A노선',
      ]);
    });

    test('★ 노선이 없으면 조각 자체가 빠진다 — 자리를 "-" 로 채우지 않는다', () {
      expect(busOf(name: '3호차').titleParts, ['3호차']);
    });
  });

  group('assignedCount — 서버 onboard 를 이름만 바꿔 받는다', () {
    test('배정 명부 크기이지 현재 탑승 인원이 아니다', () {
      expect(busOf().assignedCount, 3);
      expect(busOf().seatCapacity, 25, reason: '좌석 수와 배정 인원은 별개 값이다');
    });
  });
}
