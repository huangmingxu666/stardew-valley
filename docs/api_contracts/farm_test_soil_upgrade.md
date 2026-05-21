# Farm_Test_Soil 场景集成交接

> 所属线程：地图/耕地测试场景线程  
> 主要场景：`scenes/Test/Farm_Test_soil.tscn`  
> 主要脚本：`scripts/farm/FarmTestSoilUpgradeController.gd`  
> 相关脚本：`scripts/farm/FarmMapController.gd`、`scripts/player/ToolController.gd`、`scripts/crops/CropRegistry.gd`、`scripts/core/SceneTransitionState.gd`

---

## 1. 本线程负责范围

本线程当前负责以下内容：

- `Farm_Test_soil` 测试场景的耕地等级模板切换
- 升级交互点（`Marker2D`）与黑色淡入淡出过渡
- 正式生效层 `ShoveledLayer` / `FenceLayer` 的模板拷贝
- `ShoveledLayer` 到 `FarmGrid` 的可耕地注册接线
- 测试场景内的种子播种入口
- 浇水后地块加深色的 `TileMapLayer` 叠色方案
- 切图/睡觉等过渡时的玩家输入锁接口补充

本线程**不负责**以下内容：

- 正式商人升级流程
- 通用经济 UI
- 作物完整成长数值设计
- 收获奖励入背包完整链路
- 存档恢复后的耕地等级持久化

---

## 2. 场景结构约定

### 2.1 `Farm_Test_soil.tscn` 中正式生效层

以下节点是运行时真正生效的层：

- `Ground/ShoveledLayer`
  说明：当前等级下的正式可耕地区来源层。`FarmGrid` 只从这里注册可耕格子。
- `Ground/FenceLayer`
  说明：当前等级下的正式围栏显示层。
- `Ground/WateredOverlayLayer`
  说明：浇水后深色覆盖层。仅做显示，不承载玩法数据。

### 2.2 模板层

以下节点只作为模板层，运行开始后会被缓存并 `clear()`：

- `Ground/Level1Layer/ShoveledLayer1`
- `Ground/Level1Layer/FenceLayer1`
- `Ground/Level2Layer/ShoveledLayer2`
- `Ground/Level2Layer/FenceLayer2`
- `Ground/Level3Layer/ShoveledLayer3`
- `Ground/Level3Layer/FenceLayer3`

后续若扩展更多等级，沿用相同命名即可：

```text
Ground/
  Level4Layer/
	ShoveledLayer4
	FenceLayer4
  Level5Layer/
	ShoveledLayer5
	FenceLayer5
```

控制器通过节点名中的数字自动排序，不需要额外注册。

### 2.3 升级交互点

- `Ground/Upgrade` 下的所有 `Marker2D` 都会被识别为升级交互点。
- 当前场景内已有：
  - `Ground/Upgrade/Upgrade_left`
  - `Ground/Upgrade/Upgrade_right`

是否能触发升级取决于：

- 玩家与任一升级点的距离
- `upgrade_enabled`
- 是否还有下一等级
- 是否正在升级
- 如果配置了 `upgrade_costs`，则还要求 `GameState.current_cash` 足够

---

## 3. FarmTestSoilUpgradeController 对外接口

### 3.1 信号

```gdscript
signal level_upgrade_started(from_level: int, to_level: int)
signal level_upgrade_completed(new_level: int)
signal level_changed(old_level: int, new_level: int)
signal upgrade_available(next_level: int)
signal upgrade_blocked(current_level: int)
signal fade_completed(is_visible: bool)
```

说明：

- `level_upgrade_started`
  升级序列真正开始时触发，输入已锁定。
- `level_changed`
  模板已经应用到正式层，`FarmGrid` 已同步。
- `level_upgrade_completed`
  淡出完成，输入已恢复。
- `upgrade_available`
  当前条件满足时可用于 UI 高亮或提示。
- `upgrade_blocked`
  触发升级但条件不满足时触发。
- `fade_completed`
  `true` 表示淡入完成，`false` 表示淡出完成。

### 3.2 方法

```gdscript
func can_upgrade() -> bool
func try_upgrade() -> bool
func get_current_level() -> int
func get_next_level() -> int
func get_max_level() -> int
func is_upgrading() -> bool
func has_reached_max_level() -> bool
func set_upgrade_enabled(enabled: bool) -> void
func apply_upgrade_level(level_number: int) -> bool
func play_fade_in(target_alpha: float = 1.0) -> Tween
func play_fade_out(target_alpha: float = 0.0) -> Tween
func get_fade_progress() -> float
func get_upgrade_cost(to_level: int) -> int
```

用途约定：

