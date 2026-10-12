//go:build linux

package wi

import (
	"errors"
	"os"
	"syscall"
	"unsafe"
)

// openat2(2) arguments (linux/openat2.h). The syscall number is 437 on every Linux architecture.
const (
	sysOpenat2        = 437
	resolveNoMagic    = 0x02
	resolveNoSymlinks = 0x04
)

type openHow struct{ flags, mode, resolve uint64 }

// openNoSymlinks opens path read-only without ever following a symlink in ANY path component
// (VSC-363). path is already symlink-free (filepath.EvalSymlinks), so a link met here was put
// there after the resolution and is refused with ELOOP. A kernel without openat2 (ENOSYS) or a
// sandbox that denies it (EPERM) falls back to the final-component-only O_NOFOLLOW open.
func openNoSymlinks(path string) (*os.File, error) {
	p, err := syscall.BytePtrFromString(path)
	if err != nil {
		return nil, err
	}
	how := openHow{
		flags:   uint64(syscall.O_RDONLY | syscall.O_NONBLOCK | syscall.O_NOFOLLOW | syscall.O_CLOEXEC),
		resolve: resolveNoMagic | resolveNoSymlinks,
	}
	atFDCWD := -100
	fd, _, errno := syscall.Syscall6(sysOpenat2, uintptr(atFDCWD), uintptr(unsafe.Pointer(p)),
		uintptr(unsafe.Pointer(&how)), unsafe.Sizeof(how), 0, 0)
	switch {
	case errno == 0:
		return os.NewFile(fd, path), nil
	case errors.Is(errno, syscall.ENOSYS), errors.Is(errno, syscall.EPERM):
		return os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW|syscall.O_CLOEXEC, 0)
	}
	return nil, &os.PathError{Op: "openat2", Path: path, Err: errno}
}
