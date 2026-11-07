# --- build stage: качаем ровно один платформенный бинарник ---
FROM node:24-alpine AS build

ARG OPENCODE_VERSION=2.2.6
# baseline=true — бинарник без AVX2, работает на старых CPU
ARG OPENCODE_BASELINE=true
# подставляется Buildx автоматически: amd64 / arm64
ARG TARGETARCH

RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) VARIANT=linux-x64 ;; \
      arm64) VARIANT=linux-arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    if [ "${VARIANT}" = "linux-x64" ] && [ "${OPENCODE_BASELINE}" = "true" ]; then \
      VARIANT=linux-x64-baseline; \
    fi; \
    # только сам бинарник, без обёртки @opencode/cli и без optional-зависимостей
    npm install -g --prefix /tmp/oc --ignore-scripts --no-audit --no-fund \
      "@opencode/cli-${VARIANT}-musl@${OPENCODE_VERSION}"; \
    mkdir -p /out/bin; \
    cp "/tmp/oc/lib/node_modules/@opencode/cli-${VARIANT}-musl/bin/opencode" /out/bin/opencode; \
    chmod 755 /out/bin/opencode; \
    ls -lh /out/bin/opencode

# --- runtime stage: только бинарник и системные утилиты ---
FROM node:24-alpine

RUN apk add --no-cache git bash coreutils

COPY --from=build /out/bin/opencode /usr/local/bin/opencode
RUN opencode --version

WORKDIR /workspace

ENTRYPOINT ["opencode"]
