//go:build tools
// +build tools

// Package zivpn — tools file. This file is excluded from regular builds
// (build tag `tools` is never set) but `go mod tidy` still scans its
// imports. That's exactly what we need: keep golang.org/x/mobile in
// the dependency graph so `gomobile bind` recognises this module as
// a valid bind target, without actually compiling x/mobile into the
// resulting AAR.
package zivpn

import (
	_ "golang.org/x/mobile/bind"
)
