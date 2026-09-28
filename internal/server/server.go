package server

import (
	"database/sql"
	"io/fs"
	"net/http"
	"strings"
	"sync"

	"github.com/taurusxin/fast-forwarder/internal/gost"
)

type App struct {
	db          *sql.DB
	dir, listen string
	manager     *gost.Manager
	mu          sync.Mutex
}

func New(db *sql.DB, dir, listen string, manager *gost.Manager) *App {
	return &App{db: db, dir: dir, listen: listen, manager: manager}
}
func (a *App) Handler(dist fs.FS) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/status", a.status)
	mux.HandleFunc("/api/setup", a.setup)
	mux.HandleFunc("/api/login", a.login)
	mux.HandleFunc("/api/logout", a.protected(a.logout))
	mux.HandleFunc("/api/me", a.protected(a.me))
	mux.HandleFunc("/api/gost", a.protected(a.gostInfo))
	mux.HandleFunc("/api/rules", a.protected(a.rules))
	mux.HandleFunc("/api/rules/", a.protected(a.rule))
	mux.HandleFunc("/api/ports/check", a.protected(a.checkPort))
	files := http.FileServer(http.FS(dist))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			if _, err := fs.Stat(dist, strings.TrimPrefix(r.URL.Path, "/")); err != nil {
				r.URL.Path = "/"
			}
		}
		files.ServeHTTP(w, r)
	})
	return mux
}
