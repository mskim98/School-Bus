# Flutter Web 빌드 → nginx 정적 서빙.
#
# Docker 로 띄울 수 있는 건 Web 타깃뿐이다 — 컨테이너 안에서 Android/iOS 앱을 "실행"할 방법은
# 없다(빌드만 가능). 모바일 실기기 확인은 같은 코드베이스를 `flutter run` 으로 Docker 밖에서 돌린다.
# 상세: frontend/docs/FLUTTER_FRONTEND_PLAN.md §1.2

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# 의존성 해석만 먼저 캐시 — lib/ 변경 시 pub get 을 다시 돌지 않게 한다
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# API_BASE_URL 은 "브라우저가 보는 주소"다. 컨테이너 이름(backend:8080)이 아니라 localhost:8080 —
# 요청 주체가 컨테이너가 아니라 사용자 브라우저이기 때문. 배포 시 build-arg 로 덮어쓴다.
ARG API_BASE_URL=http://localhost:8080
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
