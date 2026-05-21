// Package zivpn is a placeholder for the native ZIVPN/Hysteria-based core.
//
// The intent is to wire the existing zivpn-go upstream (e.g. the
// zahidbd2/zivpn reference implementation) into this package, then build it
// as an Android .aar via gomobile so the Kotlin layer can call:
//
//   dev.zivpn.Core{}.Start(host, port, password, sni, fd)
//   dev.zivpn.Core{}.Stop()
//
// For now we expose only a no-op skeleton so `gomobile bind` can succeed,
// allowing CI to validate the toolchain end-to-end before real wiring lands.
package zivpn

// Core is exported via gomobile and consumed from Kotlin via reflection.
type Core struct{}

// Start brings the tunnel up. The fd argument is the tun file descriptor
// returned by VpnService.Builder.establish() on the Android side.
func (c *Core) Start(host string, port int, password, sni string, fd int) error {
	// TODO: dial UDP to host:port using the QUIC + obfuscation parameters
	// and pump packets between fd and the encrypted transport.
	_ = host
	_ = port
	_ = password
	_ = sni
	_ = fd
	return nil
}

// Stop tears the tunnel down.
func (c *Core) Stop() error { return nil }
