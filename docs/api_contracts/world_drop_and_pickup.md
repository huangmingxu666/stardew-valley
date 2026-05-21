# 世界掉落物 / 拾取 / 入包 接口契约

> 所属系统：角色 / 交互 / 背包侧  
> 主要脚本：`scripts/world/WorldDropManager.gd`、`scripts/objects/WorldItemPickup.gd`、`scripts/inventory/Inventory.gd`  
> 主要场景：`scenes/objects/WorldItemPickup.tscn`  
> 当前接线场景：`scenes/Test/Farm_Test_soil.tscn`、`scenes/world/Farm.tscn`

---

## 一、职责边界

本契约负责定义以下链路：

```text
作物收获结果
→ WorldDropManager 监听 harvest 结果
→ 生成多个 WorldItemPickup
→ 掉落物从作物原点小范围弹射并抛物线落地
→ 落地后才开放拾取
→ 玩家进入范围
→ 掉落物自动吸附
→ Inventory.add_stack() 尝试入包
→ 成功则播放拾取反馈并销毁
→ 背包满则掉落物保留在地上
```

本契约不负责：

- 作物是否成熟
- 收获产量如何计算
- 收获行为由哪个工具触发
- 物品售价与售卖结算
- 掉落物音效、数字飘字、粒子特效

---

## 二、架构概览

| 层级 | 文件 | 职责 |
|------|------|------|
| 收益转发层 | `scripts/world/WorldDropManager.gd` | 监听收获结果，把 `yield_count` 转成多个世界掉落物 |
| 掉落实例层 | `scripts/objects/WorldItemPickup.gd` | 处理弹出、吸附、碰撞、自动拾取、失败重试 |
| 入包接口层 | `scripts/inventory/Inventory.gd` | 提供统一的堆叠入包接口 |

核心数据流：

```text
ToolController.use_current_tool()
→ CropRegistry.harvest_crop()
→ signal: tool_action_completed(action, cell, result)
→ WorldDropManager._on_tool_action_completed()
→ WorldItemPickup.setup(stack, velocity)
→ 玩家进入 Area2D
→ Inventory.add_stack()
```

---

## 二点五、线程速查

给其它线程的最小判断规则：

| 我是什么线程 | 应该依赖什么 | 不该直接改什么 |
|------|------|------|
| 作物线程 | 发 `tool_action_completed(harvest, cell, result)` | 不直接实例化 `WorldItemPickup` |
| 角色 / 交互线程 | 维护 `WorldDropManager` / `WorldItemPickup` 运行时行为 | 不改作物成熟 / 产量规则 |
| 背包线程 | 维护 `Inventory.add_stack()` / `add_item_data()` | 不在掉落物里手搓 slot 写入 |
| UI 线程 | 监听 `inventory_changed` / `slot_changed` 刷新显示 | 不介入拾取判定 |

当前这条链的权威文档就是本文件。后续如果有旧文档或口头说明与本文件冲突，以本文件为准。

---

## 三、WorldDropManager 对外契约

> 脚本路径：`scripts/world/WorldDropManager.gd`  
> 节点类型：`Node`

### 3.1 作用

`WorldDropManager` 是“收获结果”与“地上掉落物”之间的唯一转换层。

它当前只处理：

- `action == &"harvest"`
- `result.success == true`
- `yield_count > 0`

它当前不处理：

- 摧毁作物掉落
- 砍树掉落
- 商店抛出物品
- 怪物掉落

后续其它系统如果要复用世界掉落逻辑，建议直接复用本节点的生成方式，而不是各自再写一套拾取物。

---

### 3.2 当前消费的上游信号

`WorldDropManager` 当前监听：

```gdscript
CropRegistry.tool_action_completed(action: StringName, cell: Vector2i, result: Dictionary)
```

最低依赖字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `action` | `StringName` | 必须为 `&"harvest"` |
| `result.success` | `bool` | 必须为 `true` |
| `result.crop_id` | `String` | 用于回查 `CropData` |
| `result.yield_count` | `int` | 生成掉落数量 |

收获结果示例：

```gdscript
{
	"success": true,
	"action": "harvest",
	"crop_id": "tomato_crop",
	"crop_item_id": "tomato",
	"yield_count": 3,
	"cell_x": 5,
	"cell_y": 3,
	"regrowable": false,
}
```

---

