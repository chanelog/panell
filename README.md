# ZiCustom

Custom Android client untuk akun **ZIVPN UDP** (Hysteria-based, dengan
obfuscation password). Dirancang sebagai alternatif yang ringan dan
bertema gelap-neon, beda dari MiniZIVPN aslinya.

## Tema

Palet warna pakai background hampir hitam dengan accent **neon purple**
(`#7C4DFF`) dan **neon cyan** (`#00E5FF`) — lihat `app/src/main/res/values/colors.xml`
kalau mau ganti.

## Build

APK di-build otomatis oleh GitHub Actions setiap push. Hasil ada di tab
**Actions → workflow run → Artifacts**:

- `ZiCustom-debug` — APK debug, siap install di HP
- `ZiCustom-release-unsigned` — APK release belum di-sign

### Build lokal (opsional)

```sh
gradle wrapper --gradle-version 8.7 --distribution-type bin
./gradlew :app:assembleDebug
# APK ada di app/build/outputs/apk/debug/
```

## Konfigurasi yang diminta app

| Field    | Contoh                | Catatan                                  |
|----------|----------------------|------------------------------------------|
| Host     | `vpn.example.com`    | FQDN atau IP server ZIVPN                |
| Port     | `6666`               | UDP port                                 |
| Password | `zi`                 | UDP obfuscation password                 |
| SNI      | `www.cloudflare.com` | TLS SNI untuk QUIC handshake             |
| MTU      | `1380`               | Default cocok untuk QUIC over UDP        |

## Status fitur

- [x] UI lengkap: form config, tombol connect/disconnect, log, status pill
- [x] VpnService Android dengan foreground notification
- [x] Persistensi config via SharedPreferences
- [x] CI build APK debug + release (unsigned) via GitHub Actions
- [x] Bridge ke native ZIVPN core (Go + gomobile) — pluggable, fallback ke stub
- [ ] Native ZIVPN core wiring penuh (placeholder di `core/core.go`)
- [ ] Signing key untuk release APK
- [ ] Import/export config via QR code

## Struktur

```
.
├── app/                     # Android app module (Kotlin + Material 3)
│   ├── src/main/java/.../ui          # MainActivity
│   ├── src/main/java/.../vpn         # VpnService
│   ├── src/main/java/.../core        # JNI/reflection bridge
│   └── src/main/res/values/colors.xml  # Palet warna custom
├── core/                    # Go module untuk ZIVPN engine (gomobile target)
└── .github/workflows/       # CI: build APK otomatis
```

## Roadmap

1. Wire engine asli ZIVPN ke `core/core.go` (port dari upstream zivpn-go).
2. Tambahin parser config (QR code / clipboard / file `.json`).
3. Sign release APK dengan keystore (di-store sebagai GitHub Secret).
