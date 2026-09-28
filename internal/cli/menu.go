package cli

import (
	"fmt"
	"github.com/taurusxin/fast-forwarder/internal/storage"
	"os"
	"os/exec"
	"path/filepath"
)

func Run(dir string) {
	for {
		fmt.Println("fast-forwarder")
		fmt.Println("1. 查看配置")
		fmt.Println("2. 查看状态")
		fmt.Println("3. 重启服务")
		fmt.Println("4. 安装或更新")
		fmt.Println("5. 卸载")
		fmt.Println("0. 退出")
		var v string
		fmt.Print("请选择: ")
		if _, err := fmt.Scanln(&v); err != nil {
			return
		}
		switch v {
		case "0":
			return
		case "1":
			fmt.Println("管理地址:", storage.SavedListen(dir))
			b, err := os.ReadFile(filepath.Join(dir, "gost.json"))
			if err != nil {
				fmt.Println(err)
			} else {
				fmt.Println(string(b))
			}
		case "2":
			out, _ := exec.Command("sh", "-c", "systemctl status fast-forwarder --no-pager 2>/dev/null || rc-service fast-forwarder status").CombinedOutput()
			fmt.Println(string(out))
		case "3":
			out, err := exec.Command("sh", "-c", "systemctl restart fast-forwarder 2>/dev/null || rc-service fast-forwarder restart").CombinedOutput()
			fmt.Println(string(out), err)
		case "4", "5":
			action := "install"
			if v == "5" {
				action = "uninstall"
			}
			c := exec.Command("sh", "/usr/local/share/fast-forwarder/install.sh", action)
			c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
			if err := c.Run(); err != nil {
				fmt.Println(err)
			}
			if v == "5" {
				return
			}
		default:
			fmt.Println("无效选项")
		}
	}
}