### 3.3 导出参数

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `crop_registry_path` | `NodePath` | 空 | 显式指定 `CropRegistry` 路径；留空时自动搜索 |
| `drop_parent_path` | `NodePath` | 空 | 显式指定掉落物父节点；留空时优先找当前场景的 `Prop` |
| `scatter_speed_min` | `float` | `28.0` | 掉落初始散射速度最小值 |
| `scatter_speed_max` | `float` | `44.0` | 掉落初始散射速度最大值 |
| `scatter_jitter_radius` | `float` | `3.0` | 生成点抖动半径 |
| `scatter_angle_jitter` | `float` | `0.28` | 每个掉落方向的角度抖动，避免完全规则分布 |

---

### 3.4 内部生成约定

每个收获单位会生成一个 `WorldItemPickup`：

```gdscript
for index: int in range(yield_count):
	_spawn_drop(crop_data.harvest_item, origin, index, yield_count)
```

因此：

- `yield_count == 1` → 地上 1 个图标
- `yield_count == 3` → 地上 3 个图标

如果后续想改成“一个掉落物显示数量 3”，应改 `WorldDropManager` 的生成策略，而不是改 `Inventory.add_stack()`。

---

### 3.5 依赖的上游接口

| 来源 | 方法 / 数据 | 用途 |
|------|-------------|------|
| `CropRegistry` | `tool_action_completed` | 收获完成事件来源 |
| `CropRegistry` | `get_crop_data(crop_id)` | 通过 `crop_id` 回查 `CropData` |
| `CropData` | `harvest_item` | 取出掉落的 `ItemData` |
| `FarmGrid` | `cell_to_world(cell)` | 把格子坐标转换为掉落生成世界坐标 |

### 3.6 对外最小接口

严格说 `WorldDropManager` 当前没有设计成“通用服务对象”，但其它线程如果要复用同一套世界掉落表现，默认可沿用：

```gdscript
var pickup: WorldItemPickup = preload("res://scenes/objects/WorldItemPickup.tscn").instantiate()
drop_parent.add_child(pickup)
pickup.global_position = world_position
pickup.setup(ItemStack.from_item_data(item_data, amount), initial_velocity)
```

如果后续要把它正式提炼成公共接口，建议只额外暴露一个：

```gdscript
func spawn_item_drop(item_data: ItemData, world_position: Vector2, amount: int = 1) -> void
```

而不是让各线程分别复制散射逻辑。

---

## 四、WorldItemPickup 对外契约

> 脚本路径：`scripts/objects/WorldItemPickup.gd`  
> 场景路径：`scenes/objects/WorldItemPickup.tscn`  
> 根节点类型：`Area2D`

### 4.1 作用

`WorldItemPickup` 负责单个地上物品实例的运行时行为：

- 从作物原点小范围弹射出去
- 以抛物线视觉落地
- 落地后才允许拾取
- 玩家进入碰撞范围
- 自动吸附到玩家
- 尝试调用 `Inventory.add_stack()`
- 成功则播放收尾 Tween 并销毁
- 背包满则保留并继续等待

---

### 4.2 Public Method

```gdscript
func setup(item_stack: ItemStack, initial_velocity: Vector2 = Vector2.ZERO) -> void
```

#### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `item_stack` | `ItemStack` | 世界掉落物所代表的物品堆叠 |
| `initial_velocity` | `Vector2` | 初始散射速度 |

#### 调用约束

- `setup()` 应在实例正式使用前调用
- `item_stack` 不应为 `null`
- `item_stack.quantity` 应大于 `0`

当前 `WorldDropManager` 的调用方式：

```gdscript
pickup.setup(ItemStack.from_item_data(item_data, 1), scatter_velocity)
drop_parent.add_child(pickup)
pickup.global_position = origin + jitter
```

### 4.2.1 运行时状态语义

`WorldItemPickup` 当前有两个关键阶段：

| 阶段 | 说明 |
|------|------|
| 空中阶段 | 从原点弹出、按抛物线视觉飞行、不可拾取 |
| 落地阶段 | 开始允许吸附、允许尝试入包 |

因此其它线程如果看到“玩家已经碰到掉落物却没立刻拾取”，先不要判定为 bug，先确认它是否仍处于空中阶段。

---

