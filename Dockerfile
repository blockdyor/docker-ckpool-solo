# syntax=docker/dockerfile:1

ARG DEBIAN_IMAGE=debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

FROM ${DEBIAN_IMAGE} AS builder

ARG CKPOOL_COMMIT=be3e1e0796fbea60b7792a9b62fc2614764e1fc0
ARG SECP256K1_COMMIT=ebf594320dc838b9de1abb54d5ba98cef84f4297

WORKDIR /build

RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        git \
        libcapnp-dev \
        libsodium-dev \
        libtool \
        libzmq3-dev \
        pkgconf \
    && rm -rf /var/lib/apt/lists/*

# Fetch and verify the immutable upstream revisions instead of trusting movable tags.
RUN git init . \
    && git remote add origin https://bitbucket.org/ckolivas/ckpool.git \
    && git fetch --depth 1 origin "${CKPOOL_COMMIT}" \
    && test "$(git rev-parse FETCH_HEAD)" = "${CKPOOL_COMMIT}" \
    && git checkout --detach FETCH_HEAD \
    && rm -rf src/secp256k1 \
    && git init src/secp256k1 \
    && git -C src/secp256k1 remote add origin https://github.com/bitcoin-core/secp256k1.git \
    && git -C src/secp256k1 fetch --depth 1 origin "${SECP256K1_COMMIT}" \
    && test "$(git -C src/secp256k1 rev-parse FETCH_HEAD)" = "${SECP256K1_COMMIT}" \
    && git -C src/secp256k1 checkout --detach FETCH_HEAD

# Upstream selects instruction sets from the build host. That is unsafe for a
# portable multi-architecture image, particularly when arm64 is built in QEMU.
RUN sed -i "s/host_cpu = 'x86_64'/host_cpu = 'x86_64-disabled'/" configure.ac \
    && sed -i "s/host_cpu = 'aarch64'/host_cpu = 'aarch64-disabled'/" configure.ac

RUN ./autogen.sh \
    && ./configure --enable-sv2 CFLAGS="-O2 -Wall" CXXFLAGS="-O2 -Wall" \
    && grep -q '#define HAVE_SV2 1' config.h \
    && grep -q '#define HAVE_CAPNP 1' config.h \
    && make -j "$(nproc)" \
    && make check \
    && strip --strip-unneeded /build/src/ckpool

FROM ${DEBIAN_IMAGE} AS runtime

ARG CKPOOL_VERSION=1.2.0
ARG CKPOOL_COMMIT=be3e1e0796fbea60b7792a9b62fc2614764e1fc0
ARG SECP256K1_COMMIT=ebf594320dc838b9de1abb54d5ba98cef84f4297

LABEL org.opencontainers.image.title="docker-ckpool-solo" \
      org.opencontainers.image.description="Portable multi-architecture ckpool solo-mining server with Stratum V1, Stratum V2, ZMQ, and optional Mining IPC" \
      org.opencontainers.image.licenses="MIT AND GPL-3.0-or-later" \
      org.opencontainers.image.version="${CKPOOL_VERSION}" \
      io.github.blockdyor.ckpool.commit="${CKPOOL_COMMIT}" \
      io.github.blockdyor.ckpool.secp256k1_commit="${SECP256K1_COMMIT}" \
      io.github.blockdyor.ckpool.source="https://bitbucket.org/ckolivas/ckpool"

RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        libcapnp-1.1.0 \
        libsodium23 \
        libzmq5 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 ckpool \
    && useradd --uid 1000 --gid ckpool --home-dir /app --shell /usr/sbin/nologin ckpool \
    && install --directory --owner ckpool --group ckpool /app/bin /app/logs /sv2

COPY --from=builder --chown=ckpool:ckpool /build/src/ckpool /app/bin/ckpool
COPY --chmod=755 ckpool-start.sh /app/bin/ckpool-start.sh
COPY --from=builder /build/COPYING /usr/share/doc/ckpool/COPYING
COPY --from=builder /build/src/secp256k1/COPYING /usr/share/doc/ckpool/COPYING.secp256k1

WORKDIR /app
USER 1000:1000

EXPOSE 3333 3336 3337

ENTRYPOINT ["/app/bin/ckpool-start.sh"]
