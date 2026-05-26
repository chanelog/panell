//go:build linux || android

package zivpn

import "golang.org/x/sys/unix"

func dupFD(fd int) (int, error) {
	// F_DUPFD_CLOEXEC starts the search for an unused fd at 3 and sets
	// O_CLOEXEC atomically — the right choice for any duped fd we plan
	// to wrap in *os.File.
	return unix.FcntlInt(uintptr(fd), unix.F_DUPFD_CLOEXEC, 3)
}
