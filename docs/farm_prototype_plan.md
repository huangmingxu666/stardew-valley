# 类星露谷农场游戏原型开发方案

## 1. 原型目标

现阶段建议制作一个小范围、可玩的农场垂直切片，而不是直接制作完整游戏，也不是制作完全不可复用的临时 Demo。

第一版原型要验证核心循环：

```text
移动 -> 交互 -> 锄地 -> 播种 -> 浇水 -> 睡觉 -> 成长 -> 收获 -> 售卖 -> 购买种子
```

只要这个循环成立，后续的建筑、室内、NPC、任务、动物、钓鱼、战斗都可以围绕它扩展。

## 2. 当前资源判断

你已经具备比较完善的农场素材和拓展建筑素材，因此下一步不需要继续停留在抽象设计阶段。

建议直接推进第一阶段：农场地图切片。

目标不是制作最终大地图，而是先把素材导入 Godot，搭出一张可运行的农场测试地图，完成 TileMapLayer 分层、碰撞、Y-sort、遮挡、玩家移动和镜头跟随。

第一阶段完成后，再接格子系统和种植系统会更稳，因为后续所有玩法都要落在真实地图和真实素材上。

## 3. 第一版可玩范围

第一版只做一个 10 分钟左右可玩的农场循环：

1. 玩家从农场或房间开始。
2. 玩家移动到耕地区域。
3. 使用锄头开垦土地。
4. 播种。
5. 浇水。
6. 睡觉进入下一天。
7. 作物成长。
8. 成熟后收获。
9. 放入售卖箱获得金币。
10. 用金币购买更多种子。

第一版暂时不做：

- NPC 好感度
- 复杂剧情任务
- 钓鱼
- 战斗
- 动物养殖
- 大量建筑升级
- 复杂烹饪和制造
- 完整季节系统
- 大地图探索

## 4. 项目共享约定

这一节是所有并行线程都必须先阅读的公共约定。

它不属于某一个开发阶段，而是项目级基础规则。后续如果开多个线程并行开发，不需要每个线程重复解释这些内容，只要告诉它们：

```text
先阅读《项目共享约定》，再阅读自己负责的系统章节。
```

### 4.1 Godot 基础约定

- Godot 版本：4.6。
- 渲染模式：2D 项目优先。
- Tile 尺寸：大部分素材按 32x32 处理，小部分特殊素材允许单独记录尺寸和对齐规则。
- 地图节点：Godot 4.4 及以后不再优先使用旧 `TileMap`，地图层使用 `TileMapLayer` 组织。
- 地图摆放：视觉地图可以由你手工搭建，线程不强行自动生成整张地图。
- 玩家碰撞体尺寸：需要和 Tile 尺寸、门、道路宽度一起验证。
- 地图坐标与格子坐标必须统一，不允许每个系统自己写一套换算。

### 4.2 命名约定

资源 ID 使用小写蛇形命名：

```text
turnip_seed
turnip
basic_hoe
basic_watering_can
shipping_bin
```

脚本类名使用大驼峰：

```text
FarmGrid
FarmTileState
PlayerController
CropData
ItemData
```

信号名使用过去式或事件式，避免含糊：

```text
day_started
day_ended
item_added
crop_harvested
tile_state_changed
```

### 4.3 数据边界约定

TileMapLayer 负责显示，不作为唯一玩法数据源。

视觉地图和玩法格子要分开理解：

- 视觉地图：由 `TileMapLayer` 和手工摆放的装饰、建筑、树木等节点组成，可以由你亲自搭建。
- 玩法格子：由 `FarmGrid` 管理，用于判断可耕种、已锄地、已浇水、作物状态等。

因此即使地图需要手工摆放，农场格子系统仍然可以交给线程负责。线程不需要替你设计整张地图，只需要实现：

- 世界坐标和格子坐标转换。
- 指定区域初始化为可耕种地块。
- 查询和修改某个格子的玩法状态。
- 根据格子状态通知视觉层更新。

农场格子状态由 `FarmGrid` 或同类系统管理，至少包含：

```text
坐标
地表类型
是否可耕种
是否已锄地
是否已浇水
当前作物
作物成长阶段
是否有障碍物
```

物品、作物、工具都应数据驱动，不要写死在玩家控制器或工具脚本里。

### 4.4 系统通信约定

系统之间优先通过以下方式通信：

