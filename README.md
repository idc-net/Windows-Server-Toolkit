# 🖥️ Windows Server Toolkit

> 专为 **Windows Server** 设计的 PowerShell 工具集，涵盖 RDP 端口管理与系统更新管控，让服务器更稳定、更安全。

💡 idc.net 用户提示： 如果您是 idc.net 的用户，无需自行操作，请直接登录控制台提交工单，我们的技术团队将协助您完成配置。

**维护方：** [idc.net](http://idc.net) &nbsp;|&nbsp; **GitHub：** [github.com/idc-net](https://github.com/idc-net/) &nbsp;|&nbsp; **协议：** MIT

[🇺🇸 English](#english) | [🇨🇳 中文](#中文)

---

## 中文

### 📦 工具列表

| 文件名 | 适用场景 | 功能 |
|--------|---------|------|
| `modify_rdp_port.ps1` | 所有场景 | 修改 RDP 端口、启用 RDP、强制 NLA、自动更新防火墙规则 |
| `disable_auto_update_desktop.ps1` | Windows Server 当桌面 | 全面封锁自动更新，手动完全掌控 |
| `disable_auto_update_web.ps1` | 网站 / 应用服务器 | 自动下载安全补丁，手动选时间安装，禁止自动重启 |

---

### 🔧 modify_rdp_port.ps1

#### 功能特性

- 🔄 **自定义 RDP 端口** — 告别默认 3389，降低暴力破解风险
- 🛡️ **强制 NLA 认证** — 自动启用网络级别身份验证
- 🔥 **防火墙自动管理** — 清除旧规则并为新端口创建入站规则
- ↩️ **失败自动回滚** — 任意步骤出错，自动恢复原端口
- 🚫 **端口占用检测** — 变更前检查目标端口是否已被占用
- 📋 **操作日志记录** — 写入 `C:\Windows\Logs\rdp_port_change.log`
- ✅ **RDP 自动启用** — 若 RDP 处于禁用状态自动开启

#### 使用方式

以管理员身份打开 PowerShell，直接运行：

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/modify_rdp_port.ps1 | iex
```

#### 执行流程

1. 验证管理员权限
2. 读取当前 RDP 端口
3. 提示输入新端口（1025–65535）
4. 检测新端口是否被占用
5. 更新注册表端口配置
6. 启用 RDP（如已禁用）
7. 强制开启 NLA
8. 删除旧防火墙规则，创建新规则
9. 重启远程桌面服务
10. 显示配置摘要并记录日志

> 第 5–9 步任意失败，自动回滚至原端口。

---

### 🖥️ disable_auto_update_desktop.ps1（桌面服务器版）

适用于 **Windows Server 当桌面使用**的场景，全面封锁自动更新，更新时机完全由你掌控。

#### 功能特性

- 📢 **通知但不自动安装** — 系统仅弹窗提示，不自动下载或安装
- 🚫 **全时段禁止自动重启** — 任何时间均不会自动重启
- 🌐 **断开更新服务器** — 自动检测失效，更新完全由你掌控
- 📦 **禁用交付优化** — 禁止从其他 PC 下载更新
- ⚙️ **禁用 UsoSvc** — 关闭更新调度服务
- 🛡️ **禁用 WaaSMedicSvc** — 尝试禁用自修复服务（视系统版本）
- 📋 **操作日志记录** — 写入 `C:\Windows\Logs\windows_update_control.log`

#### 使用方式

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/disable_auto_update_desktop.ps1 | iex
```

#### 配置策略一览

| 层级 | 措施 | 效果 |
|------|------|------|
| 第1层 | 通知但不自动安装 | 阻止静默下载 |
| 第2层 | 全时段禁止自动重启 | 任何时间均不重启 |
| 第3层 | 断更新服务器地址 | 彻底无法自动检测 |
| 第4层 | 禁用交付优化 | 节省带宽 |
| 第5层 | 禁用 UsoSvc | 从根源切断重启触发 |
| 第6层 | 禁用 WaaSMedicSvc | 防止服务自动恢复 |

> **手动更新建议：** 每月固定选一天低峰期，打开「设置 → Windows 更新 → 检查更新」手动执行。

---

### 🌐 disable_auto_update_web.ps1（网站服务器版）

适用于**对外提供网站或应用服务**的服务器，安全补丁自动下载，安装时机由你决定，绝不自动重启。

#### 功能特性

- 📥 **自动下载安全补丁** — 补丁静默下载，不影响运行
- 📢 **通知安装** — 下载完成后弹窗提示，由你决定何时安装
- 🚫 **全时段禁止自动重启** — 任何时间均不会自动重启
- 📦 **禁用交付优化** — 禁止从其他 PC 下载更新
- ⚙️ **保留 UsoSvc** — 确保安全补丁正常推送
- 📋 **操作日志记录** — 写入 `C:\Windows\Logs\windows_update_control.log`

#### 使用方式

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/disable_auto_update_web.ps1 | iex
```

#### 配置策略一览

| 层级 | 措施 | 效果 |
|------|------|------|
| 第1层 | 自动下载，通知安装 | 补丁及时到位，安装由你掌控 |
| 第2层 | 全时段禁止自动重启 | 任何时间均不重启 |
| 第3层 | 禁用交付优化 | 节省带宽 |
| 第4层 | 保留 UsoSvc | 确保安全补丁正常推送 |

> **安装建议：** 补丁下载完成后系统会弹窗通知，选择业务低峰期手动安装，建议每月至少安装一次安全更新。

---

### 两个版本对比

| 对比项 | 桌面服务器版 | 网站服务器版 |
|--------|------------|------------|
| 自动下载补丁 | ❌ | ✅ |
| 自动安装补丁 | ❌ | ❌ |
| 自动重启 | ❌ 全时段禁止 | ❌ 全时段禁止 |
| 更新服务器 | 断开 | 保持连接 |
| UsoSvc | 禁用 | 保持运行 |
| 适用场景 | 桌面办公、远程桌面 | Web、应用、数据库服务器 |

---

### 📋 运行环境

- Windows Server 2016 / 2019 / 2022 / 2025（或 Windows 10 / 11）
- PowerShell 5.1 及以上版本
- 管理员权限

> ✅ 已在 Server 2016 / 2019 / 2022 上验证。Server 2025 理论兼容，如遇问题欢迎提交 [Issue](https://github.com/idc-net/)。

---

### ⚠️ 重要提示

在运行 `modify_rdp_port.ps1` 之前，请务必确保你拥有**备用访问方式**：服务器控制台 / VNC / KVM / IPMI。

---

### 🤝 参与贡献

欢迎提交 Pull Request！若涉及较大改动，建议先开 Issue 说明你的想法。

1. Fork 本仓库
2. 创建分支（`git checkout -b feature/你的功能`）
3. 提交更改（`git commit -m '添加某功能'`）
4. 推送分支（`git push origin feature/你的功能`）
5. 发起 Pull Request

---

## English

### 📦 Scripts

| File | Use Case | Purpose |
|------|---------|---------|
| `modify_rdp_port.ps1` | All servers | Change RDP port, enable RDP, enforce NLA, update firewall rules |
| `disable_auto_update_desktop.ps1` | Desktop servers | Full update lockdown, manual control only |
| `disable_auto_update_web.ps1` | Web / App servers | Auto-download patches, manual install, no auto-reboot |

---

### 🔧 modify_rdp_port.ps1

#### Usage

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/modify_rdp_port.ps1 | iex
```

---

### 🖥️ disable_auto_update_desktop.ps1 (Desktop Server)

For Windows Server used as a desktop environment. Fully locks down automatic updates.

#### Usage

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/disable_auto_update_desktop.ps1 | iex
```

---

### 🌐 disable_auto_update_web.ps1 (Web Server)

For servers hosting websites or applications. Security patches download automatically, you choose when to install.

#### Usage

```powershell
irm https://raw.githubusercontent.com/idc-net/Windows-Server-Toolkit/main/disable_auto_update_web.ps1 | iex
```

---

### Comparison

| Feature | Desktop Version | Web Version |
|---------|----------------|-------------|
| Auto-download patches | ❌ | ✅ |
| Auto-install patches | ❌ | ❌ |
| Auto-reboot | ❌ Fully disabled | ❌ Fully disabled |
| Update server | Disconnected | Connected |
| UsoSvc | Disabled | Running |
| Use case | Remote desktop / office | Web / App / DB servers |

---

### 📋 Requirements

- Windows Server 2016 / 2019 / 2022 / 2025 (or Windows 10 / 11)
- PowerShell 5.1 or later
- Administrator privileges

---

### 📄 License

MIT © [idc.net](http://idc.net)

---

<p align="center">
  由 <a href="http://idc.net">idc.net</a> 用心维护 &nbsp;|&nbsp;
  Made with ❤️ by <a href="http://idc.net">idc.net</a> &nbsp;|&nbsp;
  <a href="https://github.com/idc-net/">GitHub</a>
</p>
