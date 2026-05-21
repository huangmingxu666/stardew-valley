# 角色线程接口交接

> 所属线程：角色 / 交互 / 玩家表现  
> 主要脚本：`scripts/player/*`、`scripts/interaction/Interactable.gd`、`scripts/economy/ShippingBin.gd`  
> 主要场景：`scenes/player/Player.tscn`

---

## 1. 当前线程职责

当前角色线程负责：

- 玩家 8 方向移动、4 方向身体动画与最后按键优先朝向
- 节点式状态机：`Idle` / `Move` / `ToolUse`
- 玩家面前交互探针与统一 `Interactable` 交互入口
- 工具使用时的身体动画、工具动画、命中时机驱动
- 工具使用期间的输入锁定：
  - 忽略重复左键
  - 忽略工具切换
  - 锁定朝向
- 背包打开时禁止工具使用
- 售卖箱交互后请求打开售卖面板
- `Esc` 请求关闭售卖面板 / 关闭 UI

当前线程不负责：

- 工具玩法规则权威实现
- 工具数据资源的最终内容维护
- 售卖面板内部逻辑
- 售卖结算
- 背包 / 快捷栏 UI 交互规则
- 世界掉落物的抛物线、落地后开放拾取、自动吸附策略

相关权威契约：

- `docs/api_contracts/world_drop_and_pickup.md`

---

## 2. 对外输出接口

### 2.1 `PlayerController`

路径：`scripts/player/PlayerController.gd`

对其它线程可安全调用的方法：

```gdscript
func get_selected_tool_data() -> ToolData
func try_use_current_tool() -> bool
func has_selected_tool() -> bool
func is_tool_use_locked() -> bool

func get_interaction_position(distance: float) -> Vector2
func get_target_world_position_at_distance(distance: float) -> Vector2
func get_target_tile() -> Vector2i
func get_target_tile_at_distance(distance: float) -> Vector2i

func request_open_shipping_panel() -> bool
func request_close_shipping_panel() -> bool
func request_close_all_ui() -> bool
```

说明：

- `get_target_tile_at_distance()` / `get_target_world_position_at_distance()` 是工具线程当前命中计算依赖
- `is_tool_use_locked()` 可用于 UI / 工具线程判断当前是否允许切换或再次使用工具
- `request_open_shipping_panel()` / `request_close_shipping_panel()` 是角色线程与售卖线程的 UI 接缝

### 2.2 `Interactable`

路径：`scripts/interaction/Interactable.gd`

统一接口：

```gdscript
func can_interact(player: PlayerController) -> bool
func interact(player: PlayerController) -> void
func get_prompt() -> String
```

说明：

- 新交互对象应继承 `Interactable`
- 玩家主逻辑不直接写死对象类型判断

### 2.3 `ShippingBin`

路径：`scripts/economy/ShippingBin.gd`

当前已实现角色线程相关行为：

```gdscript
func can_interact(player: PlayerController) -> bool
func interact(player: PlayerController) -> void
```

当前 `interact()` 行为：

- 调用 `player.request_open_shipping_panel()`

---

## 3. 当前线程消费的外部接口

### 3.1 工具线程

当前角色线程依赖：

- `ToolController.get_selected_tool_data() -> ToolData`
- `ToolController.use_current_tool() -> bool`
- `ToolController.select_tool_by_id(tool_id)`
- `ToolController.clear_selected_tool()`

当前角色线程消费 `ToolData.visual_data: ToolVisualData`

角色线程默认读取这些字段：

```text
use_down / use_up / use_side
body_use_down / body_use_up / body_use_side
offset_down / offset_up / offset_side
z_index_down / z_index_up / z_index_side
effect_frame_index_down / effect_frame_index_up / effect_frame_index_side
```

说明：

- `ToolVisualData` 里的 `body_use_*` 是当前每种工具身体动作的权威来源
- 若某工具未提供 `body_use_*`，角色线程会回退到 `PlayerVisual` 中的通用 `body_tool_use_*`
- 这个回退是临时兼容层，后续工具线程全部补齐后可删除