- 明确类型的函数调用
- 信号
- 数据资源
- 统一管理器

避免：

- 跨系统直接改内部变量
- 用节点路径硬找其他系统
- 在玩家脚本里堆所有玩法逻辑
- 让 TileMapLayer 同时负责显示、规则、存档

### 4.5 并行开发约定

每个线程最好只负责一个系统目录。

不要让多个线程同时修改这些核心文件：

```text
scenes/world/Farm.tscn
scripts/core/GameState.gd
scripts/core/TimeManager.gd
scripts/player/PlayerController.gd
scripts/farm/FarmGrid.gd
```

如果必须修改共享文件，需要先说明：

- 为什么要改
- 改哪些接口
- 会影响哪些系统
- 其他线程需要怎么适配

### 4.6 GDScript 类型约定

成员变量尽量写明确类型。

函数返回值尽量写明确类型。

`:=` 只在右侧类型非常明确时使用。

来自无类型对象、`Dictionary.get()`、`get_node_or_null()`、`Resource.get()` 的值，优先显式声明类型。

推荐：

```gdscript
var farm_grid: FarmGrid
var inventory: Inventory
var current_tool: ToolData

func get_selected_item() -> ItemData:
	return inventory.get_selected_item()
```

谨慎：

```gdscript
var item := inventory_data.get("selected_item")
var target := get_node_or_null("Target")
var result := manager.call_some_method()
```

## 5. 推荐项目结构

```text
scenes/
  world/
	Farm.tscn
	FarmPrototype.tscn
  player/
	Player.tscn
  ui/
	HUD.tscn
	InventoryPanel.tscn
	ShopPanel.tscn
  objects/
	ShippingBin.tscn
	Bed.tscn
	Door.tscn
  crops/
	Crop.tscn

scripts/
  core/
	GameState.gd
	TimeManager.gd
	SaveManager.gd
	EventBus.gd
  data/
	ItemData.gd
	CropData.gd
	ToolData.gd
  farm/
	FarmGrid.gd
	FarmTileState.gd
	FarmMapController.gd
  player/
	PlayerController.gd
	PlayerInteractor.gd
	ToolController.gd
  inventory/
	Inventory.gd
	ItemStack.gd
  economy/
	ShippingBin.gd
	ShopInventory.gd
  interaction/
	Interactable.gd
  crops/
	CropInstance.gd
	CropRegistry.gd
```

核心原则：

- Player 不直接管理作物。
- 作物不直接管理全局时间。
- TileMapLayer 不直接等于游戏状态。
- 交互对象使用统一接口。
- 数据内容尽量放在资源或配置里。
- 存档读取和玩法节点解耦。

## 6. 系统拆分和线程分工

### 6.1 地图与素材系统

地图视觉摆放更适合由你主导，线程可以辅助整理 TileSet、TileMapLayer 层级、碰撞和测试场景结构。

职责：

- 导入农场素材。
- 配置 TileSet。
- 搭建或辅助搭建第一张农场测试地图。
- 设置 TileMapLayer 分层。
- 设置碰撞。
- 设置前景遮挡。
- 处理玩家与建筑、树木、围栏的视觉排序。

建议产出：

```text
scenes/world/FarmPrototype.tscn
scenes/world/Farm.tscn
scripts/farm/FarmMapController.gd
```

TileMapLayer 建议分层：

```text
Ground       地面层
Soil         可耕地表现层
Decoration   装饰层
Collision    碰撞层
Front         前景遮挡层
Interactable 交互标记层
```

验收标准：

- 玩家可以在农场中自然移动。
- 不会穿过建筑、树木、围栏、水体。
- 玩家走到树、建筑、门框后方时遮挡关系正确。
- 地图中预留一块可耕种测试区域。
- 地图中预留房屋、售卖箱、商店入口位置。

### 6.2 玩家控制系统

职责：

- 八方向移动。
- 行走动画。
- 镜头跟随。
- 当前朝向。
- 当前目标格计算。
- 基础交互输入。

建议产出：

```text
scenes/player/Player.tscn
scripts/player/PlayerController.gd
scripts/player/PlayerInteractor.gd
```

验收标准：

- 玩家移动手感稳定。
- 动画方向正确。
- 镜头跟随自然。
- 能计算玩家面前的目标格。
- 能调用交互对象的 `interact()`。

### 6.3 交互系统

职责：

