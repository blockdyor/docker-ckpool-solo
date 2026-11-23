# docker-ckpool-solo

> Hardened, multi-architecture ckpool solo-mining image with Stratum V1, Stratum V2, ZMQ, optional Mining IPC, and broad CPU portability.

The image supports Linux amd64 and arm64. Host-specific instruction-set
optimizations are disabled so a build produced on one machine does not crash on
an older CPU. The runtime contains only ckpool and its shared runtime libraries
(ZeroMQ, libsodium, and Cap'n Proto; secp256k1 is statically linked), and runs
as UID/GID `1000:1000` by default.

Standard JSON-RPC + ZeroMQ works with both Bitcoin Core and Bitcoin Knots
(including Bitcoin Knots 29.3 and earlier versions). Optional Cap'n Proto Mining
IPC (`ipcmining`) and Stratum V2 Job Declaration (`sv2jdurl`) are compiled in
and stay disabled unless explicitly configured in `ckpool.conf`.

The container entrypoint (`/app/bin/ckpool-start.sh`) exports the compiled
CKPool version to `/www/pool/version.json` when `/www` is writable, optionally
waits up to 30 seconds at startup for Bitcoin Core's IPC socket when
`APP_BITCOIN_IPC_ENABLED=true`, and reloads CKPool gracefully on `SIGTERM` only
when an explicit `.reload-trigger` file changes alongside `ckpool.conf`.
Standalone invocations without a config file (such as `--help`) `exec` CKPool
directly.

The upstream ckpool source revision, bundled `secp256k1` commit, and Debian base
image are pinned to make build inputs auditable. Release tags are immutable and
published with SBOM and provenance attestations.

## Usage

```console
$ docker run --rm ghcr.io/blockdyor/docker-ckpool-solo:v1.2.0-3 --help
-B | --btcsolo
-c CONFIG | --config CONFIG
-D | --daemonise
-g GROUP | --group GROUP
-H | --handover
-h | --help
-k | --killold
-L | --log-shares
-l LOGLEVEL | --loglevel LOGLEVEL
-n NAME | --name NAME
-N | --node
-P | --passthrough
-p | --proxy
-q | --quiet
-R | --redirector
-s SOCKDIR | --sockdir SOCKDIR
-t | --trusted
-u | --userproxy
```

```console
$ docker run --rm --volume "$PWD:/data:ro" -p 3333:3333 -p 3336:3336 ghcr.io/blockdyor/docker-ckpool-solo:v1.2.0-3 --btcsolo --config /data/ckpool.conf
[2025-12-11 17:40:54.742] ckpool generator starting
[2025-12-11 17:40:54.743] ckpool stratifier starting
[2025-12-11 17:40:54.745] ckpool connector starting
[2025-12-11 17:40:54.746] ckpool connector ready
[2025-12-11 17:40:54.760] ckpool generator ready
[2025-12-11 17:40:54.760] Connected to bitcoind: 10.21.21.8:8332
[2025-12-11 17:40:54.772] ckpool stratifier ready
[2025-12-11 17:40:54.779] Mining solo to any incoming valid BTC address username
[2025-12-11 17:40:54.779] Network diff set to 1.0
```

The configuration must point `logdir` at a location writable by UID 1000. The
default working directory, `/app`, contains a writable `logs` directory for
standalone use.

## Building

Build the native architecture locally with:

```console
docker build --tag docker-ckpool-solo:local .
docker run --rm docker-ckpool-solo:local --help
```

The pinned Debian digest and `CKPOOL_COMMIT` build argument should only be
updated together with a reviewed dependency or upstream release change.
Release tags use `<ckpool-version>-<packaging-revision>`, such as `v1.2.0-3`,
so a packaging update never overwrites an existing image.

## Licenses

The Docker packaging in this repository is MIT licensed © Umbrel, Inc.
The bundled ckpool program is licensed under GPL-3.0-or-later by Con Kolivas;
its corresponding source is the pinned upstream revision documented in the
Dockerfile, and its license text is included in the image.
