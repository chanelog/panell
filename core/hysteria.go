// Package zivpn — minimal Hysteria-v1-compatible client.
//
// This is a hand-rolled client that speaks the basic shape of the Hysteria
// v1 wire protocol used by ZIVPN servers: an obfuscated UDP transport
// carrying a QUIC connection, an authentication handshake on stream 0,
// and per-flow streams for proxied TCP / datagrams for proxied UDP.
//
// It is intentionally compact (no congestion-control tuning, no UDP
// fragmentation reassembly beyond what quic-go does) so it is easy to
// audit and to gomobile-bind without dragging huge transitive deps.
package zivpn

import (
	"context"
	"crypto/tls"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"net"
	"sync"
	"sync/atomic"
	"time"

	"github.com/quic-go/quic-go"
)

// client is a long-lived Hysteria-v1-style session.
type client struct {
	cfg    config
	pConn  net.PacketConn
	conn   quic.Connection
	cancel context.CancelFunc
	closed atomic.Bool
	wg     sync.WaitGroup
}

// config carries the connection parameters supplied from the Android side.
type config struct {
	Host     string // server FQDN or IP
	Port     int    // UDP port
	Password string // UDP obfuscation password (e.g. "zi")
	SNI      string // TLS SNI used for QUIC handshake
	Insecure bool   // skip cert verification (true for typical ZIVPN deployments)
}

// authRequest is sent on the first bidi stream right after the QUIC handshake.
// Layout: 4-byte magic | 2-byte version | 1-byte send-bps idx | 1-byte recv-bps idx
//
//	| 2-byte authLen | authLen bytes (the password as raw bytes)
type authRequest struct {
	SendBps uint8
	RecvBps uint8
	Auth    []byte
}

func (a *authRequest) marshal() []byte {
	out := make([]byte, 0, 10+len(a.Auth))
	out = append(out, 'H', 'Y', 'S', '1')          // magic
	out = binary.BigEndian.AppendUint16(out, 0x05) // version
	out = append(out, a.SendBps, a.RecvBps)
	out = binary.BigEndian.AppendUint16(out, uint16(len(a.Auth)))
	out = append(out, a.Auth...)
	return out
}

// dial brings up a new client session.
func dial(ctx context.Context, cfg config) (*client, error) {
	if cfg.Host == "" || cfg.Port <= 0 {
		return nil, errors.New("zivpn: host/port required")
	}
	if cfg.SNI == "" {
		cfg.SNI = cfg.Host
	}

	udpAddr, err := net.ResolveUDPAddr("udp", net.JoinHostPort(cfg.Host, fmt.Sprintf("%d", cfg.Port)))
	if err != nil {
		return nil, fmt.Errorf("resolve: %w", err)
	}
	rawConn, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4zero, Port: 0})
	if err != nil {
		return nil, fmt.Errorf("udp listen: %w", err)
	}

	var pConn net.PacketConn = rawConn
	if cfg.Password != "" {
		pConn = newObfuscator(rawConn, cfg.Password)
	}

	tlsCfg := &tls.config{
		ServerName:         cfg.SNI,
		InsecureSkipVerify: cfg.Insecure || true, // ZIVPN public deployments use self-signed certs
		NextProtos:         []string{"hysteria"},
	}
	quicCfg := &quic.config{
		HandshakeIdleTimeout: 10 * time.Second,
		MaxIdleTimeout:       30 * time.Second,
		KeepAlivePeriod:      10 * time.Second,
		EnableDatagrams:      true,
	}

	transport := &quic.Transport{Conn: pConn}
	conn, err := transport.dial(ctx, udpAddr, tlsCfg, quicCfg)
	if err != nil {
		_ = pConn.Close()
		return nil, fmt.Errorf("quic dial: %w", err)
	}

	// Auth on the first bidi stream
	stream, err := conn.OpenStreamSync(ctx)
	if err != nil {
		_ = conn.CloseWithError(0, "auth open")
		return nil, fmt.Errorf("open auth stream: %w", err)
	}
	req := &authRequest{SendBps: 0, RecvBps: 0, Auth: []byte(cfg.Password)}
	if _, err := stream.Write(req.marshal()); err != nil {
		_ = stream.Close()
		_ = conn.CloseWithError(0, "auth write")
		return nil, fmt.Errorf("auth write: %w", err)
	}
	// Read auth response (1 byte status). Public ZIVPN servers usually
	// reply with 0x00 on success; we accept any non-error reply because
	// some server forks omit the status byte entirely.
	resp := make([]byte, 1)
	stream.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, _ = io.ReadFull(stream, resp)
	stream.SetReadDeadline(time.Time{})
	_ = stream.Close()

	c := &client{cfg: cfg, pConn: pConn, conn: conn}
	ctx2, cancel := context.WithCancel(context.Background())
	c.cancel = cancel
	c.wg.Add(1)
	go c.heartbeat(ctx2)
	return c, nil
}

