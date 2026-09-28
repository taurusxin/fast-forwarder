package main

import (
	"embed"
	"flag"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/taurusxin/fast-forwarder/internal/cli"
	"github.com/taurusxin/fast-forwarder/internal/gost"
	"github.com/taurusxin/fast-forwarder/internal/server"
	"github.com/taurusxin/fast-forwarder/internal/storage"
)

//go:embed web/dist/*
var static embed.FS

func main() {
	dir := flag.String("data-dir", "/var/lib/fast-forwarder", "data directory")
	listen := flag.String("listen", "0.0.0.0:8080", "web listen address")
	gostPath := flag.String("gost", "gost", "gost binary")
	flag.Parse()
	if len(flag.Args()) == 0 || flag.Arg(0) != "serve" {
		cli.Run(*dir)
		return
	}
	if err := os.MkdirAll(*dir, 0700); err != nil {
		log.Fatal(err)
	}
	db, err := storage.Open(*dir)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	rules, err := storage.ReadRules(db)
	if err != nil {
		log.Fatal(err)
	}
	if err = gost.WriteConfig(*dir, rules); err != nil {
		log.Fatal(err)
	}
	manager := gost.NewManager(*gostPath, filepath.Join(*dir, "gost.json"))
	if err = manager.Start(); err != nil {
		log.Printf("GOST startup: %v", err)
	}
	defer manager.Stop()
	dist, err := fs.Sub(static, "web/dist")
	if err != nil {
		log.Fatal(err)
	}
	handler := server.New(db, *dir, *listen, manager).Handler(dist)
	web := &http.Server{Addr: *listen, Handler: handler, ReadHeaderTimeout: 5 * time.Second}
	log.Printf("fast-forwarder listening on %s", *listen)
	log.Fatal(web.ListenAndServe())
}
