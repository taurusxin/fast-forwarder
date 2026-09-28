package storage

import (
	"database/sql"
	_ "modernc.org/sqlite"
	"path/filepath"
)

func Open(dir string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", filepath.Join(dir, "fast-forwarder.db"))
	if err != nil {
		return nil, err
	}
	db.SetMaxOpenConns(1)
	for _, q := range []string{
		"PRAGMA journal_mode=WAL",
		"CREATE TABLE IF NOT EXISTS admins(username TEXT PRIMARY KEY,password_hash TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,expires_at INTEGER NOT NULL)",
		"CREATE TABLE IF NOT EXISTS rules(id TEXT PRIMARY KEY,body TEXT NOT NULL)",
		"DROP TABLE IF EXISTS settings",
	} {
		if _, err = db.Exec(q); err != nil {
			_ = db.Close()
			return nil, err
		}
	}
	return db, nil
}
