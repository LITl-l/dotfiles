package main

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

// runRPC feeds newline-delimited request lines through ServeMCP and returns the
// decoded response objects (notifications produce no line).
func runRPC(t *testing.T, store *Store, requests ...string) []map[string]interface{} {
	t.Helper()
	in := strings.NewReader(strings.Join(requests, "\n") + "\n")
	var out bytes.Buffer
	if err := ServeMCP(in, &out, store); err != nil {
		t.Fatalf("ServeMCP: %v", err)
	}
	var resps []map[string]interface{}
	for _, line := range strings.Split(strings.TrimSpace(out.String()), "\n") {
		if line == "" {
			continue
		}
		var m map[string]interface{}
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("bad response line %q: %v", line, err)
		}
		resps = append(resps, m)
	}
	return resps
}

func TestMCPInitialize(t *testing.T) {
	s := newTestStore(t)
	r := runRPC(t, s, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}`)
	if len(r) != 1 {
		t.Fatalf("expected 1 response, got %d", len(r))
	}
	res := r[0]["result"].(map[string]interface{})
	if res["protocolVersion"] != "2025-06-18" {
		t.Fatalf("protocolVersion not echoed: %v", res["protocolVersion"])
	}
	if res["serverInfo"].(map[string]interface{})["name"] != "crumb" {
		t.Fatalf("serverInfo.name wrong: %v", res["serverInfo"])
	}
}

func TestMCPNotificationNoResponse(t *testing.T) {
	s := newTestStore(t)
	r := runRPC(t, s, `{"jsonrpc":"2.0","method":"notifications/initialized"}`)
	if len(r) != 0 {
		t.Fatalf("notification must produce no response, got %d", len(r))
	}
}

func TestMCPToolsList(t *testing.T) {
	s := newTestStore(t)
	r := runRPC(t, s, `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`)
	tools := r[0]["result"].(map[string]interface{})["tools"].([]interface{})
	if len(tools) != 3 {
		t.Fatalf("expected 3 tools, got %d", len(tools))
	}
	names := map[string]bool{}
	for _, tl := range tools {
		names[tl.(map[string]interface{})["name"].(string)] = true
	}
	for _, want := range []string{"compress", "retrieve", "stats"} {
		if !names[want] {
			t.Fatalf("missing tool %q in %v", want, names)
		}
	}
}

func TestMCPToolsCallCompressThenRetrieve(t *testing.T) {
	s := newTestStore(t)
	big := strings.Repeat("Q", 4000)
	bigJSON, _ := json.Marshal(big)
	r := runRPC(t, s,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"compress","arguments":{"content":`+string(bigJSON)+`}}}`)
	content := r[0]["result"].(map[string]interface{})["content"].([]interface{})
	stub := content[0].(map[string]interface{})["text"].(string)
	if !strings.HasPrefix(stub, "⟦crumb ") {
		t.Fatalf("compress did not return a stub: %q", stub)
	}
}

func TestMCPUnknownMethod(t *testing.T) {
	s := newTestStore(t)
	r := runRPC(t, s, `{"jsonrpc":"2.0","id":9,"method":"does/not/exist"}`)
	if r[0]["error"] == nil {
		t.Fatalf("expected error for unknown method")
	}
	code := r[0]["error"].(map[string]interface{})["code"].(float64)
	if int(code) != -32601 {
		t.Fatalf("error code = %v, want -32601", code)
	}
}

func TestMCPParseError(t *testing.T) {
	s := newTestStore(t)
	r := runRPC(t, s, `{not valid json`)
	if r[0]["error"].(map[string]interface{})["code"].(float64) != -32700 {
		t.Fatalf("expected parse error -32700")
	}
}
