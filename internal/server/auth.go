package server

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"golang.org/x/crypto/bcrypt"
	"net/http"
	"time"
)

func (a *App) initialized() bool {
	var n int
	_ = a.db.QueryRow("SELECT COUNT(*) FROM admins").Scan(&n)
	return n > 0
}
func (a *App) status(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, "GET") {
		return
	}
	running, e := a.manager.Status()
	reply(w, 200, map[string]any{"initialized": a.initialized(), "gostRunning": running, "gostError": e, "listen": a.listen})
}
func (a *App) setup(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, "POST") {
		return
	}
	var v struct{ Username, Password string }
	if parse(r, &v) != nil {
		bad(w, 400, "请求格式错误")
		return
	}
	if len(v.Username) < 3 || len(v.Password) < 12 {
		bad(w, 400, "用户名至少 3 位，密码至少 12 位")
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(v.Password), bcrypt.DefaultCost)
	if err != nil {
		bad(w, 500, "密码处理失败")
		return
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.initialized() {
		bad(w, 409, "管理员已创建")
		return
	}
	if _, err = a.db.Exec("INSERT INTO admins(username,password_hash) VALUES(?,?)", v.Username, string(hash)); err != nil {
		bad(w, 500, "创建失败")
		return
	}
	a.newSession(w)
}
func (a *App) login(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, "POST") {
		return
	}
	var v struct{ Username, Password string }
	if parse(r, &v) != nil {
		bad(w, 400, "请求格式错误")
		return
	}
	var hash string
	err := a.db.QueryRow("SELECT password_hash FROM admins WHERE username=?", v.Username).Scan(&hash)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte(v.Password)) != nil {
		bad(w, 401, "用户名或密码错误")
		return
	}
	a.newSession(w)
}
func hashToken(s string) string { h := sha256.Sum256([]byte(s)); return hex.EncodeToString(h[:]) }
func (a *App) newSession(w http.ResponseWriter) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		bad(w, 500, "会话创建失败")
		return
	}
	token := hex.EncodeToString(b)
	end := time.Now().Add(24 * time.Hour)
	if _, err := a.db.Exec("INSERT INTO sessions(token_hash,expires_at) VALUES(?,?)", hashToken(token), end.Unix()); err != nil {
		bad(w, 500, "会话保存失败")
		return
	}
	http.SetCookie(w, &http.Cookie{Name: "ff_session", Value: token, Path: "/", HttpOnly: true, SameSite: http.SameSiteStrictMode, Expires: end})
	reply(w, 200, map[string]bool{"ok": true})
}
func (a *App) protected(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie("ff_session")
		if err != nil {
			bad(w, 401, "请先登录")
			return
		}
		var expiry int64
		err = a.db.QueryRow("SELECT expires_at FROM sessions WHERE token_hash=?", hashToken(c.Value)).Scan(&expiry)
		if err != nil || expiry < time.Now().Unix() {
			bad(w, 401, "登录已过期")
			return
		}
		if r.Method != "GET" && r.Header.Get("Origin") != "" {
			origin := r.Header.Get("Origin")
			if origin != "http://"+r.Host && origin != "https://"+r.Host {
				bad(w, 403, "来源校验失败")
				return
			}
		}
		next(w, r)
	}
}
func (a *App) logout(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, "POST") {
		return
	}
	c, _ := r.Cookie("ff_session")
	if c != nil {
		_, _ = a.db.Exec("DELETE FROM sessions WHERE token_hash=?", hashToken(c.Value))
	}
	http.SetCookie(w, &http.Cookie{Name: "ff_session", Path: "/", MaxAge: -1})
	reply(w, 200, map[string]bool{"ok": true})
}
