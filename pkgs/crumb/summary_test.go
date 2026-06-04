package main

import (
	"strings"
	"testing"
)

func TestEstimateTokens(t *testing.T) {
	if got := EstimateTokens([]byte("abcdefgh")); got != 2 {
		t.Fatalf("EstimateTokens(8 chars) = %d, want 2", got)
	}
}

func TestDetectJSONObject(t *testing.T) {
	sum := detectSummary([]byte(`{"results":[1,2,3],"meta":{},"page":1}`))
	if sum.Type != "json" {
		t.Fatalf("type = %q, want json", sum.Type)
	}
	if !strings.Contains(sum.Detail, "results(3)") {
		t.Fatalf("detail %q missing results(3)", sum.Detail)
	}
}

func TestDetectJSONArray(t *testing.T) {
	sum := detectSummary([]byte(`[{"id":1},{"id":2}]`))
	if sum.Type != "json" || !strings.Contains(sum.Detail, "array(2)") {
		t.Fatalf("array detail = %q", sum.Detail)
	}
}

func TestDetectJSONL(t *testing.T) {
	sum := detectSummary([]byte("{\"a\":1}\n{\"a\":2}\n{\"a\":3}"))
	if sum.Type != "jsonl" || !strings.Contains(sum.Detail, "3 records") {
		t.Fatalf("jsonl detail = %q type = %q", sum.Detail, sum.Type)
	}
}

func TestDetectText(t *testing.T) {
	sum := detectSummary([]byte("line one\nline two\nplain prose here"))
	if sum.Type != "text" || !strings.Contains(sum.Detail, "3 lines") {
		t.Fatalf("text detail = %q type = %q", sum.Detail, sum.Type)
	}
}

func TestRenderStub(t *testing.T) {
	sum := detectSummary([]byte(`{"a":1}`))
	stub := RenderStub("9f3a1c8e0000", 14200, sum)
	if !strings.Contains(stub, "9f3a1c8e0000") || !strings.Contains(stub, "~14.2k tok") || !strings.Contains(stub, "type=json") {
		t.Fatalf("stub = %q", stub)
	}
	if !strings.Contains(stub, `retrieve("9f3a1c8e0000")`) {
		t.Fatalf("stub missing retrieve hint: %q", stub)
	}
}

func TestFilterJSONArray(t *testing.T) {
	content := []byte(`[{"name":"alpha"},{"name":"beta"},{"name":"alphabet"}]`)
	sum := detectSummary(content)
	out := FilterContent(content, sum, "alpha")
	if !strings.Contains(out, "alpha") || !strings.Contains(out, "alphabet") || strings.Contains(out, "beta") {
		t.Fatalf("filtered array = %q", out)
	}
}

func TestFilterTextLines(t *testing.T) {
	content := []byte("error: boom\ninfo: ok\nerror: bang")
	sum := detectSummary(content)
	out := FilterContent(content, sum, "error")
	if !strings.Contains(out, "boom") || !strings.Contains(out, "bang") || strings.Contains(out, "info: ok") {
		t.Fatalf("filtered text = %q", out)
	}
}

func TestFilterEmptyQueryReturnsAll(t *testing.T) {
	content := []byte("anything at all")
	if got := FilterContent(content, detectSummary(content), ""); got != string(content) {
		t.Fatalf("empty query = %q, want full content", got)
	}
}
