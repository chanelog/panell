// Package zivpn — minimal tun-fd reader/writer.
//
// Android's VpnService.Builder.establish() returns a file descriptor that
// represents the tun device. Reads return raw IPv4/IPv6 packets, writes
// inject them back. This file wraps the fd so the rest of the package
// can think in terms of packets, not bytes.
package zivpn

import (
	"errors"
	"io"
	"os"
	"sync"
	"sync/atomic"
)

// tunDevice is a thin wrapper around the *os.File backing the tun fd.
// We do NOT close the underlying fd in Close() — Android owns it via
// ParcelFileDescriptor and will close it when the VpnService stops.
type tunDevice struct {
	f      *os.File
	closed atomic.Bool
	mu     sync.Mutex
}

// newTunFromFD adopts an int fd into a *os.File without taking ownership.
func newTunFromFD(fd int) (*tunDevice, error) {
	if fd < 0 {
		return nil, errors.New("zivpn: invalid tun fd")
	}
	// Dup so closing this *os.File does not affect the original fd
	// when Android decides to clean up via ParcelFileDescriptor.
	dup, err := dupFD(fd)
	if err != nil {
		return nil, err
	}
	f := os.NewFile(uintptr(dup), "tun")
	return &tunDevice{f: f}, nil
}

// Read fills p with one or more raw IP packets. The underlying tun fd
// returns one packet per read on Android.
func (t *tunDevice) Read(p []byte) (int, error) {
	if t.closed.Load() {
		return 0, io.EOF
	}
	return t.f.Read(p)
}

// Write injects a raw IP packet back into the device.
func (t *tunDevice) Write(p []byte) (int, error) {
	if t.closed.Load() {
		return 0, io.ErrClosedPipe
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	return t.f.Write(p)
}

// Close releases our duped fd. The original tun fd remains open.
func (t *tunDevice) Close() error {
	if !t.closed.CompareAndSwap(false, true) {
		return nil
	}
	return t.f.Close()
}
