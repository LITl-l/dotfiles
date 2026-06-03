package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strconv"
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
