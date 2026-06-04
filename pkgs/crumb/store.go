package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"time"
)

// ErrNotFound is returned when a hash has no stored blob (never stored, or gc'd).
var ErrNotFound = errors.New("crumb: not found (may have been gc'd)")

// Store is a content-addressed blob store with an append-only event log.
type Store struct {
	dir       string
	blobsDir  string
	eventsLog string
	hashLen   int
}

// DefaultDir resolves the store root: $CRUMB_DIR, else $XDG_STATE_HOME/crumb,
// else ~/.local/state/crumb.
func DefaultDir() string {
	if d := os.Getenv("CRUMB_DIR"); d != "" {
		return d
	}
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return filepath.Join(d, "crumb")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "state", "crumb")
}

func hashLenFromEnv() int {
	if v := os.Getenv("CRUMB_HASH_LEN"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 6 && n <= 64 {
			return n
		}
	}
	return 12
}

// NewStore creates the store directories if needed.
func NewStore(dir string) (*Store, error) {
	s := &Store{
		dir:       dir,
		blobsDir:  filepath.Join(dir, "blobs"),
		eventsLog: filepath.Join(dir, "events.jsonl"),
		hashLen:   hashLenFromEnv(),
	}
	if err := os.MkdirAll(s.blobsDir, 0o755); err != nil {
		return nil, err
	}
	return s, nil
}

// Hash returns the canonical short id (truncated sha256 hex) for content.
func (s *Store) Hash(content []byte) string {
	sum := sha256.Sum256(content)
	return hex.EncodeToString(sum[:])[:s.hashLen]
}

func (s *Store) blobPath(hash string) string {
	return filepath.Join(s.blobsDir, hash)
}

// Put stores content (dedup by hash) using an atomic temp-write + rename, and
// returns its hash.
func (s *Store) Put(content []byte) (string, error) {
	hash := s.Hash(content)
	path := s.blobPath(hash)
	if _, err := os.Stat(path); err == nil {
		return hash, nil // already stored
	}
	tmp, err := os.CreateTemp(s.blobsDir, ".tmp-*")
	if err != nil {
		return "", err
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(content); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return "", err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return "", err
	}
	if err := os.Rename(tmpName, path); err != nil {
		os.Remove(tmpName)
		return "", err
	}
	return hash, nil
}

// Get returns stored content for hash, or ErrNotFound.
func (s *Store) Get(hash string) ([]byte, error) {
	data, err := os.ReadFile(s.blobPath(hash))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return data, nil
}

// Event is one row in events.jsonl.
type Event struct {
	TS      int64  `json:"ts"`
	Op      string `json:"op"`
	Hash    string `json:"hash"`
	OrigTok int    `json:"orig_tok"`
	StubTok int    `json:"stub_tok"`
}

// AppendEvent appends one event via O_APPEND (atomic for small writes on POSIX).
func (s *Store) AppendEvent(e Event) error {
	f, err := os.OpenFile(s.eventsLog, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	line, err := json.Marshal(e)
	if err != nil {
		return err
	}
	line = append(line, '\n')
	_, err = f.Write(line)
	return err
}

// Stats aggregates the event log plus on-disk usage.
type Stats struct {
	Compressions int
	UniqueBlobs  int
	OrigTokens   int
	StubTokens   int
	SavedTokens  int
	StoreBytes   int64
	Recent       []Event
}

// ReadStats folds events.jsonl into totals, keeping the last recentN events.
func (s *Store) ReadStats(recentN int) (Stats, error) {
	var st Stats
	f, err := os.Open(s.eventsLog)
	if err != nil {
		if os.IsNotExist(err) {
			st.StoreBytes, st.UniqueBlobs = s.diskUsage()
			return st, nil
		}
		return st, err
	}
	defer f.Close()

	var events []Event
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1024*1024), 64*1024*1024)
	for sc.Scan() {
		var e Event
		if json.Unmarshal(sc.Bytes(), &e) != nil {
			continue // skip a corrupt line rather than fail
		}
		events = append(events, e)
		if e.Op == "compress" {
			st.Compressions++
			st.OrigTokens += e.OrigTok
			st.StubTokens += e.StubTok
		}
	}
	st.SavedTokens = st.OrigTokens - st.StubTokens
	st.StoreBytes, st.UniqueBlobs = s.diskUsage()
	if recentN > 0 && len(events) > recentN {
		st.Recent = events[len(events)-recentN:]
	} else {
		st.Recent = events
	}
	return st, nil
}

func (s *Store) diskUsage() (int64, int) {
	entries, err := os.ReadDir(s.blobsDir)
	if err != nil {
		return 0, 0
	}
	var total int64
	n := 0
	for _, e := range entries {
		if e.IsDir() || e.Name()[0] == '.' {
			continue // skip leftover .tmp-* files
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		total += info.Size()
		n++
	}
	return total, n
}

// GCResult reports what GC removed.
type GCResult struct {
	Removed    int
	FreedBytes int64
}

// GC removes blobs older than maxAge (when >0), then removes the oldest
// remaining blobs until total size is under maxBytes (when >0). now is injected
// so tests are deterministic.
func (s *Store) GC(now time.Time, maxAge time.Duration, maxBytes int64) (GCResult, error) {
	var res GCResult
	entries, err := os.ReadDir(s.blobsDir)
	if err != nil {
		return res, err
	}
	type blob struct {
		path string
		size int64
		mod  time.Time
	}
	var blobs []blob
	for _, e := range entries {
		if e.IsDir() || e.Name()[0] == '.' {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		blobs = append(blobs, blob{s.blobPath(e.Name()), info.Size(), info.ModTime()})
	}

	var remaining []blob
	for _, b := range blobs {
		if maxAge > 0 && now.Sub(b.mod) > maxAge {
			if os.Remove(b.path) == nil {
				res.Removed++
				res.FreedBytes += b.size
			}
			continue
		}
		remaining = append(remaining, b)
	}

	if maxBytes > 0 {
		var total int64
		for _, b := range remaining {
			total += b.size
		}
		if total > maxBytes {
			sort.Slice(remaining, func(i, j int) bool { return remaining[i].mod.Before(remaining[j].mod) })
			for _, b := range remaining {
				if total <= maxBytes {
					break
				}
				if os.Remove(b.path) == nil {
					res.Removed++
					res.FreedBytes += b.size
					total -= b.size
				}
			}
		}
	}
	return res, nil
}
