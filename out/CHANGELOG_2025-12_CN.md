# Android GKI Kernel 5.15 更新摘要
## 2025-12 版本 (相比 2025-05)

---

## 🎯 核心更新

### 内核版本
- **基础版本**: Linux 5.15.194
- **Android 版本**: android13-5.15-2025-12
- **更新范围**: 2025年5月至2025年12月

---

## 🔒 安全修复 (关键)

1. **nbd**: 修复 UAF 漏洞 (`nbd_genl_connect()`)
2. **vsock**: 禁止绑定 VMADDR_PORT_ANY
3. **crypto/af_alg**: 修复位域赋值和并发写入问题
4. **binder**: 修复潜在的 UAF (`target_{proc,thread}`)
5. **net/packet**: 修复竞争条件
6. **内存安全**: 修复多个内存管理相关的安全问题

---

## 📁 文件系统

### F2FS 重大改进
- ✅ 防止原子文件在提交前被脏化
- ✅ 修复压缩覆盖时的死循环
- ✅ 修复预分配块截断问题
- ✅ 添加查找模式挂载选项
- ✅ 为特权用户添加保留节点
- ✅ 支持禁用线性查找回退

### 其他文件系统
- **btrfs**: 修复 inode ref 大小检查
- **ocfs2**: 修复 fiemap 死锁
- **nilfs2**: 修复 CFI 失败问题

---

## 🌐 网络子系统

### 网络协议栈
- **Unisoc**: 添加 12 个新的网络函数符号
- **MPTCP**: 改进子流管理和关闭传播
- **TCP**: 修复 fastopen 相关问题
- **Bridge**: 改进多播功能

### 网络驱动
- **i40e**: 多个验证和边界检查修复
- **qede**: 修复初始化问题
- **HSR**: 添加 VLAN 和 MC 过滤支持

---

## 🎵 音频 (ASoC)

- 修复 ASoC 核心中的 platform_max 问题
- 添加 Sony DualSense PS5 支持
- 改进 USB 音频驱动
- 修复多个音频编解码器问题

---

## 🖥️ 图形显示

- **i915**: 修复背光缩放问题
- **gma500**: 修复 HDMI 空指针解引用
- **AMD**: 修复内存泄漏
- **fbcon**: 修复字体分配 OOB 和整数溢出

---

## 🏗️ Android GKI 特性

### GKI 符号列表更新
- ✅ Amlogic 符号列表更新
- ✅ QCOM 符号列表更新
- ✅ Unisoc 添加 12 个函数符号
- ✅ Sunxi/Oplus/PointMobile/Honor 更新

### Vendor Hooks 新增
- **内存管理**: 多个内存回收和页面管理 hooks
- **调度器**: CPU cgroup 和实体权重 hooks
- **RCU**: RCU stall 警告 hooks
- **Workingset**: refault 计数记录 hook

### 内存管理
- 导出 `isolate_folio` 和 `reclaim_pages`
- 导出 `isolate_page` 函数
- 添加 memfd-ashmem-shim 层

---

## 🛠️ 构建系统

### 构建脚本改进
- ✅ `build_gki.sh`: 增强错误处理和产物生成
- ✅ 支持 KernelSU 和 AnyKernel3 打包
- ✅ 更新重新打包脚本

### 配置优化
- 启用 schedhorizon
- 使用 fq_codel 作为默认队列
- 启用 -O3 优化
- 启用 wakelock blocker

---

## 🔬 BPF 子系统

- ✅ 添加 dmabuf 迭代器支持
- ✅ 允许小堆栈程序回退到解释器
- ✅ 拒绝 PREEMPT_RT 的 bpf_timer
- ✅ 改进验证器

---

## ⚡ 性能优化

- **CPU 调度**: cpuidle 和 cpufreq 改进
- **内存管理**: vmalloc 和 kvmalloc 优化
- **调度器**: 多个调度器改进

---

## 📊 统计信息

- **修改文件**: 1405 个
- **新增代码**: 22,344 行
- **删除代码**: 11,867 行
- **净增加**: 约 10,477 行

---

## 🎯 主要亮点

1. ✅ **安全性**: 多个关键安全漏洞修复
2. ✅ **稳定性**: 大量 bug 修复和稳定性改进
3. ✅ **性能**: CPU 调度和内存管理优化
4. ✅ **功能**: F2FS 和网络子系统重大改进
5. ✅ **GKI**: 扩展的符号列表和 vendor hooks
6. ✅ **工具**: 改进的构建脚本和工具链

---

## ⚠️ 升级注意事项

1. **安全修复**: 强烈建议尽快升级
2. **符号列表**: 可能需要重新编译内核模块
3. **配置变更**: 检查您的内核配置
4. **备份**: 升级前备份重要数据

---

**生成日期**: 2025年12月3日  
**文件位置**: `out/RELEASE_NOTES_2025-12.md` (详细版本)

