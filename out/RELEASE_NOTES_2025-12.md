# Android GKI Kernel 5.15 Release Notes
## 版本: android13-5.15-2025-12
## 基于: Linux 5.15.194

---

## 📋 概述

本文档概述了从 **android13-5.15-2025-05** 到 **android13-5.15-2025-12** 之间的主要更新内容。

---

## 🔄 内核版本更新

- **基础内核版本**: Linux 5.15.194
- **Android 版本**: Android 13 (GKI)
- **发布日期**: 2025年12月

---

## 🔒 安全修复

### 关键安全补丁
- **nbd**: 修复 `nbd_genl_connect()` 错误路径中的 UAF (Use-After-Free) 漏洞
- **vsock**: 禁止绑定到 `VMADDR_PORT_ANY`，防止潜在的安全问题
- **crypto/af_alg**: 修复位域赋值问题，防止并发写入
- **crypto/essiv**: 修复解密和就地加密时的 ssize 检查
- **binder**: 修复潜在的 UAF 问题 (`target_{proc,thread}`)
- **net/packet**: 修复 `packet_set_ring()` 和 `packet_notifier()` 中的竞争条件

### 内存安全
- **mm/hugetlb**: 修复删除时 folio 仍被映射的问题
- **mm/memory-failure**: 修复内存去毒时的 VM_BUG_ON_PAGE 问题
- **mm/migrate_device**: 修复迁移设备时不会将待释放的 folio 添加到 LRU 的问题

---

## 📁 文件系统改进

### F2FS 文件系统
- **FROMGIT**: 防止原子文件在提交前被脏化
- **BACKPORT**: 修复 `prepare_compress_overwrite()` 中的潜在死循环
- **UPSTREAM**: 修复 `f2fs_file_open()` 中预分配块的截断问题
- **BACKPORT**: 修复压缩时 `i_blocks` 和 dnode 之间的不一致性
- **FROMGIT**: 添加查找模式挂载选项
- **FROMGIT**: 为特权用户添加保留节点
- **FROMGIT**: 添加系统文件系统条目用于有效查找模式
- **FROMGIT**: 支持禁用线性查找回退

### 其他文件系统
- **fs/proc**: 使用 `__for_each_thread()` 优化 `do_task_stat`
- **btrfs**: 修复树检查器中的 inode ref 大小检查错误
- **ocfs2**: 修复 fiemap 调用中的递归信号量死锁
- **nilfs2**: 修复访问 `/sys/fs/nilfs2/features/*` 时的 CFI 失败

---

## 🌐 网络子系统

### 网络协议栈
- **net/bridge**: 更新 Unisoc 白名单，添加 12 个函数符号
  - `br_multicast_has_querier_adjacent`
  - `br_multicast_has_querier_anywhere`
  - `br_multicast_has_router_adjacent`
  - `br_multicast_list_adjacent`
  - `crc32c`
  - `dev_get_iflink`
  - `ip_mc_check_igmp`
  - `ipv6_mc_check_mld`
  - `netdev_master_upper_dev_get_rcu`
  - `netif_rx_any_context`
  - `skb_prepare_seq_read`
  - `skb_seq_read`

### MPTCP (多路径 TCP)
- 修复 `sync_socket_options` 传播 `SOCK_KEEPOPEN`
- 修复在接收 SYN 时设置 `remote_deny_join_id0`
- 改进子流关闭传播

### 网络驱动
- **net/qede**: 使用指定初始化器初始化 `qede_ll_ops`
- **net/hsr**: 添加 VLAN CTAG 过滤支持
- **net/hsr**: 添加从设备 MC 过滤支持
- **net/hsr**: 在卸载模式下禁用混杂模式

### 其他网络修复
- **af_unix**: 修复不留下连续消耗的 OOB skbs
- **tcp_bpf**: 修复 `tcp_bpf_send_verdict()` 分配失败时调用 `sk_msg_free()`
- **tcp**: 在 `tcp_disconnect()` 中清除 `tcp_sk(sk)->fastopen_rsk`

