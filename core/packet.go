// Package zivpn — IP packet parsing helpers.
//
// We parse only what is required to route to the right tunnel primitive:
//   - IP version + protocol field
//   - IPv4/IPv6 addresses
//   - TCP/UDP source/destination ports
//
// No checksum validation is done on read (the tun driver gives us valid
// packets). On write we emit synthetic packets only for UDP responses, so
// we recompute the IPv4 + UDP checksums there.
package zivpn

import (
	"encoding/binary"
	"errors"
	"net"
)

const (
	protoTCP = 6
	protoUDP = 17
)

// flowKey identifies one logical flow in the tun stream.
type flowKey struct {
	SrcIP, DstIP net.IP
	SrcPort      uint16
	DstPort      uint16
	IsUDP        bool
}

// parsePacket decodes a raw IPv4 packet just enough to extract a flowKey and
// the L4 payload. IPv6 is ignored (returns ErrUnsupported); the Android
// builder we use only configures an IPv4 route.
func parsePacket(pkt []byte) (flowKey, []byte, int, error) {
	if len(pkt) < 20 {
		return flowKey{}, nil, 0, errors.New("packet too short")
	}
	version := pkt[0] >> 4
	if version != 4 {
		return flowKey{}, nil, 0, ErrUnsupported
	}
	ihl := int(pkt[0]&0x0F) * 4
	if ihl < 20 || len(pkt) < ihl+8 {
		return flowKey{}, nil, 0, errors.New("bad ihl")
	}
	proto := pkt[9]
	src := net.IPv4(pkt[12], pkt[13], pkt[14], pkt[15]).To4()
	dst := net.IPv4(pkt[16], pkt[17], pkt[18], pkt[19]).To4()

	switch proto {
	case protoTCP:
		sp := binary.BigEndian.Uint16(pkt[ihl : ihl+2])
		dp := binary.BigEndian.Uint16(pkt[ihl+2 : ihl+4])
		return flowKey{src, dst, sp, dp, false}, pkt[ihl:], ihl, nil
	case protoUDP:
		sp := binary.BigEndian.Uint16(pkt[ihl : ihl+2])
		dp := binary.BigEndian.Uint16(pkt[ihl+2 : ihl+4])
		ulen := int(binary.BigEndian.Uint16(pkt[ihl+4 : ihl+6]))
		if ulen < 8 || ihl+ulen > len(pkt) {
			return flowKey{}, nil, 0, errors.New("bad udp length")
		}
		return flowKey{src, dst, sp, dp, true}, pkt[ihl+8 : ihl+ulen], ihl, nil
	default:
		return flowKey{}, nil, 0, ErrUnsupported
	}
}

// ErrUnsupported is returned for packets we ignore on purpose.
var ErrUnsupported = errors.New("unsupported packet")

// buildUDPReply constructs a synthetic IPv4+UDP packet for a reply
// flowing from key.DstIP:key.DstPort -> key.SrcIP:key.SrcPort.
// Returns a fresh slice ready to write to the tun device.
func buildUDPReply(key flowKey, payload []byte) []byte {
	totalLen := 20 + 8 + len(payload)
	out := make([]byte, totalLen)

	// IPv4 header
	out[0] = 0x45 // version 4, ihl 5
	out[1] = 0
	binary.BigEndian.PutUint16(out[2:4], uint16(totalLen))
	binary.BigEndian.PutUint16(out[4:6], 0) // ID
	binary.BigEndian.PutUint16(out[6:8], 0) // flags+frag
	out[8] = 64                             // TTL
	out[9] = protoUDP
	// checksum at out[10:12] computed below
	copy(out[12:16], key.DstIP.To4()) // src in reply = original dst
	copy(out[16:20], key.SrcIP.To4()) // dst in reply = original src
	ipChk := checksum(out[:20])
	binary.BigEndian.PutUint16(out[10:12], ipChk)

	// UDP header
	udp := out[20:]
	binary.BigEndian.PutUint16(udp[0:2], key.DstPort)
	binary.BigEndian.PutUint16(udp[2:4], key.SrcPort)
	binary.BigEndian.PutUint16(udp[4:6], uint16(8+len(payload)))
	// UDP checksum optional in IPv4 — leave zero.
	copy(udp[8:], payload)

	return out
}

func checksum(b []byte) uint16 {
	var sum uint32
	for i := 0; i+1 < len(b); i += 2 {
		sum += uint32(binary.BigEndian.Uint16(b[i : i+2]))
	}
	if len(b)%2 == 1 {
		sum += uint32(b[len(b)-1]) << 8
	}
	for sum>>16 != 0 {
		sum = (sum & 0xffff) + (sum >> 16)
	}
	return ^uint16(sum)
}