- 正式经济/商人线程应调用 `can_upgrade()`、`try_upgrade()`、`get_upgrade_cost()`
- 测试/调试线程可调用 `apply_upgrade_level()` 直接跳级
- `play_fade_in/out()` 仅用于重用本场景遮罩表现，不建议当作全局睡觉过渡接口

---

## 4. 播种测试入口

### 4.1 当前入口规则

当前 `Farm_Test_soil` 内已经接入测试播种逻辑：

- 选中快捷栏里的种子物品
- 按 `plant_action`
- 当前默认 `plant_action = &"use_left"`

脚本位置：

- `scripts/farm/FarmTestSoilUpgradeController.gd`
- 入口函数：`_handle_seed_plant_input(event: InputEvent) -> bool`

### 4.2 种子物品要求

当前播种逻辑依赖 `ItemData`：

```gdscript
item_kind == ItemData.ItemKind.SEED
metadata["crop_id"] = &"tomato_crop"
```

番茄种子资源路径：

- `resources/items/Plant/Tomato/tomato_seed.tres`

后续其它作物线程只要遵守相同约定，就能复用当前测试播种链路。

### 4.3 当前测试背包配置

`Farm_Test_soil` 运行时会被控制器重置成精简测试背包，只保留：

- `shovel`
- `watering_can`
- `bare_hands`
- `tomato_seed`
- 背包里少量 `tomato`

这部分仅用于测试场景，不应直接迁移到正式场景。

---

## 5. 与作物线程的接口

### 5.1 当前接法

当前 `Farm_Test_soil` 已挂：

- `Gameplay/CropRegistry`

升级/播种控制器通过：

```gdscript
@export_node_path("CropRegistry") var crop_registry_path: NodePath
```

接入作物系统。

### 5.2 当前调用入口

播种：

```gdscript
CropRegistry.plant_crop(crop_id: StringName, cell: Vector2i, planted_timestamp: int = 0) -> Dictionary
```

浇水：

```gdscript
CropRegistry.water_crop(cell: Vector2i) -> Dictionary
```

空手收获：

```gdscript
CropRegistry.harvest_crop(cell: Vector2i) -> Dictionary
```

铲除作物：

```gdscript
CropRegistry.destroy_crop(cell: Vector2i) -> Dictionary
```

### 5.3 当前已接但未完全跑通的点

当前 `CropRegistry` 已经能播种番茄，但**跨天成长尚未接入时间系统**。

目前项目里**没有地方调用**：

```gdscript
CropRegistry.advance_all_crops_day()
```

所以：

- 番茄可以播下
- 但睡觉跳天后不会自动长大

这是当前最重要的待补接口。

建议后续由作物线程或时间线程完成：

```gdscript
TimeManager.day_started -> CropRegistry.advance_all_crops_day()
TimeManager.day_started -> FarmGrid.clear_watered_tiles()
```

顺序建议：

1. 先 `advance_all_crops_day()`
2. 再 `clear_watered_tiles()`

---

## 6. 与 FarmGrid 的接口

### 6.1 当前正式来源层

`FarmMapController` 在测试场景中当前配置为：

```gdscript
tillable_source_layer_path = "../../Ground/ShoveledLayer"
```

即：

- `SoilLayer` 只是普通地表
- `ShoveledLayer` 决定哪些格子会被注册进 `FarmGrid`

### 6.2 升级时同步方式

升级控制器在模板层切换后会执行：

```gdscript
_sync_farm_grid_from_active_layer()
```

逻辑：

1. 保存旧格子状态
2. 读取正式 `ShoveledLayer` 的 `used_cells`
3. `FarmGrid.clear_all_tiles()`
4. 重新 `register_tillable_cells(...)`
5. 把旧的 `tilled / watered / crop_id / crop_stage / crop_max_stage` 尽量恢复到仍存在的格子上

### 6.3 依赖字段

当前恢复逻辑依赖 `FarmTileState` 字段：

- `tillable`
- `tilled`
- `watered`
- `blocked`
- `crop_id`
- `crop_stage`
- `crop_max_stage`

如果其它线程修改这些字段语义，需要同步更新升级控制器的恢复逻辑。

---

## 7. 与工具线程的接口

### 7.1 ToolController 当前已扩展

`scripts/player/ToolController.gd` 当前新增：

```gdscript
@export_node_path("CropRegistry") var crop_registry_path: NodePath
```

并已接入下列桥接：

- `TILL_SOIL`
  - 若目标格已有作物：优先 `crop_registry.destroy_crop(target_cell)`
  - 否则 `farm_grid.till_cell(target_cell)`
- `WATER_SOIL`
  - 优先 `crop_registry.water_crop(target_cell)`
  - 再 `farm_grid.water_cell(target_cell)`