---

## 🎵 音频子系统 (ASoC)

### ASoC 核心改进
- **UPSTREAM**: 从 kcontrol 宏中移除 `platform_max` 设置
- **UPSTREAM**: 在读取状态前检查负值
- **UPSTREAM**: 澄清 `snd_soc_info_volsw_sx()`
- **UPSTREAM**: 读取状态时不修改驱动的 `platform_max`

### USB 音频
- **ALSA/usb-audio**: 添加 Sony DualSense PS5 混音器 quirks
- **ALSA/usb-audio**: 修复 CONFIG_INPUT=n 时的构建问题
- **ALSA/usb-audio**: 改进混音器 quirks 代码

---

## 🖥️ 图形和显示

### DRM 驱动
- **drm/i915/backlight**: 当 scale() 发现无效参数时立即返回
- **drm/gma500**: 修复 HDMI 拆卸时的空指针解引用
- **drm/amd**: 修复 fence 清理时的内存泄漏
- **drm/bridge**: 修复多个桥接器驱动的问题
  - `analogix_dp_core`: 改进错误处理
  - `anx7625`: 修复早期 IRQ 时的空指针解引用
  - `cdns-mhdp8546`: 修复错误路径中的互斥锁解锁

### 帧缓冲
- **fbcon**: 修复字体分配中的 OOB 访问
- **fbcon**: 修复 `fbcon_do_set_font` 中的整数溢出

---

## 🔧 驱动更新

### 存储驱动
- **ata**: 多个 ATA 驱动改进和修复
- **block**: 改进块设备设置和配置

### 网络设备
- **i40e**: 多个验证和边界检查修复
  - 添加 `ring_len` 参数验证
  - 修复队列映射中的 idx 验证
  - 修复 VF 状态验证
  - 增加 XL710 的最大描述符数

### 其他驱动
- **can**: 多个 CAN 驱动修复，包括 MTU 处理和缓冲区溢出防护
- **phy**: 修复多个 PHY 驱动在解绑时的设备泄漏
- **serial**: 改进串口驱动稳定性

---

## 🏗️ Android GKI 特定更新

### GKI 符号列表更新
- **Amlogic**: 更新符号列表
- **QCOM**: 添加符号到符号列表
- **Unisoc**: 更新白名单，添加 12 个函数符号
- **Sunxi**: 更新符号列表
- **Oplus**: 更新符号列表
- **PointMobile**: 更新符号列表
- **Honor**: 更新符号列表
- **v2l**: 更新 GKI 符号列表条目

### Vendor Hooks
- **mm**: 添加多个内存管理相关的 vendor hooks
  - `pagecache_get_page()` 中的 hook
  - 文件 folio 回收的 hooks
  - 调整内存回收的 hooks
  - 激活/停用 folios 的 hook
  - 将页面添加到特定 memcg 的 hook
- **sched**: 添加调度相关的 vendor hooks
  - `reweight_entity` 中的 hooks
  - CPU cgroup 子系统中的 hooks
  - 延迟抢占的 hook
- **rcu**: 允许 hooks 进入 RCU stall 警告
- **workingset**: 添加记录 workingset refault 计数的 hook

### 内存管理改进
- **mm**: 导出 `isolate_folio` 和 `reclaim_pages`
- **mm**: 导出 `isolate_page` 函数
- **mm**: 添加 memfd-ashmem-shim 层
- **mm**: 使用 memfd-ashmem-shim ioctl 处理器
- **mm**: 导出 `css_task_iter_start()`

### 其他 Android 特定功能
- **cpufreq/schedutil**: 添加上/下频率转换速率限制
- **bpf**: 如果日志已满，不加载失败
- **binder**: 修复最小节点优先级比较
- **ashmem**: 添加 `shmem_set_file` 到 `mm/shmem.c`
- **ashmem**: 导出 `is_ashmem_file`

---

## 🛠️ 构建系统改进

