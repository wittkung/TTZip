# Spec Kit 多 Agent 并发隔离规则 (Multi-Agent Isolation Protocol)

> 本规则确保多个 AI Agent 在同一仓库中并发执行 Spec Kit 流水线时，Feature 上下文互不串台。
> 本文件不受上游 manifest 追踪，`specify integration upgrade` 不会覆盖。
> 
> 上游状态：[Issue #4128](https://github.com/github/spec-kit/issues/4128) (RFC 获核心维护者 @mnriem 支持) →
> [PR #4129](https://github.com/github/spec-kit/pull/4129) (官方定名 `SPECIFY_FEATURE_NO_PERSIST`，待合并)。
> 本地 `common.sh` 已 backport 并双向兼容 `SPECIFY_FEATURE_NO_PERSIST` 与 `SPECIFY_NO_PERSIST`。

---

## 一、 强制环境变量注入

当 Agent 执行 Spec Kit 流水线的任何阶段时，**必须在每次脚本调用前注入两个进程级环境变量**：

| 变量 | 推荐值 | 作用 |
|:-----|:---|:-----|
| `SPECIFY_FEATURE_DIRECTORY` | 当前 Agent 负责的 Feature 目录 | 短路 `feature.json` 读取，最高优先级 |
| `SPECIFY_FEATURE_NO_PERSIST` | `1` | 阻止脚本将 Feature 目录回写到 `feature.json`（官方标准定名） |
| `SPECIFY_NO_PERSIST` | `1` | 向下兼容别名 |

### 1. 脚本调用格式

所有对 `.specify/scripts/bash/` 下脚本的调用，必须使用以下格式：

```bash
SPECIFY_FEATURE_DIRECTORY="<feature-dir>" SPECIFY_FEATURE_NO_PERSIST=1 .specify/scripts/bash/<script>.sh --json
```

示例：

```bash
SPECIFY_FEATURE_DIRECTORY="specs/003-sorting-fix" SPECIFY_FEATURE_NO_PERSIST=1 .specify/scripts/bash/setup-plan.sh --json
SPECIFY_FEATURE_DIRECTORY="specs/003-sorting-fix" SPECIFY_FEATURE_NO_PERSIST=1 .specify/scripts/bash/setup-tasks.sh --json
SPECIFY_FEATURE_DIRECTORY="specs/003-sorting-fix" SPECIFY_FEATURE_NO_PERSIST=1 .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
```

### 2. Feature 上下文获取

Agent 在接收到 Spec Kit 任务时，必须通过以下方式确定 `SPECIFY_FEATURE_DIRECTORY`：

1. 用户或调度器显式指定的 Feature 目录（最高优先级）
2. `speckit-specify` 步骤的 Completion Report 中输出的 `SPECIFY_FEATURE_DIRECTORY` 值
3. 仅在确认当前为单 Agent 环境时，允许依赖 `.specify/feature.json`

### 3. Feature 目录创建

创建新 Feature 时，Agent 必须：

1. 调用 `create-new-feature.sh --dry-run --json` 获取目录名和路径（不会写入 `feature.json`）
2. 自行执行 `mkdir -p` 创建目录
3. 复制 spec-template 到目录中
4. 将生成的路径作为 `SPECIFY_FEATURE_DIRECTORY` 用于后续所有步骤

或者使用 `--timestamp` 模式避免序号竞态：

```bash
.specify/scripts/bash/create-new-feature.sh --timestamp --json "feature description"
```

---

## 二、 禁止直接操作全局状态

1. **禁止直接写入 `.specify/feature.json`**。Agent 不得使用 `write_to_file` 或任何方式
   直接修改此文件。该文件仅作为单 Agent 兼容模式的被动存储。
2. **禁止依赖 `.specify/feature.json` 的读取值**。Agent 必须始终通过环境变量传递
   Feature 上下文，不得假设 `feature.json` 中的值是自己的。

---

## 三、 技术原理

上游 `common.sh` 中的 `get_feature_paths()` 解析优先级为：

```
SPECIFY_FEATURE_DIRECTORY 环境变量  >  .specify/feature.json  >  报错退出
```

当环境变量被注入时，`feature.json` 的读取分支被完全短路。

`SPECIFY_FEATURE_NO_PERSIST=1`（或 `SPECIFY_NO_PERSIST=1`）时，`get_feature_paths()` 跳过 `_persist_feature_json` 调用，
不会将环境变量的值回写到 `feature.json`。这消除了多 Agent 并发时的"最后写入者获胜"竞态。

### 隔离机制图示

```
Agent-A (SPECIFY_FEATURE_DIRECTORY=specs/003 + SPECIFY_FEATURE_NO_PERSIST=1)
  └─ setup-plan.sh → get_feature_paths()
       ├─ 读取: 环境变量 specs/003 ✓（短路 feature.json）
       └─ 写入: 跳过（SPECIFY_FEATURE_NO_PERSIST=1）

Agent-B (SPECIFY_FEATURE_DIRECTORY=specs/006 + SPECIFY_FEATURE_NO_PERSIST=1)
  └─ setup-tasks.sh → get_feature_paths()
       ├─ 读取: 环境变量 specs/006 ✓（短路 feature.json）
       └─ 写入: 跳过（SPECIFY_FEATURE_NO_PERSIST=1）

feature.json: 完全不被触碰 → 零竞态
```

---

## 四、 与上游兼容性保证

1. 本规则不修改任何受上游 manifest 追踪的文件：
   - `.agents/skills/speckit-*/SKILL.md` — 受 `agy.manifest.json` 追踪
   - `.specify/scripts/bash/*.sh` — 受 `speckit.manifest.json` 追踪（本地已预打双向兼容补丁）
   - `.specify/templates/*.md` — 受 `speckit.manifest.json` 追踪
2. `specify integration upgrade agy` 可安全执行，不会与本规则产生冲突。
   - ⚠️ 升级后 `common.sh` 会被覆盖。若 PR #4129 已合并则无需重新 backport；
     若未合并，重新应用补丁即可。
3. 单 Agent 用户不设置 `SPECIFY_FEATURE_DIRECTORY` / `SPECIFY_FEATURE_NO_PERSIST` 时，
   上游默认行为完全不受影响。
