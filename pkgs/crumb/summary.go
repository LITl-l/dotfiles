package main

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

// EstimateTokens is a rough heuristic: ceil(chars / 4).
func EstimateTokens(content []byte) int {
	return (len(content) + 3) / 4
}

func humanTokens(n int) string {
	if n >= 1000 {
		return fmt.Sprintf("%.1fk", float64(n)/1000.0)
	}
	return fmt.Sprintf("%d", n)
}

// Summary describes detected structure of content.
type Summary struct {
	Type    string // "json" | "jsonl" | "text"
	Detail  string
	Preview string
}

func detectSummary(content []byte) Summary {
	trimmed := strings.TrimSpace(string(content))

	var js interface{}
	if trimmed != "" && json.Unmarshal([]byte(trimmed), &js) == nil {
		switch v := js.(type) {
		case map[string]interface{}:
			return Summary{Type: "json", Detail: "keys=[" + jsonObjectKeys(v) + "]", Preview: preview(trimmed)}
		case []interface{}:
			detail := fmt.Sprintf("array(%d)", len(v))
			if len(v) > 0 {
				if first, ok := v[0].(map[string]interface{}); ok {
					detail += " elem_keys=[" + jsonObjectKeys(first) + "]"
				}
			}
			return Summary{Type: "json", Detail: detail, Preview: preview(trimmed)}
		default:
			return Summary{Type: "json", Detail: "scalar", Preview: preview(trimmed)}
		}
	}

	lines := strings.Split(trimmed, "\n")
	jsonlOK := len(lines) > 1
	count := 0
	for _, ln := range lines {
		ln = strings.TrimSpace(ln)
		if ln == "" {
			continue
		}
		var x interface{}
		if json.Unmarshal([]byte(ln), &x) != nil {
			jsonlOK = false
			break
		}
		count++
	}
	if jsonlOK && count > 1 {
		return Summary{Type: "jsonl", Detail: fmt.Sprintf("%d records", count), Preview: preview(trimmed)}
	}

	nLines := strings.Count(string(content), "\n") + 1
	return Summary{Type: "text", Detail: fmt.Sprintf("%d lines, %d chars", nLines, len(content)), Preview: preview(trimmed)}
}

// jsonObjectKeys lists keys (sorted for determinism), annotating array-valued
// keys with their length, e.g. "meta, page, results(3)".
func jsonObjectKeys(m map[string]interface{}) string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, k := range keys {
		if arr, ok := m[k].([]interface{}); ok {
			parts = append(parts, fmt.Sprintf("%s(%d)", k, len(arr)))
		} else {
			parts = append(parts, k)
		}
	}
	return strings.Join(parts, ", ")
}

func preview(s string) string {
	const max = 160
	s = strings.ReplaceAll(s, "\n", " ")
	if len(s) > max {
		return s[:max] + " …"
	}
	return s
}

// RenderStub builds the transcript stub for stored content.
func RenderStub(hash string, origTok int, sum Summary) string {
	return fmt.Sprintf("⟦crumb %s ~%s tok type=%s %s⟧\npreview: %s\n↳ retrieve(%q) for full content",
		hash, humanTokens(origTok), sum.Type, sum.Detail, sum.Preview, hash)
}

// FilterContent returns the parts of content matching query. JSON arrays are
// filtered element-wise; text/jsonl/objects are grepped line-wise. An empty
// query returns the full content.
func FilterContent(content []byte, sum Summary, query string) string {
	if query == "" {
		return string(content)
	}
	if sum.Type == "json" {
		var arr []json.RawMessage
		if json.Unmarshal(content, &arr) == nil {
			var matched []string
			for _, el := range arr {
				if strings.Contains(string(el), query) {
					matched = append(matched, string(el))
				}
			}
			return fmt.Sprintf("[%s]\n(%d of %d elements matched %q)",
				strings.Join(matched, ", "), len(matched), len(arr), query)
		}
		// not an array (object/scalar) — fall through to line grep
	}
	var out []string
	for _, ln := range strings.Split(string(content), "\n") {
		if strings.Contains(ln, query) {
			out = append(out, ln)
		}
	}
	return fmt.Sprintf("%s\n(%d lines matched %q)", strings.Join(out, "\n"), len(out), query)
}