### 构建脚本
- **build_gki.sh**: 增强构建脚本，改进产物生成和错误处理
- **repack_boot.sh**: 更新重新打包脚本
- **KernelSU**: 移除 KernelSU 子模块，更新构建脚本用于温度监控
- **AnyKernel3**: 添加 GKI 构建工作流，支持 KernelSU 和 AnyKernel3 打包

### 配置更新
- **gki_defconfig**: 启用 schedhorizon
- **gki_defconfig**: 使用 fq_codel 作为默认值
- **gki_defconfig**: 启用 CONFIG_MEMFD_ASHMEM_SHIM
- **gki_defconfig**: 禁用 CONFIG_DRM_MESON（ARM 目标）
- **defconfig**: 禁用未处理中断检测

### 编译器优化
- 启用 -O3 优化
- 启用 wakelock blocker
- 启用 wq_power_efficient

---

## 🔬 BPF 子系统

### BPF 功能
- **BACKPORT**: 添加 dmabuf 迭代器支持
- **BACKPORT**: 允许堆栈大小 <= 512 的程序回退到解释器
- **bpf**: 拒绝 PREEMPT_RT 的 `bpf_timer`
- **bpf**: 改进验证器

---

## ⚡ 性能优化

### CPU 调度
- **cpuidle/menu**: 恢复 "避免丢弃有用信息" 的更改
- **cpufreq**: 在子系统之前初始化基于 cpufreq 的不变性
- **sched**: 多个调度器改进

### 内存管理
- **mm/vmalloc**: 添加 `__GFP_NOFAIL` 支持
- **mm/vmalloc**: 为 vmalloc 分配 GFP_NO{FS,IO}
- **mm/vmalloc**: 更明确地说明支持的 gfp 标志
- **mm/kvmalloc**: 允许 !GFP_KERNEL 分配

---

## 🐛 Bug 修复

### 关键修复
- **nbd**: 修复 `nbd_genl_connect()` 错误路径中的 UAF
- **comedi**: 修复多个 comedi 驱动的问题
- **dma-buf**: 重命名 debugfs 符号
- **dma-resv**: 改进 dma-resv 实现
- **PCI/ASPM**: 修复 L1SS 保存

### 驱动修复
- **watchdog**: 修复多个看门狗驱动
- **hwmon**: 改进硬件监控驱动
- **i2c**: 修复多个 I2C 驱动问题
- **spi**: 改进 SPI 驱动稳定性

---

## 📚 文档更新

- 更新 ABI 测试文档
- 更新设备树绑定文档
- 更新网络文档
- 添加新的硬件漏洞文档

---

## 🔄 上游合并

### 主要上游更新
- 合并 Linux 5.15.194
- 合并多个 LTS 补丁
- 从上游 backport 多个安全修复

### 上游修复统计
- **UPSTREAM**: 超过 100 个上游修复
- **BACKPORT**: 多个重要功能 backport
- **FROMGIT**: 从上游 git 树获取的最新修复

---

## 📊 变更统计

根据 git 统计，本次更新涉及：
- **1405 个文件**被修改
- **22344 行**代码添加
- **11867 行**代码删除

---

## 🎯 主要特性

1. **安全性增强**: 多个关键安全漏洞修复
2. **文件系统改进**: F2FS 和其他文件系统的重大改进
3. **网络优化**: MPTCP、网络驱动和协议栈改进
4. **GKI 支持**: 扩展的符号列表和 vendor hooks
5. **构建系统**: 改进的构建脚本和工具链
6. **性能优化**: CPU 调度和内存管理优化

---

## 📝 注意事项

- 本次更新包含大量安全修复，建议所有用户尽快升级
- GKI 符号列表已更新，可能需要重新编译依赖的内核模块
- 某些配置选项已更改，请检查您的内核配置
- 建议在升级前备份重要数据

---

## 🔗 相关链接

- Android GKI 文档
- Linux 5.15.194 发布说明
- Android 13 文档

---

## 👥 贡献者

感谢所有为本次发布做出贡献的开发者和维护者。

---

**发布日期**: 2025年12月  
**维护者**: Android Kernel Team  
**许可证**: GPL-2.0

