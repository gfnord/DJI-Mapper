# Production Dockerfile for DJI-Mapper Web (dji.sartrainer.org).
# Builds the Flutter web app inside Docker from a clean git checkout, so a deploy
# needs nothing pre-built on the server. Works on amd64 and arm64 hosts.

# Stage 1: build the Flutter web app
FROM debian:bookworm-slim AS flutter-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

# Keep in step with flutter-version in .github/workflows/main.yml
ARG FLUTTER_VERSION=3.35.0
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter config --no-analytics \
    && flutter precache --web

WORKDIR /app
# Path dependencies must be present before `pub get`
COPY pubspec.yaml pubspec.lock ./
COPY packages ./packages
RUN flutter pub get

COPY lib ./lib
COPY assets ./assets
COPY web ./web
RUN flutter build web --release

# Stage 2: serve the static build
FROM nginx:alpine
COPY --from=flutter-build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
