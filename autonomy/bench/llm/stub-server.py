#!/usr/bin/env python3
"""Stub OpenAI-compatible endpoint for the llm selftest.

usage: stub-server.py --port N --model ID --scenario FILE --log FILE

The scenario is a JSON list of turns. The reply to a chat request is the turn indexed
by the number of assistant messages already in that request, so the stub is stateless
and the agent's own history drives it. A turn is {"content": "..."} or
{"tool_calls": [{"name": "...", "arguments": "<raw string, sent verbatim>"}]}. Past
the end, the last turn repeats. Each chat request body is appended to --log as one
JSON line, so the selftest can read the tool results the agent sent back.
"""
import argparse
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--model", required=True)
    p.add_argument("--scenario", required=True)
    p.add_argument("--log", required=True)
    return p.parse_args()


ARGS = parse_args()
with open(ARGS.scenario, encoding="utf-8") as fh:
    SCENARIO = json.load(fh)


def pick_turn(body):
    n = sum(1 for m in body.get("messages", []) if m.get("role") == "assistant")
    return n, SCENARIO[min(n, len(SCENARIO) - 1)]


def tool_calls(turn, n):
    return [
        {
            "index": i,
            "id": f"call_{n}_{i}",
            "type": "function",
            "function": {"name": c["name"], "arguments": c["arguments"]},
        }
        for i, c in enumerate(turn.get("tool_calls", []))
    ]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_):
        pass

    def send_json(self, code, obj):
        data = (json.dumps(obj) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
        elif self.path in ("/v1/models", "/models"):
            self.send_json(200, {"object": "list", "data": [{"id": ARGS.model, "object": "model"}]})
        else:
            self.send_json(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        if not self.path.endswith("/chat/completions"):
            self.send_json(404, {"error": "not found"})
            return
        with open(ARGS.log, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(body) + "\n")
        n, turn = pick_turn(body)
        calls = tool_calls(turn, n)
        finish = "tool_calls" if calls else "stop"
        content = turn.get("content")
        usage = {"prompt_tokens": 10, "completion_tokens": 5, "total_tokens": 15}
        base = {"id": f"chatcmpl-{n}", "created": int(time.time()), "model": ARGS.model}
        if not body.get("stream"):
            msg = {"role": "assistant", "content": content}
            if calls:
                msg["tool_calls"] = [{k: v for k, v in c.items() if k != "index"} for c in calls]
            self.send_json(200, {**base, "object": "chat.completion", "usage": usage,
                                 "choices": [{"index": 0, "message": msg, "finish_reason": finish}]})
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self.end_headers()
        delta = {"role": "assistant", "content": content}
        if calls:
            delta["tool_calls"] = calls
        chunks = [
            {"choices": [{"index": 0, "delta": delta, "finish_reason": None}]},
            {"choices": [{"index": 0, "delta": {}, "finish_reason": finish}]},
            {"choices": [], "usage": usage},
        ]
        for c in chunks:
            self.wfile.write(f"data: {json.dumps({**base, 'object': 'chat.completion.chunk', **c})}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()
        self.close_connection = True


def main():
    server = ThreadingHTTPServer(("127.0.0.1", ARGS.port), Handler)
    print(f"stub listening on 127.0.0.1:{ARGS.port}", file=sys.stderr, flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
