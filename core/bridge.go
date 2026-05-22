// Package zivpn — tun ↔ Hysteria session bridge.
//
// MVP scope:
//   - UDP traffic (DNS, QUIC, games, voice) is forwarded end-to-end
//     through Hysteria datagrams and the obfuscated UDP transport.
//   - TCP packets coming out of the tun are detected but currently
//     dropped; a follow-up iteration will plug in a userspace TCP/IP
//     stack (gVisor netstack) to splice TCP byte-streams through
//     client.DialTCP(). Splitting that work isolates the QUIC + obfs
//     handshake risk from the TCP-stack risk.
//
// One Bridge owns a TunDevice and a Client, plus a small NAT table that
// maps incoming reply datagrams back to the original source flow so the
// reply IP packet has the right addressing.
package zivpn

import (
	"context"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// Bridge wires a TunDevice to a Client.
type Bridge struct {
	tun     *TunDevice
	client  *Client
	cancel  context.CancelFunc
	wg      sync.WaitGroup
	udpMu   sync.Mutex
	udpFlow map[string]FlowKey
	stopped atomic.Bool
}

// NewBridge takes ownership of tun and client until Close().
func NewBridge(tun *TunDevice, client *Client) *Bridge {
	return &Bridge{
		tun:     tun,
		client:  client,
		udpFlow: make(map[string]FlowKey),
	}
}

// Run blocks until Close() is invoked or a fatal IO error occurs.
func (b *Bridge) Run(parent context.Context) error {
	ctx, cancel := context.WithCancel(parent)
	b.cancel = cancel

	b.wg.Add(1)
	go func() { defer b.wg.Done(); b.readDatagrams(ctx) }()

	buf := make([]byte, 65535)
	for {
		if b.stopped.Load() {
			return nil
		}
		n, err := b.tun.Read(buf)
		if err != nil {
			cancel()
			b.wg.Wait()
			return err
		}
		if n < 20 {
			continue
		}
		key, payload, _, perr := Parse(buf[:n])
		if perr != nil {
			continue
		}
		if key.IsUDP {
			b.handleUDP(key, payload)
			continue
		}
		// TCP path is reserved for the next iteration once gVisor
		// netstack is wired up. Dropping silently here keeps the
		// MVP focused on the UDP/QUIC-heavy ZIVPN use cases.
	}
}

func (b *Bridge) handleUDP(key FlowKey, payload []byte) {
	dst := key.DstIP.String()
	mapKey := dst + ":" + portString(key.DstPort) + "/" + portString(key.SrcPort)
	b.udpMu.Lock()
	b.udpFlow[mapKey] = key
	b.udpMu.Unlock()

	cp := make([]byte, len(payload))
	copy(cp, payload)
	_ = b.client.SendDatagram(dst, key.DstPort, cp)
}

func (b *Bridge) readDatagrams(ctx context.Context) {
	for {
		if b.stopped.Load() {
			return
		}
		dctx, cancel := context.WithTimeout(ctx, 1*time.Second)
		data, err := b.client.conn.ReceiveDatagram(dctx)
		cancel()
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			continue
		}
		if len(data) < 4 {
			continue
		}
		addrLen := int(data[0])<<8 | int(data[1])
		if addrLen+4 > len(data) {
			continue
		}
		host := string(data[2 : 2+addrLen])
		port := uint16(data[2+addrLen])<<8 | uint16(data[3+addrLen])
		payload := data[4+addrLen:]

		ip := net.ParseIP(host).To4()
		if ip == nil {
			continue
		}
		mapKey := ip.String() + ":" + portString(port)
		b.udpMu.Lock()
		var found FlowKey
		var hit bool
		for k, v := range b.udpFlow {
			if startsWith(k, mapKey+"/") {
				found = v
				hit = true
				break
			}
		}
		b.udpMu.Unlock()
		if !hit {
			continue
		}
		reply := BuildUDPReply(found, payload)
		_, _ = b.tun.Write(reply)
	}
}

// Close stops the bridge.
func (b *Bridge) Close() error {
	if !b.stopped.CompareAndSwap(false, true) {
		return nil
	}
	if b.cancel != nil {
		b.cancel()
	}
	if b.tun != nil {
		_ = b.tun.Close()
	}
	if b.client != nil {
		_ = b.client.Close()
	}
	b.wg.Wait()
	return nil
}

func portString(p uint16) string {
	const digits = "0123456789"
	if p == 0 {
		return "0"
	}
	buf := [5]byte{}
	i := len(buf)
	for p > 0 {
		i--
		buf[i] = digits[p%10]
		p /= 10
	}
	return string(buf[i:])
}

func startsWith(s, prefix string) bool {
	return len(s) >= len(prefix) && s[:len(prefix)] == prefix
}
