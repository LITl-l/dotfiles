package main

import (
	"os"
	"path/filepath"
	"testing"
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
