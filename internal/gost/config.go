package gost

import (
	"encoding/json"
	"fmt"
	"github.com/taurusxin/fast-forwarder/internal/model"
	"net"
	"os"
	"path/filepath"
	"strconv"
)

func ConfigFor(rules []model.Rule) ([]byte, error) {
	cfg := map[string]any{"services": []any{}}
	services := []any{}
	chains := []any{}
	for _, r := range rules {
		if !r.Enabled {
			continue
		}
		handler := map[string]any{"type": r.Type}
		if len(r.Hops) > 0 {
			chainName := "chain-" + r.ID
			handler["chain"] = chainName
			hops := []any{}
			for i, h := range r.Hops {
				connector := map[string]any{"type": h.Type}
				if h.Username != "" {
					connector["auth"] = map[string]string{"username": h.Username, "password": h.Password}
				}
				hops = append(hops, map[string]any{"name": fmt.Sprintf("hop-%d", i), "nodes": []any{map[string]any{"name": fmt.Sprintf("node-%d", i), "addr": h.Address, "connector": connector, "dialer": map[string]string{"type": "tcp"}}}})
			}
			chains = append(chains, map[string]any{"name": chainName, "hops": hops})
		}
		if r.Username != "" {
			handler["auth"] = map[string]string{"username": r.Username, "password": r.Password}
		}
		service := map[string]any{"name": "rule-" + r.ID, "addr": net.JoinHostPort(r.ListenHost, strconv.Itoa(r.ListenPort)), "handler": handler, "listener": map[string]string{"type": "tcp"}}
		if r.Type == "tcp" {
			service["forwarder"] = map[string]any{"nodes": []any{map[string]string{"name": "target", "addr": r.Target}}}
		}
		services = append(services, service)
	}
	cfg["services"] = services
	if len(chains) > 0 {
		cfg["chains"] = chains
	}
	return json.MarshalIndent(cfg, "", "  ")
}
func WriteConfig(dir string, rules []model.Rule) error {
	b, e := ConfigFor(rules)
	if e != nil {
		return e
	}
	return AtomicWrite(filepath.Join(dir, "gost.json"), b)
}
func AtomicWrite(path string, b []byte) error {
	f, e := os.CreateTemp(filepath.Dir(path), ".gost-*")
	if e != nil {
		return e
	}
	defer os.Remove(f.Name())
	if e = f.Chmod(0600); e != nil {
		_ = f.Close()
		return e
	}
	if _, e = f.Write(b); e != nil {
		_ = f.Close()
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	return os.Rename(f.Name(), path)
}
