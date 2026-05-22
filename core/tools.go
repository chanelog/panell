// Package zivpn — keep golang.org/x/mobile/bind in the dependency graph.
//
// gomobile bind refuses to run if golang.org/x/mobile is not a declared
// dependency of the module being bound. The previous attempt used a
// `//go:build tools` tag, but `go mod tidy` happily prunes deps that are
// only referenced by tag-gated files in newer Go versions. So we drop
// the build tag and pay the cost of compiling a single empty package
// (golang.org/x/mobile/bind imports almost nothing on Android).
//
// Nothing in production code references this file's imports — the blank
// import only exists to anchor the module dependency.
package zivpn

import (
	_ "golang.org/x/mobile/bind"
)