- 定义所有可交互对象的统一规则。
- 提供交互提示文本。
- 提供交互检测方式。

建议接口：

```text
Interactable
- can_interact(player)
- interact(player)
- get_prompt()
```

建议产出：

```text
scripts/interaction/Interactable.gd
scripts/player/PlayerInteractor.gd
```

验收标准：

- 玩家可以与售卖箱、床、门、地块使用同一套交互流程。
- 新增交互对象时，不需要改玩家主控制逻辑。

### 6.4 农场格子系统

适合交给独立线程负责。

这个系统不负责美术摆放整张地图，只负责玩法格子数据和坐标规则。

职责：

- 管理农场每个格子的玩法状态。
- 判断某个格子是否可耕种。
- 判断某个格子是否已锄地、已浇水、已有作物。
- 向 TileMapLayer 或对应视觉节点同步变化。
- 提供世界坐标和格子坐标转换方法。
- 支持从指定矩形区域或标记层初始化可耕种区域。

建议产出：

```text
scripts/farm/FarmGrid.gd
scripts/farm/FarmTileState.gd
```

验收标准：

- 可以查询任意格子的状态。
- 可以修改格子状态并刷新显示。
- TileMapLayer 只是显示层，不是唯一数据源。
- 手工摆放的地图也能接入格子系统。

### 6.5 工具系统

职责：

- 铲子：可耕地变为已锄地。
- 水壶：已锄地变为已浇水。
- 种子：在已锄地块上播种。
- 收获：作物成熟后获得物品。

建议产出：

```text
scripts/player/ToolController.gd
scripts/data/ToolData.gd
```

验收标准：

- 工具只对合法目标格生效。
- 无效目标格有失败反馈或无操作。
- 工具逻辑不直接写死在玩家移动脚本里。

### 6.6 作物系统

职责：

- 管理作物数据。
- 管理作物实例状态。
- 按天推进成长。
- 处理成熟和收获。

建议作物数据：

```text
CropData
- id
- seed_item_id
- harvest_item_id
- growth_days
- stages
- season
- regrow_days
- needs_water
```

建议产出：

```text
scripts/data/CropData.gd
scripts/crops/CropInstance.gd
scripts/crops/CropRegistry.gd
scenes/crops/Crop.tscn
```

验收标准：

- 至少 3 种作物可用。
- 作物可以根据天数切换阶段。
- 作物成熟后可以收获对应物品。
- 作物数据不写死在工具脚本里。

### 6.7 物品与背包系统

职责：

- 定义物品数据。
- 管理物品堆叠。
- 管理背包。
- 管理快捷栏。

建议物品数据：

```text
ItemData
- id
- name
- icon
- stackable
- max_stack
- type
- sell_price
```

建议产出：

```text
scripts/data/ItemData.gd
scripts/inventory/Inventory.gd
scripts/inventory/ItemStack.gd
scenes/ui/InventoryPanel.tscn
```

验收标准：

- 可以添加、移除、查询物品。
- 同类物品可以堆叠。
- 快捷栏可以选择当前工具或种子。
- 售卖和商店能通过物品 ID 结算。

### 6.8 时间系统

职责：

- 管理当前时间。
- 管理当前日期。
- 管理睡觉进入下一天。
- 发出日变化事件。

建议事件：

```text
day_started
day_ended
hour_changed
```

建议产出：

```text
scripts/core/TimeManager.gd
```

验收标准：

- 时间可以推进。
- 睡觉后进入下一天。
- 作物系统能响应天数变化。
- 未来可以扩展季节、天气、节日。

### 6.9 售卖与商店系统

职责：

- 售卖箱接收物品。
- 睡觉后结算金币。
- 简单商店出售种子。

建议产出：

```text
scenes/objects/ShippingBin.tscn
scripts/economy/ShippingBin.gd
scripts/economy/ShopInventory.gd
scenes/ui/ShopPanel.tscn
```

验收标准：

- 玩家可以把作物放入售卖箱。
- 进入下一天后获得金币。
- 玩家可以花金币购买种子。
- 买卖都通过物品数据结算。

### 6.10 存档系统

职责：

- 保存玩家位置。
- 保存背包。
- 保存金币。
- 保存当前日期。
- 保存农场格子状态。
- 保存作物状态。
- 保存已放置物体。

建议产出：

```text
scripts/core/SaveManager.gd
```

验收标准：

