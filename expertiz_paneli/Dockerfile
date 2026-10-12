# YerimeBak admin / personel paneli (Flutter web) -> admin.yerimebak.com.tr
# Derleme asamasi: testlerde kullanilan Flutter surumu ile ayni.
FROM buildpack-deps:bookworm AS build
ARG FLUTTER_VERSION=3.47.7
ARG YERIMEBAK_API_BASE_URL=https://admin.yerimebak.com.tr/api/v1
RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xJf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter config --no-analytics >/dev/null && flutter pub get
COPY . .
# Cizim motoru (CanvasKit) imaja gomulur: Google CDN'e bagimlilik kalmaz
RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=YERIMEBAK_API_BASE_URL=${YERIMEBAK_API_BASE_URL}

# Sunum asamasi
FROM nginx:1.27-alpine
COPY docker/nginx-admin.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
