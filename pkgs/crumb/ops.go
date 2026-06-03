package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

func minTokens() int {
	if v := os.Getenv("CRUMB_MIN_TOKENS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			return n
		}
	}
	return 50
}

func pricePerMTok() float64 {
	if v := os.Getenv("CRUMB_PRICE_PER_MTOK"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil && f > 0 {
			return f
		}
	}
	return 0
}

// CompressContent stores content and returns a stub. Content below the min-token
// threshold is returned unchanged (no store, no event).
func CompressContent(store *Store, content []byte, ts int64) (string, error) {
	origTok := EstimateTokens(content)
	if origTok < minTokens() {
		return string(content), nil
	}
	hash, err := store.Put(content)
	if err != nil {
		return "", err
	}
	sum := detectSummary(content)
	stub := RenderStub(hash, origTok, sum)
	stubTok := EstimateTokens([]byte(stub))
	_ = store.AppendEvent(Event{TS: ts, Op: "compress", Hash: hash, OrigTok: origTok, StubTok: stubTok})
	return stub, nil
}

// RetrieveContent reads stored content for hash, optionally filtered by query.
func RetrieveContent(store *Store, hash, query string) (string, error) {
	data, err := store.Get(hash)
	if err != nil {
		return "", err
	}
	return FilterContent(data, detectSummary(data), query), nil
}

// StatsText renders human-readable savings for the store.
func StatsText(store *Store) (string, error) {
	st, err := store.ReadStats(10)
	if err != nil {
		return "", err
	}
	var b strings.Builder
	fmt.Fprintf(&b, "crumb store: %s\n", store.dir)
	fmt.Fprintf(&b, "compressions: %d\n", st.Compressions)
	fmt.Fprintf(&b, "unique blobs: %d\n", st.UniqueBlobs)
	fmt.Fprintf(&b, "tokens: orig=%d stub=%d saved=%d\n", st.OrigTokens, st.StubTokens, st.SavedTokens)
	fmt.Fprintf(&b, "store size: %.2f MB\n", float64(st.StoreBytes)/(1024*1024))
	if price := pricePerMTok(); price > 0 {
		fmt.Fprintf(&b, "est cost saved: $%.4f (at $%.2f/Mtok)\n", float64(st.SavedTokens)/1e6*price, price)
	}
	if len(st.Recent) > 0 {
		b.WriteString("recent:\n")
		for _, e := range st.Recent {
			fmt.Fprintf(&b, "  %s %s orig=%d stub=%d\n", e.Op, e.Hash, e.OrigTok, e.StubTok)
		}
	}
	return b.String(), nil
}

// dispatchTool routes an MCP/CLI tool call to the core operations. Shared by the
// MCP server and (indirectly) the CLI, so the two can never diverge.
func dispatchTool(name string, args json.RawMessage, store *Store) (string, error) {
	switch name {
	case "compress":
		var a struct {
			Content string `json:"content"`
		}
		if err := json.Unmarshal(args, &a); err != nil {
			return "", fmt.Errorf("invalid arguments for compress: %w", err)
		}
		return CompressContent(store, []byte(a.Content), time.Now().Unix())
	case "retrieve":
		var a struct {
			Hash  string `json:"hash"`
			Query string `json:"query"`
		}
		if err := json.Unmarshal(args, &a); err != nil {
			return "", fmt.Errorf("invalid arguments for retrieve: %w", err)
		}
		return RetrieveContent(store, a.Hash, a.Query)
	case "stats":
		return StatsText(store)
	default:
		return "", fmt.Errorf("unknown tool: %s", name)
	}
}
