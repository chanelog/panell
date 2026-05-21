# core/ — ZIVPN native engine (Go, gomobile)

This module is built into an Android `.aar` via `gomobile bind`. The CI
workflow (`.github/workflows/android-build.yml`) builds it on every push and
drops the artifact into `app/libs/zivpn-core.aar` so the app can call into it.

When the AAR is missing, the Kotlin layer (`ZiCore.kt`) automatically falls
back to a stub mode so the rest of the app still builds and runs end-to-end.

## Local build

```sh
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init
gomobile bind -target=android -androidapi 21 -o ../app/libs/zivpn-core.aar ./
```

## Wiring the real engine

Replace the body of `core.go` with calls into the upstream zivpn-go core
(QUIC + Hysteria-style obfuscation, UDP password auth). Keep the public
`Core` type and method signatures stable so the Kotlin reflection bridge
keeps working without changes.
