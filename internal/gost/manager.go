package gost

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

type Manager struct {
	binary, config string
	mu             sync.Mutex
	cmd            *exec.Cmd
	done           chan error
	lastError      string
}

func NewManager(binary, config string) *Manager { return &Manager{binary: binary, config: config} }
func (m *Manager) Info() (version, binary, config string, running bool, lastError string) {
	running, lastError = m.Status()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, m.binary, "-V").CombinedOutput()
	if err == nil {
		version = strings.TrimSpace(string(output))
	}
	if version == "" {
		version = "未知"
	}
	return version, m.binary, m.config, running, lastError
}
func (m *Manager) Status() (bool, string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.cmd != nil, m.lastError
}
func (m *Manager) Start() error { m.mu.Lock(); defer m.mu.Unlock(); return m.startLocked() }
func (m *Manager) Restart() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.stopLocked()
	return m.startLocked()
}
func (m *Manager) Stop() { m.mu.Lock(); defer m.mu.Unlock(); m.stopLocked() }
func (m *Manager) startLocked() error {
	path, err := exec.LookPath(m.binary)
	if err != nil {
		m.lastError = err.Error()
		return err
	}
	cmd := exec.Command(path, "-C", m.config)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	if err = cmd.Start(); err != nil {
		m.lastError = err.Error()
		return err
	}
	done := make(chan error, 1)
	m.cmd, m.done = cmd, done
	go func() {
		waitErr := cmd.Wait()
		done <- waitErr
		m.mu.Lock()
		if m.cmd == cmd {
			m.cmd, m.done = nil, nil
			m.lastError = fmt.Sprintf("GOST 已退出: %v", waitErr)
		}
		m.mu.Unlock()
	}()
	select {
	case err = <-done:
		if err == nil {
			err = errors.New("GOST 提前退出")
		}
		m.cmd, m.done = nil, nil
		m.lastError = err.Error()
		return err
	case <-time.After(300 * time.Millisecond):
		m.lastError = ""
		return nil
	}
}
func (m *Manager) stopLocked() {
	if m.cmd == nil {
		return
	}
	cmd, done := m.cmd, m.done
	m.cmd, m.done = nil, nil
	_ = cmd.Process.Kill()
	<-done
}
