package server

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/taurusxin/fast-forwarder/internal/gost"
	"github.com/taurusxin/fast-forwarder/internal/model"
	"github.com/taurusxin/fast-forwarder/internal/storage"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func (a *App) rules(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		items, err := storage.ReadRules(a.db)
		if err != nil {
			bad(w, 500, "读取规则失败")
			return
		}
		reply(w, 200, items)
		return
	}
	if !only(w, r, "POST") {
		return
	}
	var v model.Rule
	if parse(r, &v) != nil {
		bad(w, 400, "请求格式错误")
		return
	}
	v.ID = randomID()
	if err := a.change(v, false, false); err != nil {
		bad(w, 400, err.Error())
		return
	}
	reply(w, 201, v)
}
func (a *App) rule(w http.ResponseWriter, r *http.Request) {
	id := strings.TrimPrefix(r.URL.Path, "/api/rules/")
	if id == "" || strings.Contains(id, "/") {
		bad(w, 404, "规则不存在")
		return
	}
	if r.Method == "PUT" {
		var v model.Rule
		if parse(r, &v) != nil {
			bad(w, 400, "请求格式错误")
			return
		}
		v.ID = id
		if err := a.change(v, true, false); err != nil {
			bad(w, 400, err.Error())
			return
		}
		reply(w, 200, v)
		return
	}
	if r.Method == "DELETE" {
		if err := a.change(model.Rule{ID: id}, true, true); err != nil {
			bad(w, 400, err.Error())
			return
		}
		reply(w, 200, map[string]bool{"ok": true})
		return
	}
	bad(w, 405, "不支持的请求方法")
}
func randomID() string { b := make([]byte, 12); _, _ = rand.Read(b); return hex.EncodeToString(b) }
func address(s string) bool {
	h, p, e := net.SplitHostPort(s)
	if e != nil || h == "" {
		return false
	}
	n, e := strconv.Atoi(p)
	return e == nil && n > 0 && n < 65536
}
func valid(v model.Rule) error {
	if strings.TrimSpace(v.Name) == "" {
		return errors.New("请输入名称")
	}
	if v.Type != "tcp" && v.Type != "http" && v.Type != "socks5" {
		return errors.New("不支持的类型")
	}
	if net.ParseIP(v.ListenHost) == nil {
		return errors.New("监听地址必须是 IP")
	}
	if v.ListenPort < 1 || v.ListenPort > 65535 {
		return errors.New("监听端口无效")
	}
	if v.Type == "tcp" && !address(v.Target) {
		return errors.New("目标地址须为 主机:端口")
	}
	if (v.Username == "") != (v.Password == "") {
		return errors.New("代理账号和密码需同时填写")
	}
	for _, h := range v.Hops {
		if h.Type != "http" && h.Type != "socks5" {
			return errors.New("链节点仅支持 HTTP 或 SOCKS5")
		}
		if !address(h.Address) {
			return errors.New("链节点地址无效")
		}
		if (h.Username == "") != (h.Password == "") {
			return errors.New("链节点账号和密码需同时填写")
		}
	}
	return nil
}
func portFree(host string, port int) error {
	l, e := net.Listen("tcp", net.JoinHostPort(host, strconv.Itoa(port)))
	if e != nil {
		return fmt.Errorf("端口不可用: %w", e)
	}
	return l.Close()
}
func (a *App) checkPort(w http.ResponseWriter, r *http.Request) {
	if !only(w, r, "GET") {
		return
	}
	host := r.URL.Query().Get("host")
	port, _ := strconv.Atoi(r.URL.Query().Get("port"))
	if net.ParseIP(host) == nil || port < 1 || port > 65535 {
		bad(w, 400, "地址或端口无效")
		return
	}
	if err := portFree(host, port); err != nil {
		bad(w, 409, err.Error())
		return
	}
	reply(w, 200, map[string]bool{"available": true})
}
func sameListen(old []model.Rule, v model.Rule) bool {
	for _, x := range old {
		if x.ID == v.ID {
			return x.Enabled && x.ListenHost == v.ListenHost && x.ListenPort == v.ListenPort
		}
	}
	return false
}
func (a *App) change(v model.Rule, update, remove bool) error {
	a.mu.Lock()
	defer a.mu.Unlock()
	if !remove {
		if err := valid(v); err != nil {
			return err
		}
	}
	old, err := storage.ReadRules(a.db)
	if err != nil {
		return err
	}
	found := false
	next := make([]model.Rule, 0, len(old)+1)
	for _, x := range old {
		if x.ID == v.ID {
			found = true
			if !remove {
				next = append(next, v)
			}
			continue
		}
		if !remove && v.Enabled && x.Enabled && v.ListenPort == x.ListenPort && (v.ListenHost == x.ListenHost || v.ListenHost == "0.0.0.0" || x.ListenHost == "0.0.0.0" || v.ListenHost == "::" || x.ListenHost == "::") {
			return errors.New("监听端口与已有规则冲突")
		}
		next = append(next, x)
	}
	if update != found {
		return errors.New("规则不存在或已存在")
	}
	if !update {
		next = append(next, v)
	}
	if !remove && v.Enabled && (!update || !sameListen(old, v)) {
		if err := portFree(v.ListenHost, v.ListenPort); err != nil {
			return err
		}
	}
	prev, err := os.ReadFile(filepath.Join(a.dir, "gost.json"))
	if err != nil {
		return err
	}
	if err = gost.WriteConfig(a.dir, next); err != nil {
		return err
	}
	if err = a.manager.Restart(); err != nil {
		_ = gost.AtomicWrite(filepath.Join(a.dir, "gost.json"), prev)
		_ = a.manager.Restart()
		return fmt.Errorf("GOST 重启失败: %w", err)
	}
	if remove {
		_, err = a.db.Exec("DELETE FROM rules WHERE id=?", v.ID)
	} else {
		body, _ := json.Marshal(v)
		if update {
			_, err = a.db.Exec("UPDATE rules SET body=? WHERE id=?", string(body), v.ID)
		} else {
			_, err = a.db.Exec("INSERT INTO rules(id,body) VALUES(?,?)", v.ID, string(body))
		}
	}
	if err != nil {
		_ = gost.AtomicWrite(filepath.Join(a.dir, "gost.json"), prev)
		_ = a.manager.Restart()
	}
	return err
}
