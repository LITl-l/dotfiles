package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func newTestStore(t *testing.T) *Store {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("CRUMB_HASH_LEN", "12")
	s, err := NewStore(dir)
	if err != nil {
		t.Fatalf("NewStore: %v", err)
	}
	return s
}

func TestPutGetRoundtrip(t *testing.T) {
	s := newTestStore(t)
	content := []byte(`{"hello":"world","n":[1,2,3]}`)
	h, err := s.Put(content)
	if err != nil {
		t.Fatalf("Put: %v", err)
	}
	if len(h) != 12 {
		t.Fatalf("hash len = %d, want 12", len(h))
	}
	got, err := s.Get(h)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if string(got) != string(content) {
		t.Fatalf("roundtrip mismatch: got %q want %q", got, content)
	}
}

func TestPutDedup(t *testing.T) {
	s := newTestStore(t)
	c := []byte("the same content, twice")
	h1, _ := s.Put(c)
	h2, _ := s.Put(c)
	if h1 != h2 {
		t.Fatalf("dedup: hashes differ %q vs %q", h1, h2)
	}
	entries, _ := os.ReadDir(filepath.Join(s.dir, "blobs"))
	n := 0
	for _, e := range entries {
		if e.Name()[0] != '.' {
			n++
		}
	}
	if n != 1 {
		t.Fatalf("dedup: expected 1 blob, found %d", n)
	}
}

func TestGetNotFound(t *testing.T) {
	s := newTestStore(t)
	if _, err := s.Get("deadbeef0000"); err != ErrNotFound {
		t.Fatalf("Get(missing) err = %v, want ErrNotFound", err)
	}
}

func TestEventsAndStats(t *testing.T) {
	s := newTestStore(t)
	s.Put([]byte("aaaa"))
	if err := s.AppendEvent(Event{TS: 1, Op: "compress", Hash: "h1", OrigTok: 100, StubTok: 10}); err != nil {
		t.Fatalf("AppendEvent: %v", err)
	}
	s.AppendEvent(Event{TS: 2, Op: "compress", Hash: "h2", OrigTok: 50, StubTok: 5})
	st, err := s.ReadStats(10)
	if err != nil {
		t.Fatalf("ReadStats: %v", err)
	}
	if st.Compressions != 2 {
		t.Fatalf("Compressions = %d, want 2", st.Compressions)
	}
	if st.SavedTokens != (100-10)+(50-5) {
		t.Fatalf("SavedTokens = %d, want 135", st.SavedTokens)
	}
	if len(st.Recent) != 2 {
		t.Fatalf("Recent = %d, want 2", len(st.Recent))
	}
}

func TestGCByAge(t *testing.T) {
	s := newTestStore(t)
	h, _ := s.Put([]byte("old content here"))
	// backdate the blob's mtime by 30 days
	old := time.Now().Add(-30 * 24 * time.Hour)
	os.Chtimes(s.blobPath(h), old, old)
	res, err := s.GC(time.Now(), 14*24*time.Hour, 0)
	if err != nil {
		t.Fatalf("GC: %v", err)
	}
	if res.Removed != 1 {
		t.Fatalf("GC removed %d, want 1", res.Removed)
	}
	if _, err := s.Get(h); err != ErrNotFound {
		t.Fatalf("after GC Get err = %v, want ErrNotFound", err)
	}
}

func TestGCBySize(t *testing.T) {
	s := newTestStore(t)
	// three distinct blobs, ~1000 bytes each
	for i := 0; i < 3; i++ {
		buf := make([]byte, 1000)
		for j := range buf {
			buf[j] = byte('a' + i)
		}
		s.Put(buf)
	}
	// cap at 1500 bytes -> at least one blob must be evicted
	res, err := s.GC(time.Now(), 0, 1500)
	if err != nil {
		t.Fatalf("GC: %v", err)
	}
	if res.Removed < 1 {
		t.Fatalf("GC by size removed %d, want >=1", res.Removed)
	}
}