- 退出游戏后重新进入，农场状态仍然存在。
- 作物、背包、金币、日期可以恢复。
- 存档结构不要直接依赖场景节点路径。

## 7. 推荐开发顺序

### 7.1 农场地图切片

你已经有完整农场素材，所以建议现在就做这一阶段。

建议地图内容：

- 玩家出生点。
- 一块 6x4 或 8x6 的可耕地。
- 一栋房屋。
- 一个售卖箱。
- 一条通往商店或地图边缘的路。
- 几棵树、围栏、水体、装饰物，用于验证碰撞和遮挡。

验收标准：

- 场景能运行。
- 玩家能走动。
- 碰撞正确。
- 视觉排序正确。
- 可耕地区域位置明确。

### 7.2 基础系统并行开发

地图切片稳定后，可以并行：

- 玩家控制系统
- 交互系统
- 农场格子系统
- 物品与背包系统
- 时间系统

### 7.3 种植闭环

基础系统可用后，接入：

- 工具系统
- 作物系统
- 售卖与商店系统

目标是完成完整农场循环。

### 7.4 存档接入

当格子、作物、背包、时间的数据结构稳定后，再接入存档。

不要太晚做存档，但也不要在数据结构频繁变化时过早写复杂存档。

## 8. 原型和重构策略

可以接受后续重构，但不要让核心数据模型变成临时代码。

可以先简化：

- UI 表现
- 商店界面
- 工具动画
- 作物数量
- 地图规模
- 经济数值

不建议写死：

- 物品 ID
- 作物成长数据
- 格子状态
- 存档结构
- 交互方式
- 时间事件
- 地图坐标系统

这些内容一旦写乱，后续内容越多，重构成本越高。

## 9. Godot GDScript 新版本注意事项：类型推断失败

之前开发时遇到的问题，更准确地说不是简单的“变量必须显式声明”，而是 Godot GDScript 的类型推断在某些情况下会失败。

典型错误：

```gdscript
var battle_session

func cast_spell() -> void:
	var can_afford := battle_session.can_afford_spell(...)
```

`:=` 的意思是让 Godot 根据右边的值自动推断变量类型。

问题在于 `battle_session` 本身没有明确类型：

```gdscript
var battle_session
```

所以 Godot 不确定：

```gdscript
battle_session.can_afford_spell(...)
```

这个调用到底返回什么类型。

即使实际函数里写了：

```gdscript
func can_afford_spell(...) -> bool:
```

因为调用对象 `battle_session` 是无类型的，解析器也无法可靠推断，于是可能报错：

```text
Cannot infer the type of "can_afford" variable because the value doesn't have a set type.
```

解决方式一：给局部变量显式声明类型。

```gdscript
var can_afford: bool = battle_session.can_afford_spell(...)
```

解决方式二：给成员变量声明类型，从源头解决。

```gdscript
var battle_session: BattleSession
var can_afford := battle_session.can_afford_spell(...)
```

简单记法：

```gdscript
# 右边类型明确，可以用 :=
var count := 10
var name := "hero"
var tile := Vector2i(3, 5)

# 右边来自无类型对象、Dictionary.get()、get_node_or_null()、Resource.get() 等，最好写显式类型
var can_afford: bool = battle_session.can_afford_spell(...)
var node: Node = get_node_or_null("Path")
var value: float = float(data.get("value", 0.0))
```

后续写 GDScript 时，看到下面这种形式就要警惕：

```gdscript
var result := unknown_object.some_method()
```

如果 `unknown_object` 没有明确类型，Godot 很可能无法推断 `result` 的类型。

## 10. 当前项目快照（2026-05-12 检查）

这一节用于修正前面“项目仍处于骨架阶段”的旧描述。当前工程已经不只是占位文件，已经有可运行主场景和多条系统线程的落地内容。

### 10.1 MCP 与工程状态

已通过 Godot MCP 确认：

```text
Godot 版本：4.6.stable.official.89cea1439
项目路径：D:\Godot\Stardew Valley\stardew-valley
当前统计：17 个场景、39 个脚本、99 个资源
主场景：scenes/world/Farm.tscn
```

说明：本项目后续默认按 2D 项目处理。除非任务明确要求 3D，不需要调用 MeshLibrary、3D 节点、3D 物理或 3D 场景相关流程。

### 10.2 已经落地的内容

当前主场景 `scenes/world/Farm.tscn` 已经接入：