### 4.3 当前行为参数

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `burst_damping` | `float` | `360.0` | 初始散射速度衰减 |
| `attraction_acceleration` | `float` | `900.0` | 吸附加速度 |
| `attraction_max_speed` | `float` | `180.0` | 吸附时最大速度 |
| `launch_duration_seconds` | `float` | `0.26` | 弹射到落地的飞行总时长 |
| `launch_peak_height_min` | `float` | `12.0` | 抛物线最小峰值高度 |
| `launch_peak_height_max` | `float` | `20.0` | 抛物线最大峰值高度 |
| `failed_pickup_retry_seconds` | `float` | `0.18` | 入包失败后的重试冷却 |
| `pickup_completion_distance` | `float` | `18.0` | 视为拾取完成的距离阈值 |

**职责说明：**

- 掉落物“何时开始允许拾取”属于 `WorldItemPickup.gd` 的职责范围
- 当前实现是**基于落地判定**的开放策略：先完成弹射与抛物线落地，再开放拾取
- 如果后续要改成“落地后再额外等待一段时间”或“落地瞬间自动吸附”，应继续在 `WorldItemPickup.gd` 这一层调整，而不是改作物线程

---

### 4.4 碰撞与拾取规则

场景默认配置：

```text
Area2D.collision_layer = 0
Area2D.collision_mask  = 1
CollisionShape2D       = CircleShape2D(radius = 18)
```

即：

- 掉落物自己不占碰撞层
- 只检测 layer 1 的物体
- 默认依赖玩家在 layer 1 上

当 `body_entered` 命中 `PlayerController` 时：

```gdscript
_tracked_player = player
```

如果掉落物尚未落地，只记录玩家引用，不会立即拾取。  
落地后才会进入自动吸附与入包尝试。

---

### 4.5 入包行为

`WorldItemPickup` 固定按以下 section 顺序尝试：

```gdscript
[
	Inventory.SECTION_BACKPACK,
	Inventory.SECTION_HOTBAR,
]
```

也就是：

1. 先往背包堆叠或找空位
2. 背包放不下，再尝试快捷栏

这套顺序当前写死在：

```gdscript
const PICKUP_SECTION_ORDER
```

如果后续希望“快捷栏优先”或“只允许背包”，改这里即可。

---

### 4.6 成功 / 失败语义

#### 成功

当 `Inventory.add_stack()` 返回：

```gdscript
{
	"added_quantity": > 0,
	"remaining_quantity": 0
}
```

则视为完全拾取成功，执行：

- 关闭 `monitoring`
- 禁用 `CollisionShape2D`
- Tween 到玩家位置
- 缩放/透明淡出
- `queue_free()`

#### 部分成功

当返回：

```gdscript
{
	"added_quantity": > 0,
	"remaining_quantity": > 0
}
```

则：

- 更新 `stack.quantity = remaining_quantity`
- 掉落物继续留在地上
- 等待下一次重试

#### 完全失败

当返回：

```gdscript
{
	"added_quantity": 0
}
```

则：

- 不销毁
- 进入短暂 retry cooldown
- 玩家背包腾出位置后可再次自动拾取

---

## 五、Inventory 新增入包契约

> 脚本路径：`scripts/inventory/Inventory.gd`

### 5.1 新增 Public Methods

```gdscript
func add_item_data(item_data: ItemData, amount: int = 1) -> Dictionary
func add_stack(stack: ItemStack, preferred_sections: Array[StringName] = []) -> Dictionary
```

---

### 5.2 `add_item_data()`

语义：

- 用 `ItemData` + 数量构造一个 `ItemStack`
- 再委托给 `add_stack()`

适合：

- 掉落物拾取
- 奖励发放
- 商店购买后直接进包

---

### 5.3 `add_stack()`

#### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `stack` | `ItemStack` | 要尝试放入背包的堆叠 |
| `preferred_sections` | `Array[StringName]` | 可选 section 顺序 |

#### 默认 section 顺序

如果 `preferred_sections` 为空，则默认：

```gdscript
[
	SECTION_BACKPACK,
	SECTION_HOTBAR,
]
```

#### 放入规则

按顺序执行两阶段：

1. 先尝试向已有同类堆叠合并
2. 再尝试放入空槽

不会发生：

- 自动交换
- 挤掉现有物品
- 跨 section 移动已有物品来腾空间

---

### 5.4 返回结构

成功或失败都返回统一字典：

```gdscript
{
	"success": bool,
	"fully_added": bool,
	"added_quantity": int,
	"remaining_quantity": int,
}
```

#### 示例 1：完全成功

```gdscript
{
	"success": true,
	"fully_added": true,
	"added_quantity": 3,
	"remaining_quantity": 0,
}
```

