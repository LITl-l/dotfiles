package main

import (
	"fmt"
	"os"
)

// version is overridden at build time via -ldflags "-X main.version=…".
var version = "dev"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	switch os.Args[1] {
	case "--version", "-v", "version":
		fmt.Println("crumb", version)
	case "--help", "-h", "help":
		usage()
	default:
		fmt.Fprintln(os.Stderr, "unknown command:", os.Args[1])
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `crumb — context store-and-stub

usage:
  crumb mcp                          run the stdio MCP server
  crumb compress [FILE|-]            store content, print the crumb stub
  crumb retrieve <hash> [--query Q]  print stored content (optionally filtered)
  crumb stats [--json]               print savings + recent events
  crumb gc [--days N] [--max-mb M] [--all]   prune old/oversized blobs
  crumb --version | --help
`)
}