- `Node2D` 根节点，开启 Y-sort。
- `Ground` 下的多个 `TileMapLayer`：`GrassLayer`、`SoilLayer`、`WaterLayer`、`ShoveledLayer`。
- `Prop` 下的 `PropLayer` 和玩家实例。
- `Object` 下的房屋与售卖箱。
- `Gameplay` 下的 `FarmGrid`、`FarmMapController`、`SceneSpawnController`。
- `Player_UI`，包含 HUD 和背包面板入口。

玩家系统已经包括：

- `PlayerController.gd`
- `PlayerInteractor.gd`
- `ToolController.gd`
- `PlayerVisual.gd`
- `PlayerStateMachine.gd`
- `PlayerIdleState.gd`
- `PlayerMoveState.gd`
- `PlayerToolUseState.gd`
- `Camera2D`
- 工具使用动画与基础工具数据接线

农场格子系统已经包括：

- `FarmGrid.gd`
- `FarmTileState.gd`
- 世界坐标与格子坐标转换
- 从 `TileMapLayer` 对齐坐标
- 可耕种地块注册
- 锄地、浇水、播种、作物阶段、清除作物
- 导出/导入格子状态的基础结构

工具系统已经包括：

- `ToolData.gd`
- `resources/tools/axe.tres`
- `resources/tools/fishing_rod.tres`
- `resources/tools/shovel.tres`
- `resources/tools/watering_can.tres`
- 当前默认行为：`shovel` 调用 `FarmGrid.till_cell()`，`watering_can` 调用 `FarmGrid.water_cell()`

UI 与背包系统已经包括：

- `PlayerUi.tscn` / `PlayerUi.gd`
- `HUD.tscn` / `HUD.gd`
- `InventoryPanel.tscn` / `InventoryPanel.gd`
- `Slot.tscn` / `SlotUI.gd`
- `Inventory.gd`
- `ItemStack.gd`
- `TrashDropArea.gd`

物体与场景切换已经包括：

- `Door.tscn` / `Door.gd`
- `farmer_home.tscn`
- `FarmerHouseInterior.tscn`
- `SceneExitArea.gd`
- `SceneTransitionState.gd`
- `SceneSpawnController.gd`

### 10.3 仍然需要接线或完善的内容

以下内容虽然已有文件或场景，但还不能按完整农场闭环验收：

- `ShippingBin.gd` 目前主要是可交互和开合动画测试，售卖结算尚未完成。
- `ShopInventory.gd` 仍是商店库存与购买规则占位。
- `CropInstance.gd` 仍是运行时作物状态占位。
- `SaveManager.gd` 仍是存档编排占位。
- `GameState.gd` 仍是全局状态协调占位。
- 作物成长、收获、售卖、购买种子、睡觉进入下一天之间尚未形成完整闭环。
- UI 线程已有较多表现与背包结构，但需要和真实物品、工具、商店、售卖箱、时间系统继续对齐。

因此后续线程不应再按“全空项目”处理，而应基于现有实现做增量接线和修补。

## 11. 多线程与 Godot MCP 使用规范

### 11.1 线程是否会自动调用 MCP

不要默认每个线程都会自动调用 MCP。

当前环境中，Codex 可以正常调用 Godot MCP；但新开的并行线程是否会主动调用，取决于该线程是否拿到了 MCP 工具、任务提示是否明确要求、以及它是否判断场景/节点信息需要通过 Godot 校验。

为了稳定协作，后续分发线程时要明确写入：

```text
本线程必须主动使用 Godot MCP 检查工程状态；涉及场景、节点、资源 UID、运行验证时，优先使用 Godot MCP，而不是只靠猜测或纯文本改 .tscn。
```

这不是因为所有任务都必须用 MCP。纯 GDScript 逻辑、文档整理、简单资源列表检查，可以先用 `rg` 和文件读取完成。但只要涉及 Godot 场景结构、节点增删、场景保存、运行验证，就应该调用 MCP。

### 11.2 每个线程启动时必须做的事

每个线程开始开发前，先执行以下检查：

```text
1. 使用 Godot MCP 确认 Godot 版本和项目路径。
2. 读取 docs/project_shared_conventions.md。
3. 读取 docs/prototype_scope.md。
4. 读取自己负责系统的 docs/system_briefs/*.md。
5. 用 rg 检索自己负责的脚本、场景、资源，确认现状后再修改。
6. 如果要改场景或节点，先通过 MCP 或现有 .tscn 结构确认节点路径。
7. 完成后优先用 Godot MCP 运行相关场景并读取 debug 输出。
```

