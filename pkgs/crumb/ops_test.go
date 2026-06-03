package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestCompressStoresAndStubs(t *testing.T) {
	s := newTestStore(t)
	big := []byte(strings.Repeat("x", 4000)) // ~1000 tokens, above min
	stub, err := CompressContent(s, big, 1)
	if err != nil {
		t.Fatalf("CompressContent: %v", err)
	}
	if !strings.HasPrefix(stub, "⟦crumb ") {
		t.Fatalf("expected a stub, got %q", stub)
	}
	// the stub must carry a retrievable hash
	start := strings.Index(stub, "⟦crumb ") + len("⟦crumb ")
	hash := stub[start : start+12]
	got, err := s.Get(hash)
	if err != nil || string(got) != string(big) {
		t.Fatalf("retrieve via stub hash failed: err=%v len=%d", err, len(got))
	}
}

func TestCompressSmallPassesThrough(t *testing.T) {
	s := newTestStore(t)
	small := []byte("tiny")
	out, err := CompressContent(s, small, 1)
	if err != nil {
		t.Fatalf("CompressContent: %v", err)
	}
	if out != "tiny" {
		t.Fatalf("small content should pass through unchanged, got %q", out)
	}
}

func TestRetrieveNotFound(t *testing.T) {
	s := newTestStore(t)
	if _, err := RetrieveContent(s, "nope00000000", ""); err != ErrNotFound {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestStatsTextReportsSaved(t *testing.T) {
	s := newTestStore(t)
	CompressContent(s, []byte(strings.Repeat("y", 4000)), 1)
	out, err := StatsText(s)
	if err != nil {
		t.Fatalf("StatsText: %v", err)
	}
	if !strings.Contains(out, "saved=") || !strings.Contains(out, "compressions: 1") {
		t.Fatalf("stats text = %q", out)
	}
}

func TestDispatchToolCompress(t *testing.T) {
	s := newTestStore(t)
	args := json.RawMessage(`{"content":` + jsonString(strings.Repeat("z", 4000)) + `}`)
	out, err := dispatchTool("compress", args, s)
	if err != nil || !strings.HasPrefix(out, "⟦crumb ") {
		t.Fatalf("dispatch compress: out=%q err=%v", out, err)
	}
}

func jsonString(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}
