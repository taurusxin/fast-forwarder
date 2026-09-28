package server

import "net/http"

func (a *App) gostInfo(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, http.MethodGet) {
		return
	}
	version, binary, config, running, lastError := a.manager.Info()
	reply(w, 200, map[string]any{
		"version": version, "binary": binary, "config": config,
		"running": running, "error": lastError,
	})
}
