// Package zivpn — gomobile entry point.
//
// Kotlin reflection bridge in the Android app calls these methods:
//
//   dev.zivpn.Core{}.Start(host, port, password, sni, fd)  -> error
//   dev.zivpn.Core{}.Stop()                               -> error
//
// gomobile's bind tool flattens the package into the Java class
// `dev.zivpn.Core` automatically (the package's go module path is
// `dev.zivpn` and the exported type is `Core`).
package zivpn

import (
	"context"
	"errors"
	"sync"
)

// Core is the only type exposed to Java/Kotlin. It owns one Bridge
// at a time; concurrent Start() calls return an error.
type Core struct {
	mu     sync.Mutex
	bridge *Bridge
}

// Start brings up the tunnel. fd is the int fd returned by
// VpnService.Builder.establish().
func (c *Core) Start(host string, port int, password, sni string, fd int) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.bridge != nil {
		return errors.New("zivpn: already running")
	}
	tun, err := NewTunFromFD(fd)
	if err != nil {
		return err
	}
	cli, err := Dial(context.Background(), Config{
		Host:     host,
		Port:     port,
		Password: password,
		SNI:      sni,
	})
	if err != nil {
		_ = tun.Close()
		return err
	}
	br := NewBridge(tun, cli)
	c.bridge = br
	go func() {
		// Run blocks; we don't surface its error back to Java because
		// gomobile-bound goroutines can't return values. The Android
		// side observes connection state via its own broadcasts.
		_ = br.Run(context.Background())
	}()
	return nil
}

// Stop tears the tunnel down. Safe to call repeatedly.
func (c *Core) Stop() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.bridge == nil {
		return nil
	}
	err := c.bridge.Close()
	c.bridge = nil
	return err
}
