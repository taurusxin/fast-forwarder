package storage

import (
	"database/sql"
	"errors"
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
		"CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)",
	} {
		if _, err = db.Exec(q); err != nil {
			_ = db.Close()
			return nil, err
		}
	}
	return db, nil
}
func EnsureListen(db *sql.DB, initial string) (string, error) {
	var saved string
	err := db.QueryRow("SELECT value FROM settings WHERE key='web_listen'").Scan(&saved)
	if errors.Is(err, sql.ErrNoRows) {
		saved = initial
		_, err = db.Exec("INSERT INTO settings(key,value) VALUES('web_listen',?)", saved)
	}
	return saved, err
}
func SavedListen(dir string) string {
	db, err := sql.Open("sqlite", filepath.Join(dir, "fast-forwarder.db"))
	if err != nil {
		return ""
	}
	defer db.Close()
	var value string
	_ = db.QueryRow("SELECT value FROM settings WHERE key='web_listen'").Scan(&value)
	return value
}
