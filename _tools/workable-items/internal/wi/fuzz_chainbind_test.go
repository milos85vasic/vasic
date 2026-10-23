package wi

import (
	"os"
	"path/filepath"
	"testing"
)

// FuzzLoadChainBinder: whatever bytes chain.jsonl holds, loading never panics, and a
// binder that loads never binds a record whose digest it does not hold (T068/T057).
func FuzzLoadChainBinder(f *testing.F) {
	f.Add([]byte(`{"seq":1,"artifact_path":"sha256:00","author_session_id":"s"}` + "\n"))
	f.Add([]byte("\n\n"))
	f.Add([]byte(`{"seq":1}` + "\n" + `{"seq":1}` + "\n"))
	f.Add([]byte("not json"))
	f.Fuzz(func(t *testing.T, data []byte) {
		dir := t.TempDir()
		if err := os.WriteFile(filepath.Join(dir, "chain.jsonl"), data, 0o644); err != nil {
			t.Skip()
		}
		b, err := LoadChainBinder(dir)
		if err != nil {
			return
		}
		for seq := range b.rows {
			if _, err := b.Bind([]byte("bytes that are certainly not the sealed record \x00\x01"), seq); err == nil {
				t.Fatalf("seq %d bound arbitrary bytes", seq)
			}
		}
	})
}
