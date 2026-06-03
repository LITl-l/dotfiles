package main

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

// version is overridden at build time via -ldflags "-X main.version=…".
var version = "dev"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	switch os.Args[1] {
	case "mcp", "serve":
		runMCP()
	case "compress":
		runCompress(os.Args[2:])
	case "retrieve":
		runRetrieve(os.Args[2:])
	case "stats":
		runStats(os.Args[2:])
	case "gc":
		runGC(os.Args[2:])
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

func openStore() *Store {
	s, err := NewStore(DefaultDir())
	check(err)
	return s
}

func runMCP() {
	if err := ServeMCP(os.Stdin, os.Stdout, openStore()); err != nil {
		fmt.Fprintln(os.Stderr, "crumb mcp:", err)
		os.Exit(1)
	}
}

func runCompress(args []string) {
	var data []byte
	var err error
	if len(args) == 0 || args[0] == "-" {
		data, err = io.ReadAll(os.Stdin)
	} else {
		data, err = os.ReadFile(args[0])
	}
	check(err)
	out, err := CompressContent(openStore(), data, time.Now().Unix())
	check(err)
	fmt.Println(out)
}

func runRetrieve(args []string) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: crumb retrieve <hash> [--query Q]")
		os.Exit(2)
	}
	hash := args[0]
	query := ""
	for i := 1; i < len(args); i++ {
		if args[i] == "--query" && i+1 < len(args) {
			query = args[i+1]
			i++
		}
	}
	out, err := RetrieveContent(openStore(), hash, query)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Print(out)
	if !strings.HasSuffix(out, "\n") {
		fmt.Println()
	}
}

func runStats(args []string) {
	out, err := StatsText(openStore())
	check(err)
	fmt.Print(out)
}

func runGC(args []string) {
	days := envInt("CRUMB_GC_DAYS", 14)
	maxMB := envInt("CRUMB_GC_MAX_MB", 512)
	all := false
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--days":
			if i+1 < len(args) {
				days = atoiOr(args[i+1], days)
				i++
			}
		case "--max-mb":
			if i+1 < len(args) {
				maxMB = atoiOr(args[i+1], maxMB)
				i++
			}
		case "--all":
			all = true
		}
	}
	store := openStore()
	var res GCResult
	var err error
	if all {
		res, err = store.GC(time.Now(), time.Nanosecond, 0) // evict everything
	} else {
		res, err = store.GC(time.Now(), time.Duration(days)*24*time.Hour, int64(maxMB)*1024*1024)
	}
	check(err)
	fmt.Printf("crumb gc: removed %d blob(s), freed %.2f MB\n", res.Removed, float64(res.FreedBytes)/(1024*1024))
}

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		return atoiOr(v, def)
	}
	return def
}

func atoiOr(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil {
		return n
	}
	return def
}

func check(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "crumb:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `crumb — context store-and-stub

usage:
  crumb mcp                          run the stdio MCP server
  crumb compress [FILE|-]            store content, print the crumb stub
  crumb retrieve <hash> [--query Q]  print stored content (optionally filtered)
  crumb stats                        print savings + recent events
  crumb gc [--days N] [--max-mb M] [--all]   prune old/oversized blobs
  crumb --version | --help

env:
  CRUMB_DIR             store directory (default ~/.local/state/crumb)
  CRUMB_MIN_TOKENS      don't stub content below this (default 50)
  CRUMB_HASH_LEN        short-hash length (default 12)
  CRUMB_GC_DAYS         gc age in days (default 14)
  CRUMB_GC_MAX_MB       gc size cap in MB (default 512)
  CRUMB_PRICE_PER_MTOK  if set, stats shows estimated cost saved
`)
}
