# TTZip 高定视觉设计系统与 UI 规范指南 (TTZip UI Design System Specification)

> **设计哲学 (Core Philosophy)**:
> 本规范融合 **无印禅意 (Muji Zen)**、**华尔街日报社论审美 (WSJ Editorial Aesthetic)** 与 **Apple Silicon 原生高透水凝玻璃 (Native Glassmorphism)**。旨在为 macOS SwiftUI 桌面应用提供极具奢华质感、通透优雅且充满秩序感的界面表达。

---

## 目录 (Table of Contents)
1. [核心设计铁律 (Core Principles)](#1-核心设计铁律-core-principles)
2. [色彩令牌与深色模式规范 (Color Palette & Dark Mode)](#2-色彩令牌与深色模式规范-color-palette--dark-mode)
3. [字体排印与版式层次 (Typography & Layout Hierarchy)](#3-字体排印与版式层次-typography--layout-hierarchy)
4. [三栏绝对水平对齐与布局数学 (3-Column Y-Alignment Math)](#4-三栏绝对水平对齐与布局数学-3-column-y-alignment-math)
5. [浮岛玻璃容器与模态弹窗 (Floating Glass Cards & Modals)](#5-浮岛玻璃容器与模态弹窗-floating-glass-cards--modals)
6. [标准组件代码库 (Standard Component Code Patterns)](#6-标准组件代码库-standard-component-code-patterns)
7. [绝对禁止异味与反模式 (Banned Anti-Patterns)](#7-绝对禁止异味与反模式-banned-anti-patterns)

---

## 1. 核心设计铁律 (Core Principles)

1. **贯穿秩序感 (Unbroken Alignment)**:
   - 全应用三栏（左侧报刊侧边栏、中央主工作区、右侧 Inspector 媒体画板）顶栏标牌统一采用 `52pt` 固定高度，其下方的**金缮金分割线 (Kintsugi Gold Rule)** 必须在 **Y = 90pt** 处绝对 100% 水平对齐！
2. **通透无漆黑 (Translucent Depth, Zero Opaque Black Boxes)**:
   - 彻底废除任何硬编码的纯黑或深灰漆黑背景框（如 `#1F1F24`）。在 Dark Mode 下所有卡片与浮岛使用动态微光高透背景 `Color.primary.opacity(0.025 ~ 0.04)`。
3. **浮岛容器化 (Floating Glass Islands)**:
   - 所有工作区、表单、提示框与侧栏画板必须使用 `16pt`（模态框 `18pt`）连续平滑圆角（`.continuous`）浮岛容器，配以 `Color.primary.opacity(0.07)` 纤细发丝线边框。
4. **呼吸感与防拥挤 (Breathable Spacing)**:
   - 拒绝多重 Header 重叠堆砌。组件内边距严格遵守栅格律动，快捷键 Tag 间保留 `6pt` 以上呼吸空间，Miller Column 默认列宽设为 `230pt` 以上。

---

## 2. 色彩令牌与深色模式规范 (Color Palette & Dark Mode)

| 色彩令牌 (Token) | Light Mode | Dark Mode | 语义用途 (Semantic Use) |
| :--- | :--- | :--- | :--- |
| `TTZipTheme.kintsugiGold` | `#C8A96E` | `#D4B87D` | 顶栏 Serif 英文小标、置顶金缮分割线、强调数字 |
| `Color.bambooGreen` | `#789262` (RGB: 120, 146, 98) | `#8FA876` (RGB: 143, 168, 118) | 品牌主色、状态胶囊、主要按钮填充、微光边框 |
| `TTZipTheme.cinnabarRed` | `#C84B31` | `#E05A47` | 危险警告、取消按键、错误校验提示 |
| `Glass Fill (Card)` | `Color.primary.opacity(0.025)` | `Color.primary.opacity(0.025)` | 浮岛卡片默认背景 |
| `Input Field Fill` | `Color.primary.opacity(0.035)` | `Color.primary.opacity(0.035)` | 输入框/下拉框背景 |
| `Hairline Border` | `Color.primary.opacity(0.07)` | `Color.primary.opacity(0.07)` | 浮岛发丝线描边 |

---

## 3. 字体排印与版式层次 (Typography & Layout Hierarchy)

- **顶栏 Section 英文小标**:
  - `font(.system(size: 9, weight: .bold, design: .serif))`
  - `.tracking(2.0)`
  - `.foregroundStyle(TTZipTheme.kintsugiGold)`
- **顶栏 Main 中文主标题**:
  - `font(.system(size: 16, weight: .bold, design: .serif))`
  - `.foregroundStyle(.primary)`
- **数据指标与代码字段**:
  - `font(.system(size: 11..13, weight: .bold, design: .monospaced))`
- **交互胶囊文字**:
  - `font(.system(size: 10.5..12, weight: .bold))`

---

## 4. 三栏绝对水平对齐与布局数学 (3-Column Y-Alignment Math)

```
Window Top Edge (Y = 0)
  │
  ├─ Global Floating Search Bar (.padding(.top, 38))
  │
  ├─ [ Left Sidebar Masthead ] ── Y = 38pt ─── [ Central Workspace ] ─── [ Right Inspector Panel ]
  │      Title Height: 52pt                           Header Height: 52pt             Header Height: 52pt
  │
  └─ ══════════════════════════════════════════════════════════════════════════════════════════════════
     KINTSUGI GOLD RULE (Y = 90pt) - 1.5pt Height Rule Across ALL 3 COLUMNS!
```

- **三栏顶部间距**: 统一设置 `.padding(.top, 38)`，为顶部中央悬浮搜索框（`LiquidGlassSearchBar`）留出空间。
- **三栏 Header 高度**: 统一设置为 `52pt` Height + `.padding(.horizontal, 20)`。
- **分割线对齐式**:
  ```swift
  Rectangle()
      .fill(TTZipTheme.kintsugiGold)
      .frame(height: 1.5)
  ```

---

## 5. 浮岛玻璃容器与模态弹窗 (Floating Glass Cards & Modals)

### 浮岛卡片 Modifier
```swift
.background(Color.primary.opacity(0.025))
.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
)
```

### 模态弹窗 Container Standard
- 宽度：`480pt ~ 520pt`
- 圆角：`18pt continuous`
- 结构：52pt 顶栏金线 + 16pt Padding 表单内容 + 右下角双胶囊按钮 (取消 Capsule / 确认竹青 Capsule)

---

## 6. 标准组件代码库 (Standard Component Code Patterns)

### Pattern 1: 标准页面顶栏标牌 (Standard 52pt Header Bar)
```swift
HStack(spacing: 12) {
    VStack(alignment: .leading, spacing: 1) {
        Text("SECTION_NAME")
            .font(.system(size: 9, weight: .bold, design: .serif))
            .tracking(2)
            .foregroundStyle(TTZipTheme.kintsugiGold)
        Text("中文板块标题")
            .font(.system(size: 16, weight: .bold, design: .serif))
            .foregroundStyle(.primary)
    }
    
    Spacer()
    
    // 右侧状态胶囊或操作按键
    HStack(spacing: 4) {
        Image(systemName: "sparkles")
            .font(.system(size: 10))
            .foregroundStyle(TTZipTheme.bambooGreen)
        Text("状态/指标")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(TTZipTheme.bambooGreen)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(TTZipTheme.bambooGreen.opacity(0.12))
    .clipShape(Capsule())
}
.padding(.horizontal, 20)
.frame(height: 52)

Rectangle()
    .fill(TTZipTheme.kintsugiGold)
    .frame(height: 1.5)
```

### Pattern 2: 高定竹青色交互按键 (Bamboo Green Action Button)
```swift
Button(action: performAction) {
    HStack(spacing: 6) {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
        Text("确认执行")
            .font(.system(size: 12, weight: .bold))
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 7)
    .background(TTZipTheme.bambooGreen)
    .foregroundStyle(Color.white)
    .clipShape(Capsule())
}
.buttonStyle(.plain)
```

---

## 7. 绝对禁止异味与反模式 (Banned Anti-Patterns)

- ❌ **严禁使用原生蓝色 `.buttonStyle(.borderedProminent)`**：所有主按键必须使用高定 `TTZipTheme.bambooGreen` 填充胶囊！
- ❌ **严禁漆黑硬编码填充**：禁止在卡片背景写 `Color(hex: "#1F1F24")` 或 `Color.black`。
- ❌ **严禁三栏金线错位**：左侧、中央与右侧金线的 Y 轴坐标若不为 90pt 即属重大缺陷。
- ❌ **严禁使用 `.textFieldStyle(.roundedBorder)` 默认外观**：输入框必须包裹于 `Color.primary.opacity(0.035)` 微光透框中。

---
*TTZip Architectural Guideline — Maintenance & Evolution Spec*