#### 示例 2：部分成功

```gdscript
{
	"success": true,
	"fully_added": false,
	"added_quantity": 1,
	"remaining_quantity": 2,
}
```

#### 示例 3：完全失败

```gdscript
{
	"success": false,
	"fully_added": false,
	"added_quantity": 0,
	"remaining_quantity": 3,
}
```

---

### 5.5 信号约定

`add_stack()` 内部会正常触发已有背包刷新信号：

```gdscript
slot_changed(section, index, stack)
hotbar_changed()
backpack_changed()
inventory_changed()
```

因此 UI / HUD 不需要额外兼容新拾取流程。

### 5.6 给其它线程的调用建议

推荐：

```gdscript
var result: Dictionary = inventory.add_item_data(item_data, amount)
if bool(result.get("success", false)):
	# 成功发奖励或销毁来源
```

或：

```gdscript
var result: Dictionary = inventory.add_stack(stack, [Inventory.SECTION_BACKPACK])
```

不推荐：

```gdscript
inventory.set_stack(...)
inventory.clear_slot(...)
inventory.move_or_swap_stack(...)
```

直接拼装出“奖励发放 / 自动拾取 / 购买入包”的行为。

---

## 六、推荐给其它线程的接法

### 6.1 作物线程

作物线程不需要直接生成掉落物，只需要保证收获结果继续通过：

```gdscript
tool_action_completed(action, cell, result)
```

对外发出，并确保：

```gdscript
action == &"harvest"
result.success == true
result.crop_id 有效
result.yield_count >= 1
```

---

### 6.2 其它掉落来源线程

如果以后树木、石头、怪物也要掉落，推荐复用当前模式：

```gdscript
var pickup: WorldItemPickup = preload("res://scenes/objects/WorldItemPickup.tscn").instantiate()
pickup.setup(ItemStack.from_item_data(item_data, amount), initial_velocity)
drop_parent.add_child(pickup)
pickup.global_position = world_position
```

不要绕过 `Inventory.add_stack()` 直接改 slot。

更进一步的建议：

- 如果只是想“直接给物品”，调用 `Inventory.add_item_data()`
- 如果想要“地上弹出再捡”，复用 `WorldItemPickup`
- 如果想要“收获结果自动转掉落”，复用 `WorldDropManager` 的监听式接法

---

### 6.3 背包线程

背包线程后续如要扩展自动拾取，建议继续保持 `add_stack()` 为唯一正式入口。

可以扩展：

- 权限校验
- 限定 section
- 某些物品禁止自动拾取

但不要让不同系统分别调用：

- `set_stack()`
- `clear_slot()`
- `move_or_swap_stack()`

去手搓“入包逻辑”。

---

## 七、当前场景接线状态

### 7.1 `scenes/Test/Farm_Test_soil.tscn`

当前已接：

```text
Gameplay/CropRegistry
Gameplay/WorldDropManager
```

这里是当前推荐的掉落物验证场景。

### 7.2 `scenes/world/Farm.tscn`

当前已放入：

```text
Gameplay/WorldDropManager
```

但主场景目前没有 `CropRegistry` 节点，因此：

- 不会报错
- 也不会实际生成作物收获掉落

后续主场景接入 `CropRegistry` 后，这个管理器会自动开始工作。

---

## 八、已知限制

- 当前没有音效。
- 当前没有“拾取数量 +1 / +3”的飘字。
- 当前掉落物视觉直接使用 `ItemStack.icon_texture`。
- 当前掉落物默认依赖玩家在 layer 1。
- 当前没有专门的“拾取磁吸范围显示”。
- 当前没有存档恢复地面掉落物。
- 当前 `WorldDropManager` 还没有正式抽成全局公共掉落服务，只是在当前场景内作为监听节点存在。

---

## 九、最小验证清单

联调时建议至少验证以下情况：

1. 收获 1 个番茄时，掉落物先从作物原点弹出并落地，落地后才可拾取。
2. 收获 3 个番茄时，地上出现 3 个图标，并围绕作物做小范围四散，不会横向飞太远。
3. 玩家在掉落物飞行过程中提前靠近时，不会在空中直接吸走。
4. 背包已满时，掉落物不会消失。
5. 背包腾出空间后，再靠近仍能拾取。
6. UI 热栏与背包数量会自动刷新，不需要额外手动刷新调用。
