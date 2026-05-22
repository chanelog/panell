// Package zivpn — UDP obfuscator compatible with ZIVPN / Hysteria-v1 style.
//
// The obfuscator XORs each UDP datagram with a keystream derived from a
// SHA-256 of the user-supplied password (commonly "zi" on public ZIVPN
// servers). Both endpoints apply the same XOR so packets look like random
// UDP noise to middleboxes that block/throttle QUIC by signature.
package zivpn

import (
	"crypto/sha256"
	"net"
)

// xorObfuscator wraps a net.PacketConn and XORs payload bytes with a
// keystream seeded from the shared password. It implements net.PacketConn
// so it can be passed straight to quic-go's Transport.
type xorObfuscator struct {
	net.PacketConn
	key []byte
}

// newObfuscator returns an obfuscated wrapper. Pass the same password the
// server is configured with (e.g. "zi", "zivpn", or any custom value in
// the server's auth list).
func newObfuscator(conn net.PacketConn, password string) *xorObfuscator {
	sum := sha256.Sum256([]byte(password))
	key := sum[:]
	return &xorObfuscator{PacketConn: conn, key: key}
}

func (o *xorObfuscator) xor(buf []byte) {
	k := o.key
	for i := range buf {
		buf[i] ^= k[i%len(k)]
	}
}

func (o *xorObfuscator) ReadFrom(p []byte) (int, net.Addr, error) {
	n, addr, err := o.PacketConn.ReadFrom(p)
	if n > 0 {
		o.xor(p[:n])
	}
	return n, addr, err
}

func (o *xorObfuscator) WriteTo(p []byte, addr net.Addr) (int, error) {
	// Make a copy so we don't mutate the caller's buffer.
	buf := make([]byte, len(p))
	copy(buf, p)
	o.xor(buf)
	return o.PacketConn.WriteTo(buf, addr)
}
