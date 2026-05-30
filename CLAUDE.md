# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## 5. Git 工作区管理

**每次功能改动后及时提交，必要时切换分支隔离不同工作。**

### 提交节奏
- 完成一个独立的功能点或修复后，立即提交，不积攒大量未提交改动。
- 提交信息使用中文，简洁描述改动目的（"为什么"而非"做了什么"）。
- 一个 commit 只做一件事，不混入无关改动。

### 分支管理
- 开发新功能或做较大改动前，从 main 切出新分支。
- 分支命名：`feature/<功能名>`、`fix/<问题名>`、`refactor/<重构内容>`。
- 完成工作后切回 main 再开始下一项任务，避免改动交叉污染。

### 提醒规则
- 当发现工作区有未提交改动且改动量较大时，主动提醒是否该提交。
- 当用户要在 main 分支上直接做较大改动时，提醒切分支。
- 当用户要开发新功能或添加功能时，提醒切分支。

## 6. 文档同步维护

**技术决策变了，文档必须跟着变。文档是第一手真相，代码是实现细节。**

### 变更回写规则
- 任何对技术架构、检测方案、权限需求、构建流程的改动完成后，**必须**回到 SPEC-FINAL.md 和 ARCHITECTURE.md 中更新对应章节。
- 不止改一处，还要**扫描文档中所有受影响的区域**（如数据流图、模块接口签名、验证步骤、项目结构树），一并修正。
- 如果旧方案被废弃，在文档中标注 `[已废弃]` 并说明原因，而非直接删除（保留历史决策链）。

### 需要同步的文档

| 文档 | 内容 | 何时更新 |
|------|------|---------|
| SPEC-FINAL.md | 产品规格、触发逻辑、技术选型结论 | 产品行为或技术方案变更时 |
| ARCHITECTURE.md | 项目结构、模块接口、数据流、构建 | 代码架构或构建流程变更时 |
| README.md | 项目介绍、安装方式、设置说明 | 用户可见的功能/安装步骤变化时 |
| USER-GUIDE.md | 使用说明、FAQ | 用户操作方式或限制变化时 |

### 常见变更 → 影响范围速查

| 改动 | 需更新的文档 |
|------|------------|
| 新增/删除模块 | ARCHITECTURE §1 项目结构、§3 模块职责 |
| 检测方案变更 | SPEC-FINAL §2.1 §3.3、ARCHITECTURE §2.1 §3.3、README |
| 窗口/动画行为变更 | ARCHITECTURE §2.2 §3.6-3.11 |
| 权限需求变更 | SPEC-FINAL §3.3、ARCHITECTURE §2.4、Info.plist |
| 构建/分发流程变更 | ARCHITECTURE §6、build.sh、README 安装说明 |
| API 接口签名变更 | ARCHITECTURE §3 对应模块的 Swift 签名 |
| 设置项变更 | SPEC-FINAL §2.5、ARCHITECTURE §3.13、README 设置表 |

## 7. 发版流程

**每次发布 release，版本号三处必须对齐，缺一不可：**

1. `TerminalNotifier/Info.plist` — `CFBundleShortVersionString`（用户可见版本，如 `1.2.0`）；`CFBundleVersion`（构建号）每次发版 +1。
2. `README.md` 更新日志加新版本条目。
3. `git tag` + `gh release create v<x.y.z>`（打 tag、上传 `.zip`、写 release notes）。

**版本号规则（语义化 主.次.补丁）：** 加功能 → 次版本 +1；只修 bug → 补丁 +1；破坏性改动 → 主版本 +1。

> ⚠️ **最容易漏的就是 Info.plist 的版本号**——它是 app 内部的「身份证」，漏改会导致 release tag 与 app 实际显示版本对不上。发版前第一件事就是改它。
