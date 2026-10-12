//go:build !linux

package wi

import (
	"os"
	"syscall"
)

// openNoSymlinks: without openat2 only the final component is protected (O_NOFOLLOW).
func openNoSymlinks(path string) (*os.File, error) {
	return os.OpenFile(path, os.O_RDONLY|syscall.O_NONBLOCK|syscall.O_NOFOLLOW|syscall.O_CLOEXEC, 0)
}