### 3.2 UI 线程

角色线程当前按接口消费：

```gdscript
PlayerUiRoot.open_shipping_panel()
PlayerUiRoot.close_shipping_panel()
PlayerUiRoot.close_all_panels()
```

角色线程假设：

- `open_shipping_panel()` 负责显示售卖 UI
- `close_shipping_panel()` 返回 `bool` 表示是否实际关闭
- `close_all_panels()` 返回 `bool` 表示是否关闭了任意 UI

角色线程当前不直接管理：

- 售卖面板内部槽位逻辑
- 快捷栏点击 / 拖拽规则
- 背包面板开关逻辑

### 3.3 时间 / 经济线程

角色线程与售卖结算没有直接数据耦合，只负责交互入口：

- 售卖箱交互 -> 请求打开售卖面板
- `Esc` -> 请求关闭售卖面板

---

## 4. 当前已实现的输入规则

### 玩家移动 / 交互

- `up/down/left/right`：移动
- `交互`：通用交互
- `use_left`：左键使用当前工具

当前 `交互`（F 键）规则补充：

- 先走统一交互链：
  - `PlayerController.try_interact()`
  - `PlayerInteractor.try_interact()`
  - `Interactable.can_interact()/interact()`
- 如果面前没有可交互对象，则回退尝试收获面前成熟作物：

```gdscript
PlayerController._try_harvest_at_target() -> CropRegistry.harvest_crop(target_cell)
```

这意味着成熟作物当前可通过 F 键直接收获，即使它们不是 `Interactable`。

补充边界：

- `F` 键负责“触发收获”
- 收获后“地上掉什么、怎么飞、什么时候能捡”不归 `PlayerController` 负责
- 那部分统一归 `WorldDropManager` / `WorldItemPickup`，详见 `world_drop_and_pickup.md`

### 工具使用限制

当前角色线程已实现：

- 未选择工具时，左键不会进入 `ToolUse`
- `ToolUse` 播放期间，重复左键输入忽略
- `ToolUse` 播放期间，工具切换请求应被忽略
- 背包面板可见时，左键工具使用被屏蔽

注意：

- 快捷栏点击 / 拖拽是否允许，不归角色线程决定
- 如果 UI 线程允许点击快捷栏槽位，需要自行决定是否阻止对应热栏选中行为

---

## 5. 当前状态机约定

路径：

- `scripts/player/state_machine/PlayerState.gd`
- `scripts/player/state_machine/PlayerStateMachine.gd`
- `scripts/player/state_machine/PlayerIdleState.gd`
- `scripts/player/state_machine/PlayerMoveState.gd`
- `scripts/player/state_machine/PlayerToolUseState.gd`

约定：

- 所有状态统一 `extends PlayerState`
- 切状态统一 `transitioned.emit("StateNodeName")`
- 当前状态节点名：
  - `Idle`
  - `Move`
  - `ToolUse`

`ToolUse` 状态职责：

- 锁定朝向
- 驱动 `BodySprite + ToolSprite`
- 在 `effect_frame_index_*` 对应时机调用 `ToolController.use_current_tool()`
- 动画期间忽略重复使用

---

## 6. 后续扩展建议

### 工具 idle / walk 手持表现

更适合：

- 工具线程提供 `ToolVisualData` 中的 `idle_*` / `move_*` 工具帧
- 角色线程在 `IdleState` / `MoveState` 里播放 `ToolSprite`

不建议：

- 把工具 idle / walk 帧硬编码在 `PlayerVisual`

### 逐帧偏移

如果后续工具和手部对位仍需要细调，建议优先扩展：

- `ToolVisualData` 增加逐帧 offset

不建议优先重构为：

- 手持工具独立物理节点 / 独立世界场景

因为当前手持工具是视觉层，不是命中实体。
