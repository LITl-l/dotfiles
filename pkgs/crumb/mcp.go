package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
)

// serverProtocolVersion is used when the client does not request one.
const serverProtocolVersion = "2025-06-18"

type rpcRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  interface{}     `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// ServeMCP runs the newline-delimited JSON-RPC stdio loop until in is exhausted.
// Only JSON responses are written to out; nothing else may touch it.
func ServeMCP(in io.Reader, out io.Writer, store *Store) error {
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 1024*1024), 64*1024*1024)
	enc := json.NewEncoder(out)
	for sc.Scan() {
		line := sc.Bytes()
		if len(bytes.TrimSpace(line)) == 0 {
			continue
		}
		var req rpcRequest
		if json.Unmarshal(line, &req) != nil {
			if err := enc.Encode(rpcResponse{JSONRPC: "2.0", Error: &rpcError{Code: -32700, Message: "parse error"}}); err != nil {
				return err
			}
			continue
		}
		resp, isNotification := handleRPC(&req, store)
		if isNotification {
			continue
		}
		if err := enc.Encode(resp); err != nil {
			return err
		}
	}
	return sc.Err()
}

func handleRPC(req *rpcRequest, store *Store) (rpcResponse, bool) {
	switch req.Method {
	case "initialize":
		pv := serverProtocolVersion
		var p struct {
			ProtocolVersion string `json:"protocolVersion"`
		}
		if json.Unmarshal(req.Params, &p) == nil && p.ProtocolVersion != "" {
			pv = p.ProtocolVersion
		}
		return rpcResponse{
			JSONRPC: "2.0", ID: req.ID,
			Result: map[string]interface{}{
				"protocolVersion": pv,
				"capabilities":    map[string]interface{}{"tools": map[string]interface{}{}},
				"serverInfo":      map[string]interface{}{"name": "crumb", "version": version},
			},
		}, false
	case "notifications/initialized":
		return rpcResponse{}, true
	case "ping":
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Result: map[string]interface{}{}}, false
	case "tools/list":
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Result: map[string]interface{}{"tools": toolDefs()}}, false
	case "tools/call":
		return handleToolCall(req, store), false
	default:
		if req.ID == nil { // any other notification
			return rpcResponse{}, true
		}
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Error: &rpcError{Code: -32601, Message: "method not found: " + req.Method}}, false
	}
}

func handleToolCall(req *rpcRequest, store *Store) rpcResponse {
	var p struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if json.Unmarshal(req.Params, &p) != nil {
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Error: &rpcError{Code: -32602, Message: "invalid params"}}
	}
	text, err := dispatchTool(p.Name, p.Arguments, store)
	if err != nil {
		return rpcResponse{JSONRPC: "2.0", ID: req.ID, Error: &rpcError{Code: -32602, Message: err.Error()}}
	}
	return rpcResponse{JSONRPC: "2.0", ID: req.ID, Result: map[string]interface{}{
		"content": []map[string]interface{}{{"type": "text", "text": text}},
	}}
}

func toolDefs() []map[string]interface{} {
	return []map[string]interface{}{
		{
			"name":        "compress",
			"description": "Store large content out of context and return a short crumb stub (hash + summary). Use on big tool outputs, file contents, logs, or search results; retrieve the original later with the retrieve tool.",
			"inputSchema": map[string]interface{}{
				"type":     "object",
				"required": []string{"content"},
				"properties": map[string]interface{}{
					"content": map[string]interface{}{"type": "string", "description": "The content to stash."},
				},
			},
		},
		{
			"name":        "retrieve",
			"description": "Retrieve previously stored content by its crumb hash. An optional query filters JSON array elements or text lines.",
			"inputSchema": map[string]interface{}{
				"type":     "object",
				"required": []string{"hash"},
				"properties": map[string]interface{}{
					"hash":  map[string]interface{}{"type": "string", "description": "The crumb hash from a compress result."},
					"query": map[string]interface{}{"type": "string", "description": "Optional filter string."},
				},
			},
		},
		{
			"name":        "stats",
			"description": "Show crumb savings for this store: compressions, tokens saved, store size, and recent events.",
			"inputSchema": map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
	}
}
