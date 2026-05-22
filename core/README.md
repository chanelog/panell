# core/ — ZIVPN native engine (Go + gomobile)

Hand-rolled, dependency-light implementation of a Hysteria-v1-compatible
ZIVPN client. Built into an Android `.aar` via `gomobile bind` so the
Kotlin layer can call it through JNI:

```
dev.zivpn.Core{}.Start(host, port, password, sni, fd) -> error
dev.zivpn.Core{}.Stop()                                -> error
```

## Files

| File | Purpose |
|------|---------|
| `core.go`       | gomobile entry point (`Core` type, `Start`/`Stop`) |
| `hysteria.go`   | QUIC dial + Hysteria-v1 auth + per-flow streams/datagrams |
| `obfs.go`       | XOR-based UDP obfuscator (the ZIVPN `password=zi` trick) |
| `bridge.go`     | tun ↔ Hysteria bridge (UDP fast path + reply NAT) |
| `tun.go`        | `*os.File` wrapper around the VpnService tun fd |
| `packet.go`     | minimal IPv4 + UDP/TCP parser and reply-packet builder |
| `dup_unix.go`   | F_DUPFD_CLOEXEC helper (linux/android only) |

## What works today (MVP)

- ✅ Encrypted QUIC tunnel with the configured SNI to the ZIVPN server
- ✅ UDP password obfuscation (`zi` by default; any password from server's auth list)
- ✅ Hysteria-v1 authentication handshake on the first stream
- ✅ UDP datagram forwarding both directions (DNS, QUIC apps, games, voice)
- ✅ Reverse-NAT for inbound reply datagrams back to the originating flow

## Known limitations

- ⚠️ TCP traffic is currently dropped at the bridge. A follow-up will plug
  in a userspace TCP/IP stack (gVisor netstack) so HTTP/HTTPS/SSH work
  too. This is split out because gVisor + gomobile is the riskiest part
  of the toolchain and is best validated separately.
- ⚠️ IPv6 inbound packets from the tun are ignored; the Android builder
  only configures an IPv4 route, so this matches reality.
- ⚠️ Cert verification is disabled (`InsecureSkipVerify`) because public
  ZIVPN servers ship self-signed certs.

## Local build

```sh
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
gomobile init
gomobile bind -target=android -androidapi 21 -javapkg=dev \
  -o ../app/libs/zivpn-core.aar ./
```

## Where the build actually happens

GitHub Actions (`.github/workflows/android-build.yml`) does the full
pipeline: Go module resolution → gomobile init → bind → Gradle assembleDebug
→ artifacts. Build pertama mungkin perlu 1-2 iterasi untuk fix dependency
quirks (quic-go vs Android NDK, dll.) — itu wajar.