- `HARVEST`
  - `crop_registry.harvest_crop(target_cell)`
- `DESTROY_CROP`
  - `crop_registry.destroy_crop(target_cell)`

### 7.2 当前约束

这套桥接默认依赖：

- 场景里有 `CropRegistry`
- `CropRegistry` 能找到同一个 `FarmGrid`

否则工具层虽然还能锄地/浇水，但不会正确处理作物。

---

## 8. 浇水深色显示方案

### 8.1 当前实现

测试场景新增：

- `Ground/WateredOverlayLayer`

升级控制器会监听：

```gdscript
FarmGrid.tile_state_changed(cell, tile_state)
```

并在满足以下条件时把同格 tile 复制到 `WateredOverlayLayer`：

```gdscript
tile_state.tilled == true
tile_state.watered == true
```

### 8.2 显示方式

当前不是换另一套专门的“湿土地” tile，而是：

- 复制 `ShoveledLayer` 的同格 tile
- 在 `WateredOverlayLayer` 上统一深褐色半透明 `modulate`

因此它本质上是：

> 按格子的 TileMap 叠色遮罩

而不是：

> 每格一个单独节点的遮罩

### 8.3 后续替换空间

如果后续美术线程补了湿土地素材，可以平滑替换成：

- 单独的 `watered soil` tile atlas
- 或者 `FarmMapController` 原本预留的 `watered_soil_source_id / atlas_coords` 方案

不需要改 `FarmGrid` 数据模型。

---

## 9. 与输入/过渡线程的接口

### 9.1 SceneTransitionState 当前对外可用接口

`scripts/core/SceneTransitionState.gd` 当前新增并已被本线程使用：

```gdscript
func lock_input_for_seconds(duration_seconds: float) -> void
func acquire_input_lock(reason: StringName = &"default") -> void
func release_input_lock(reason: StringName = &"default") -> void
func is_input_locked() -> bool
func handle_player_spawn(player: PlayerController) -> void
```

### 9.2 本线程使用方式

- 升级黑屏期间：
  - `SceneTransition.acquire_input_lock(&"farm_test_soil_upgrade")`
  - 完成后 `release_input_lock(...)`
- 播种逻辑会先检查：
  - `SceneTransition.is_input_locked()`

其它线程如需接商人对话、升级 UI、强制黑屏等，可复用这套锁输入接口。

---

## 10. 与时间/睡觉线程的接口

### 10.1 当前测试场景已放置

`Farm_Test_soil` 当前已添加：

- `Prop/TestBed`

它复用：

- `scenes/objects/Bed.tscn`
- `scripts/objects/Furniture/Bed/bed.gd`
- `SleepTransition.play_sleep_transition(self)`

### 10.2 当前限制

睡觉目前只会：

- 播放睡觉黑屏
- 调 `TimeManager.request_sleep_skip_to_next_day()`

但**不会自动推进作物成长**，原因见第 5 节。

---

## 11. 当前调试输出

本线程为了测试暂时保留了播种相关 `print`，主要在：

- `FarmTestSoilUpgradeController._handle_seed_plant_input()`
- `CropRegistry.plant_crop()`

包括：

- 当前选中的物品
- 目标格坐标
- 格子是否 `tillable / tilled / watered / has_crop`
- `CropRegistry` 成功或失败原因

后续在功能稳定后可以删除或改成统一 debug flag。

---

## 12. 已知未完成项

以下内容当前仍未完成：

1. `TimeManager` 未驱动 `CropRegistry.advance_all_crops_day()`
2. 播种后已确认逻辑成功，但若“图标不显示”，仍需进一步确认作物实例显示层/位置
3. 收获成功后的背包入账链路未在测试场景中完整验证
4. 升级成功/失败还没有正式 UI 提示，仅信号和黑屏过渡
5. `Player_UI2` 目前在测试场景里被打开用于测试，不代表正式场景最终显示策略

---

## 13. 其他线程接入建议

### 商人/经济线程

优先调用：

```gdscript
FarmTestSoilUpgradeController.can_upgrade()
FarmTestSoilUpgradeController.try_upgrade()
FarmTestSoilUpgradeController.get_upgrade_cost(level)
```

不要直接改 `ShoveledLayer/FenceLayer`。

### 作物线程

优先补：

```gdscript
TimeManager.day_started -> CropRegistry.advance_all_crops_day()
```

并确认 `CropInstance` 的第一帧在当前测试场景里可见。

### 工具线程

继续沿用当前 `ToolController -> CropRegistry/FarmGrid` 的桥接，不要再在工具层重复写一套作物逻辑。

### 地图/UI 线程

若要增强浇水表现，优先替换 `WateredOverlayLayer` 的来源素材，不要改 `FarmGrid` 数据接口。
