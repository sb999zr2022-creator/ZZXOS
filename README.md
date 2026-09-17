# ZZX OS: 基于 x86 裸机架构的微型实模式操作系统设计与实现
> **Design and Implementation of a Micro Real-Mode Operating System Based on Bare-Metal x86 Architecture**

![Language](https://img.shields.io/badge/Language-16--bit%20x86%20Assembly%20(NASM)-blue.svg)
![Platform](https://img.shields.io/badge/Platform-x86%20Bare--Metal%20%2F%20QEMU-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)



---

## 📖 项目简介 (Introduction)

**ZZX OS** 是一款基于 **x86 裸机 (Bare-Metal) 架构**、完全采用 **16位 x86 汇编语言**（Intel 语法，NASM 编译器）自主研发的极简微型操作系统内核[cite: 1, 2]。

系统完全脱离现代操作系统（如 Linux、Windows）及其庞大的 C 语言运行时（C Runtime）支撑环境[cite: 1, 2]，直接运行于 x86 计算机的**实模式 (Real Mode)** 下[cite: 1, 2]。在小于 **10KB** 的二进制空间内，完整集成了自包含的 MBR Bootloader、开机 POST 硬件自检序列、开机动态 Logo 动画、双栏 TUI (Text-based User Interface) 交互 Shell，以及基于 VGA Standard Mode 13h 的纯汇编 3D 图形软渲染引擎[cite: 1, 2]。

详细的技术设计文档与架构解析，请参阅我的个人博客：
👉 **[www.theozheng.cn](https://www.theozheng.cn)**

---

## ✨ 核心特性 (Key Features)

- **零依赖与纯汇编设计**：全系统无任何外部动态库、静态库或高层次语言运行时支持，直接通过 16位 x86 汇编指令与 BIOS 中断（INT 0x10, INT 0x13, INT 0x16 等）驱动硬件[cite: 1, 2]。
- **自包含 MBR 引导程序**：完美适配 512 字节磁盘首扇区限制，具备 CHS 寻址与 3 次磁盘读取容错机制，自动将内核连续加载至 `0x1000:0x0000` 内存段[cite: 1, 2]。
- **两阶段内核初始化**：
  - **动态 ASCII Logo 展演**：通过色彩属性字节（Color Attribute Byte）与 BIOS INT 0x15 延时例程实现渐变脉冲闪烁。
  - **15 项 POST 开机自检**：实时测试 CPU 指令集、640KB 基础内存、15MB 扩展内存、硬件 RTC 时钟及 BIOS 中断向量表等[cite: 1, 2, 4]。
- **双栏 TUI 交互 Shell**：
  - 基于 `0xB8000` 文本显存直接映射[cite: 1, 2]，消除硬件光标闪烁[cite: 1, 2, 4]。
  - 支持 **Alt+B** 快速切换焦点（交互控制台区 vs 存储块映射区）[cite: 1, 2, 4]。
- **VGA Mode 13h 3D 软渲染引擎**：利用定点数矩阵旋转算法与 Bresenham 变体画线算法[cite: 1, 2]，在 $320 \times 200$ 256色图形模式（`0xA0000` 显存）下实现实时三维线框旋转[cite: 1, 2]。

---

## 🏗️ 系统架构与模块划分 (System Architecture)

系统寻址空间限定在 1MB 物理内存（`0x00000 - 0xFFFFF`）范围内，划分为以下四个核心子系统：

```text
+-------------------------------------------------------------------+
|                            ZZX OS Core                            |
+-------------------------------------------------------------------+
|  1. Bootloader & POST Engine  |  2. TUI & Text Memory Engine     |
|     - MBR 512B Load (0x7C00)  |     - Direct Video Map (0xB800)   |
|     - 15-Point POST Checklist |     - Split-Screen Layout & Focus |
+-------------------------------+-----------------------------------+
|  3. Shell Interpreter Subsys  |  4. Mode 13h 3D Graphical Engine  |
|     - INT 0x16 Keyboard Logic |     - Direct Video Map (0xA000)   |
|     - Command Dispatcher      |     - 3D Matrix & Line Rendering  |
+-------------------------------------------------------------------+
