// Package zivpn — anchor golang.org/x/mobile in the dependency graph.
//
// gomobile bind refuses to operate on a module that does not declare
// golang.org/x/mobile as a direct dependency. Without an actual import
// statement somewhere in the package, `go mod tidy` will happily prune
// x/mobile back out of go.mod, even after `go get` adds it.
//
// The blank import below references one of the smallest packages in
// x/mobile (its `bind` package is mostly type metadata and depends on
// almost nothing else on Android). The Go compiler will resolve and
// type-check it, but since nothing in production code uses any symbol
// from this import, the linker will dead-code-eliminate it from the
// final AAR.
package zivpn

import (
	_ "golang.org/x/mobile/bind"
)
