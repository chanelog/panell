# ZiCustom

Custom Android client untuk akun **ZIVPN UDP** (Hysteria-v1-based, dengan
password obfuscation). Dirancang sebagai alternatif yang ringan dan
bertema gelap-neon, beda dari MiniZIVPN aslinya.

## Tema

Palet pakai background hampir hitam dengan accent **neon purple** (`#7C4DFF`)
dan **neon cyan** (`#00E5FF`) — lihat `app/src/main/res/values/colors.xml`
kalau mau ganti.

## Build (otomatis lewat GitHub Actions)

APK di-build setiap push. Cek hasilnya di tab **Actions → workflow run
→ Artifacts**:

- `ZiCustom-debug` — APK debug, siap install di HP
- `ZiCustom-release-unsigned` — APK release belum di-sign
- `zivpn-core-aar` — native engine `.aar` (untuk debug/audit)

### Build lokal (opsional)

```sh
gradle wrapper --gradle-version 8.7 --distribution-type bin
( cd core && go mod tidy )
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
( cd core && gomobile bind -target=android -androidapi 21 -javapkg=dev \
    -o ../app/libs/zivpn-core.aar ./ )
./gradlew :app:assembleDebug
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
- [x] Native engine: QUIC + Hysteria-v1 auth + UDP password obfs (`core/`)
- [x] UDP forwarding end-to-end (DNS, QUIC apps, voice, games)
- [ ] TCP forwarding (perlu gVisor netstack — iterasi berikutnya)
- [ ] Signing key untuk release APK
- [ ] Import/export config via QR code

## Struktur

```
.
├── app/                     # Android app module (Kotlin + Material 3)
│   ├── src/main/java/.../ui          # MainActivity
│   ├── src/main/java/.../vpn         # VpnService
│   ├── src/main/java/.../core        # Reflection bridge to native AAR
│   └── src/main/res/values/colors.xml  # Palet warna custom
├── core/                    # Go module → gomobile → app/libs/zivpn-core.aar
└── .github/workflows/       # CI: build APK otomatis
```

## Roadmap

1. **Iterasi #2**: integrasi gVisor netstack untuk TCP forwarding (bisa
   browsing/streaming, tidak cuma UDP).
2. **Iterasi #3**: signing release APK pakai keystore yang disimpan di
   GitHub Secrets.
3. **Iterasi #4**: parser config via QR code / clipboard / `.json` import.

## Catatan teknis

ZIVPN protocol = Hysteria v1 + UDP XOR-obfuscation pakai SHA-256 dari password.
Server reference: [zahidbd2/udp-zivpn](https://github.com/zahidbd2/udp-zivpn)
(Content was rephrased for compliance with licensing restrictions).
