# --- build stage: ставим opencode, в образ тащим только один нужный бинарник ---
FROM node:24-alpine AS build

# Версия задаётся из workflow (build-arg OPENCODE_VERSION)
ARG OPENCODE_VERSION=2.2.6
# baseline=true — бинарник без AVX2, работает на старых CPU (по умолчанию)
ARG OPENCODE_BASELINE=true
# Автоматически подставляется Buildx: amd64 / arm64
ARG TARGETARCH

# python3/g++/make — страховка на случай нативных зависимостей; в runtime не попадают
RUN apk add --no-cache python3 g++ make

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) \
        if [ "${OPENCODE_BASELINE}" = "true" ]; then \
          VARIANT=linux-x64-baseline-musl; \
        else \
          VARIANT=linux-x64-musl; \
        fi ;; \
      arm64) VARIANT=linux-arm64-musl ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    # обёртка без optional-зависимостей и без postinstall:
    # он выбрал бы бинарник по CPU сборочной машины (на раннере это AVX2)
    npm install -g --prefix /opt/opencode --ignore-scripts --omit=optional \
      --no-audit --no-fund "@opencode/cli@${OPENCODE_VERSION}"; \
    # явно ставим ровно один платформенный бинарник
    npm install -g --prefix /opt/opencode --ignore-scripts \
      --no-audit --no-fund "@opencode/cli-${VARIANT}@${OPENCODE_VERSION}"; \
    cp "/opt/opencode/lib/node_modules/@opencode/cli-${VARIANT}/bin/opencode" \
       /opt/opencode/lib/node_modules/@opencode/cli/bin/opencode.exe; \
    chmod 755 /opt/opencode/lib/node_modules/@opencode/cli/bin/opencode.exe; \
    rm -rf /opt/opencode/lib/node_modules/@opencode/cli-linux-* \
           /opt/opencode/lib/node_modules/@opencode/cli-darwin-* \
           /opt/opencode/lib/node_modules/@opencode/cli-windows-*; \
    npm cache clean --force

# --- runtime stage: только необходимое для запуска ---
FROM node:24-alpine

RUN apk add --no-cache git bash coreutils

COPY --from=build /opt/opencode /opt/opencode
RUN ln -sf /opt/opencode/bin/opencode /usr/local/bin/opencode \
    && opencode --version

WORKDIR /workspace

ENTRYPOINT ["opencode"]