建议线程开头使用的 MCP 动作：

```text
get_godot_version
get_project_info(projectPath)
```

涉及场景和资源时优先使用：

```text
create_scene
add_node
load_sprite
save_scene
get_uid
update_project_uids
run_project
get_debug_output
```

2D 项目中通常不使用：

```text
export_mesh_library
MeshInstance3D
Node3D
CharacterBody3D
Area3D
CollisionShape3D
```

### 11.3 什么时候必须调用 MCP

以下情况要求线程主动调用 Godot MCP：

- 新建、保存或调整 `.tscn` 场景。
- 增加、删除或移动 Godot 节点。
- 给节点挂脚本、改导出变量、改节点路径引用。
- 处理 Godot 4.6 的 UID、资源引用、场景引用。
- 需要确认主场景、测试场景能否启动。
- 修改 `project.godot`、输入映射、自动加载、主题、主场景。
- 修改 TileMapLayer、玩家场景、UI 场景、交互物体场景后需要运行验证。

以下情况可以不强制调用 MCP，但完成后最好运行验证：

- 只改单个 `.gd` 逻辑文件。
- 只改 `.md` 文档。
- 只调整数据资源说明。
- 只读取项目结构或搜索代码。

### 11.4 线程输出必须包含 MCP 状态

每个线程完成任务时，最后要说明：

```text
是否调用 Godot MCP：是/否
调用了哪些 MCP 动作：例如 get_project_info、run_project、get_debug_output
是否运行了场景：是/否
如果没有运行，原因是什么
是否修改了共享核心文件
是否需要其他线程适配
```

这样可以避免多个线程都以为别人已经验证过场景。

## 12. 后续分发线程的通用提示模板

后续开新线程时，可以直接把下面模板复制给线程，然后补上具体系统名称。

```text
你负责【系统名称】线程，项目是 Godot 4.6 的 2D 类星露谷农场原型。

开始前必须：
1. 主动调用 Godot MCP，确认 Godot 版本和项目路径。
2. 阅读 docs/project_shared_conventions.md。
3. 阅读 docs/prototype_scope.md。
4. 阅读 docs/system_briefs/【对应系统】.md。
5. 用 rg 搜索现有脚本、场景和资源，不要按空项目重新设计。

开发要求：
- 默认忽略 3D，不要引入 Node3D、MeshInstance3D、CharacterBody3D、Area3D 或 MeshLibrary。
- 场景节点改动优先通过 Godot MCP 或 Godot 识别的场景结构完成。
- 代码改动要贴合现有目录和接口，不要重写无关系统。
- 不要随意修改共享核心文件；如果必须修改，要先说明接口影响。
- GDScript 中来自 Dictionary.get()、get_node_or_null()、Resource.get()、无类型对象调用的值要显式标注类型。

完成后必须：
1. 用 Godot MCP 运行相关场景或说明为什么无法运行。
2. 读取 debug 输出。
3. 汇报修改文件、验证结果、剩余风险、需要其他线程适配的接口。
```

## 13. 现阶段建议的下一步优先级

当前项目不应再继续分散做“更多占位文件”。建议进入接线和闭环阶段：

1. 先确认主场景 `scenes/world/Farm.tscn` 可以稳定运行，并记录当前报错。
2. 将 `FarmMapController`、`FarmGrid`、`ToolController` 的坐标规则统一，保证工具命中地块准确。
3. 把背包快捷栏的工具/种子选择与 `ToolController` 接通，避免工具系统和 UI 各选各的。
4. 完成播种：种子物品 -> 作物数据 -> `FarmGrid.plant_crop()` -> 可见作物节点或 TileMapLayer 表现。
5. 完成睡觉进入下一天：床/门交互 -> `TimeManager.start_next_day()` -> 清水状态 -> 作物成长。
6. 完成收获：成熟作物 -> 背包物品。
7. 完成售卖箱：投入物品 -> 睡觉后结算金币。
8. 完成商店：金币购买种子 -> 背包增加种子。
9. 最后接 `SaveManager`，保存日期、金币、背包、格子、作物状态。

并行线程继续开发时，优先围绕这些接口对齐，不要再各自新建一套平行系统。