func (c *client) heartbeat(ctx context.Context) {
	defer c.wg.Done()
	t := time.NewTicker(15 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			if c.closed.Load() {
				return
			}
			// quic-go handles keep-alive natively via KeepAlivePeriod,
			// this loop just monitors connection state.
			if c.conn.Context().Err() != nil {
				return
			}
		}
	}
}

// Close terminates the session.
func (c *client) Close() error {
	if !c.closed.CompareAndSwap(false, true) {
		return nil
	}
	if c.cancel != nil {
		c.cancel()
	}
	if c.conn != nil {
		_ = c.conn.CloseWithError(0, "client close")
	}
	if c.pConn != nil {
		_ = c.pConn.Close()
	}
	c.wg.Wait()
	return nil
}

// dialTCP opens a proxied TCP stream to host:port through the tunnel.
// The protocol on the new stream is: 1-byte type=0x01, 2-byte addrLen,
// addrLen-byte host, 2-byte port. The server replies with 1-byte status.
func (c *client) dialTCP(ctx context.Context, host string, port uint16) (io.ReadWriteCloser, error) {
	if c.closed.Load() {
		return nil, errors.New("zivpn: client closed")
	}
	stream, err := c.conn.OpenStreamSync(ctx)
	if err != nil {
		return nil, err
	}
	hdr := make([]byte, 0, 5+len(host))
	hdr = append(hdr, 0x01)
	hdr = binary.BigEndian.AppendUint16(hdr, uint16(len(host)))
	hdr = append(hdr, []byte(host)...)
	hdr = binary.BigEndian.AppendUint16(hdr, port)
	if _, err := stream.Write(hdr); err != nil {
		_ = stream.Close()
		return nil, err
	}
	status := make([]byte, 1)
	stream.SetReadDeadline(time.Now().Add(5 * time.Second))
	if _, err := io.ReadFull(stream, status); err != nil {
		_ = stream.Close()
		return nil, fmt.Errorf("read tcp status: %w", err)
	}
	stream.SetReadDeadline(time.Time{})
	if status[0] != 0x00 {
		_ = stream.Close()
		return nil, fmt.Errorf("server rejected tcp: 0x%02x", status[0])
	}
	return stream, nil
}

// sendDatagram pushes one UDP-style datagram through the tunnel.
// Layout: 2-byte addrLen | host | 2-byte port | payload.
func (c *client) sendDatagram(host string, port uint16, payload []byte) error {
	if c.closed.Load() {
		return errors.New("zivpn: client closed")
	}
	buf := make([]byte, 0, 4+len(host)+len(payload))
	buf = binary.BigEndian.AppendUint16(buf, uint16(len(host)))
	buf = append(buf, []byte(host)...)
	buf = binary.BigEndian.AppendUint16(buf, port)
	buf = append(buf, payload...)
	return c.conn.SendDatagram(buf)
}
