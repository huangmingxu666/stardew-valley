Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.



Tradeoff: These guidelines bias toward caution over speed. For trivial tasks, use judgment.



1\. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.



Before implementing:



State your assumptions explicitly. If uncertain, ask.

If multiple interpretations exist, present them - don't pick silently.

If a simpler approach exists, say so. Push back when warranted.

If something is unclear, stop. Name what's confusing. Ask.

2\. Simplicity First

Minimum code that solves the problem. Nothing speculative.



No features beyond what was asked.

No abstractions for single-use code.

No "flexibility" or "configurability" that wasn't requested.

No error handling for impossible scenarios.

If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.



3\. Surgical Changes

Touch only what you must. Clean up only your own mess.



When editing existing code:



Don't "improve" adjacent code, comments, or formatting.

Don't refactor things that aren't broken.

Match existing style, even if you'd do it differently.

If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:



Remove imports/variables/functions that YOUR changes made unused.

Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.



4\. Goal-Driven Execution

Define success criteria. Loop until verified.



Transform tasks into verifiable goals:



"Add validation" → "Write tests for invalid inputs, then make them pass"

"Fix the bug" → "Write a test that reproduces it, then make it pass"

"Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:



1\. \[Step] → verify: \[check]

2\. \[Step] → verify: \[check]

3\. \[Step] → verify: \[check]

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.



These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.



\# Godot 4.6 农场原型项目全局开发规则 (Global Rules)



你正在协助开发一个基于 Godot 4.6 的 2D 类星露谷农场游戏原型。请在所有对话和代码生成中严格遵守以下铁律：



\## 1. 核心开发模式：面向接口与低上下文（极度重要）



\- \*\*严禁全量扫描：\*\* 除非用户明确要求，绝对不允许使用 MCP 检索全站代码或读取整个工程目录。

\- \*\*依赖契约文档：\*\* 当你需要了解其他系统的运行方式时，去读取 `docs/api\_contracts/` 下对应的 `.md` 接口契约文件，严禁直接去读其他模块的 `.gd` 源码。

\- \*\*强制更新契约：\*\* 如果你当前负责的系统新增了对外暴露的方法（Public Methods）、信号（Signals）或全局状态（State），任务完成前必须主动使用 MCP 更新对应的接口契约文档。契约文档只写函数签名、参数类型和返回值，严禁写入任何业务实现细节。



\## 2. Godot 4.6 框架与 2D 限制



\- \*\*只做 2D：\*\* 本项目为纯 2D 项目。严禁引入任何 3D 节点或物理引擎（绝对不要使用 Node3D, CharacterBody3D, Area3D, MeshLibrary 等）。

\- \*\*地图系统：\*\* Godot 4.4+ 已弃用旧版 `TileMap`。所有的地图层必须使用 `TileMapLayer` 节点组织。



\## 3. GDScript 强类型与避坑指南（防推断失败）



Godot 4.6 的类型推断在无明确类型对象时会报错，必须严格遵守以下声明规则：



\- \*\*明确类型优先：\*\* 函数参数、返回值、成员变量尽量显式声明类型（如 `func do\_something(val: int) -> void:`）。

\- \*\*慎用\*\* \*\*`:=`：\*\* 只有当右侧赋值类型 100% 明确时（如 `var count := 10`），才能使用 `:=`。

\- \*\*必须显式声明（高危区）：\*\* 当变量值来源于 `Dictionary.get()`、`get\_node\_or\_null()`、`Resource.get()` 或任何\*\*无明确类型的对象方法调用\*\*时，绝对不准用 `:=`，必须显式写出类型：

&#x20; - ❌ 错误：`var node := get\_node\_or\_null("Path")`

&#x20; - ✅ 正确：`var node: Node = get\_node\_or\_null("Path")`

&#x20; - ✅ 正确：`var can\_afford: bool = battle\_session.can\_afford(...)`



\## 4. 命名与架构解耦规范



\- \*\*资源与文件 (Snake Case)：\*\* 资源 ID 和文件名使用小写蛇形命名（例：`turnip\_seed.tres`, `basic\_hoe`）。

\- \*\*类名 (Pascal Case)：\*\* 脚本类名使用大驼峰命名（例：`FarmGrid`, `CropData`）。

\- \*\*信号 (Past Tense)：\*\* 信号命名必须表意明确，使用过去式或事件式（例：`day\_started`, `crop\_harvested`）。

\- \*\*架构解耦：\*\* 模块间严禁互相硬编码路径读取节点。跨系统通信必须且只能通过：调用接口契约中的明确函数、发射信号（EventBus）或读取统一的资源配置（Data Resource）。



\## 5. MCP 操作纪律



\- 涉及场景树结构（如节点增删、确认层级）时，必须主动调用 Godot MCP 工具（如 `get\_project\_info`, `run\_project`）进行验证，不要靠猜测去手写或修改 `.tscn` 文件。

\- 严禁未经允许擅自修改共享核心场景（如 `Farm.tscn`）或核心管理器（如 `TimeManager.gd`）。





