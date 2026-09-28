package server

import (
	"net/http"
	"strings"

	"golang.org/x/crypto/bcrypt"
)

func (a *App) me(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		var username string
		if err := a.db.QueryRow("SELECT username FROM admins LIMIT 1").Scan(&username); err != nil {
			bad(w, 500, "读取管理员信息失败")
			return
		}
		reply(w, 200, map[string]string{"username": username})
	case http.MethodPut:
		var input struct{ Username, CurrentPassword, NewPassword string }
		if parse(r, &input) != nil {
			bad(w, 400, "请求格式错误")
			return
		}
		input.Username = strings.TrimSpace(input.Username)
		if len(input.Username) < 3 {
			bad(w, 400, "用户名至少 3 位")
			return
		}
		if input.NewPassword != "" && len(input.NewPassword) < 12 {
			bad(w, 400, "新密码至少 12 位")
			return
		}
		a.mu.Lock()
		defer a.mu.Unlock()
		var oldUsername, oldHash string
		if err := a.db.QueryRow("SELECT username,password_hash FROM admins LIMIT 1").Scan(&oldUsername, &oldHash); err != nil {
			bad(w, 500, "读取管理员信息失败")
			return
		}
		if bcrypt.CompareHashAndPassword([]byte(oldHash), []byte(input.CurrentPassword)) != nil {
			bad(w, 403, "当前密码错误")
			return
		}
		if input.Username == oldUsername && input.NewPassword == "" {
			bad(w, 400, "没有需要保存的修改")
			return
		}
		newHash := oldHash
		if input.NewPassword != "" {
			hash, err := bcrypt.GenerateFromPassword([]byte(input.NewPassword), bcrypt.DefaultCost)
			if err != nil {
				bad(w, 500, "密码处理失败")
				return
			}
			newHash = string(hash)
		}
		tx, err := a.db.Begin()
		if err != nil {
			bad(w, 500, "保存失败")
			return
		}
		if _, err = tx.Exec("UPDATE admins SET username=?,password_hash=? WHERE username=?", input.Username, newHash, oldUsername); err != nil {
			_ = tx.Rollback()
			bad(w, 500, "保存失败")
			return
		}
		if input.NewPassword != "" {
			cookie, _ := r.Cookie("ff_session")
			if cookie != nil {
				_, err = tx.Exec("DELETE FROM sessions WHERE token_hash<>?", hashToken(cookie.Value))
			}
			if err != nil {
				_ = tx.Rollback()
				bad(w, 500, "保存失败")
				return
			}
		}
		if err = tx.Commit(); err != nil {
			bad(w, 500, "保存失败")
			return
		}
		reply(w, 200, map[string]string{"username": input.Username})
	default:
		bad(w, 405, "不支持的请求方法")
	}
}
