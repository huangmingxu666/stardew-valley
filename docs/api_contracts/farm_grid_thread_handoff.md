# 格子系统线程交接说明

> 线程职责：农场玩法格子系统  
> 更新时间：2026-05-17  
> 适用对象：地图线程、工具线程、作物线程、时间线程、存档线程、玩家交互线程

---

## 1. 当前线程产物

本线程当前负责并已落地的文件：

- `scripts/farm/FarmTileState.gd`
- `scripts/farm/FarmGrid.gd`
- `scripts/farm/FarmMapController.gd`
- `scenes/world/Farm.tscn` 中的 `Gameplay/FarmGrid`
- `scenes/world/Farm.tscn` 中的 `Gameplay/FarmMapController`

与本线程直接相关、但不归本线程主导的接线点：

- `scripts/player/PlayerController.gd`
- `scripts/player/ToolController.gd`

---

## 2. 当前场景接线状态

当前 `Farm.tscn` 内已存在以下玩法节点：

```text
Farm
└── Gameplay
    ├── FarmGrid
    └── FarmMapController
```

当前默认配置：

- `FarmGrid.coordinate_layer_path -> ../../Ground/GrassLayer`
- `FarmMapController.farm_grid_path -> ../FarmGrid`
- `FarmMapController.coordinate_layer_path -> ../../Ground/GrassLayer`
- `FarmMapController.tillable_source_layer_path -> ../../Ground/SoilLayer`

这意味着：

- 格子坐标换算以 `Ground/GrassLayer` 为参考。
- 可耕种区域默认从 `Ground/SoilLayer` 的已用格子初始化。
- 地图线程可以继续手工改 `GrassLayer` / `SoilLayer`，格子线程不依赖旧 `TileMap`。

---

## 3. 本线程对外输出接口

### 3.1 核心数据对象

`FarmTileState` 是单格玩法状态的统一数据结构，字段包括：

- `cell`
- `surface_type`
- `tillable`
- `tilled`
- `watered`
- `blocked`
- `crop_id`
- `crop_stage`
- `crop_max_stage`

关键能力：

- `can_till()`
- `can_water()`
- `can_plant()`
- `can_harvest()`
- `can_destroy_crop()`
- `has_crop()`
- `is_crop_mature()`
- `to_dictionary()`
- `from_dictionary(data)`

### 3.2 FarmGrid 公共接口

坐标换算：

```gdscript
func world_to_cell(world_position: Vector2) -> Vector2i
func cell_to_world(cell: Vector2i, centered: bool = true) -> Vector2
```

格子注册：

```gdscript
func register_tillable_rect(area: Rect2i, surface_type: StringName = &"") -> void
func register_tillable_cells(cells: Array[Vector2i], surface_type: StringName = &"") -> void
func register_tile(cell: Vector2i, tillable: bool = false, surface_type: StringName = &"", blocked: bool = false) -> FarmTileState
```

格子查询：

```gdscript
func has_tile(cell: Vector2i) -> bool
func get_tile_state(cell: Vector2i) -> FarmTileState
func get_or_create_tile_state(cell: Vector2i) -> FarmTileState
func get_all_cells() -> Array[Vector2i]
func get_tillable_cells() -> Array[Vector2i]
func is_cell_tillable(cell: Vector2i) -> bool
func is_cell_blocked(cell: Vector2i) -> bool
```

地面玩法：

```gdscript
func can_till_cell(cell: Vector2i) -> bool
func till_cell(cell: Vector2i) -> bool
func clear_tilled_cell(cell: Vector2i) -> bool
func can_water_cell(cell: Vector2i) -> bool
func water_cell(cell: Vector2i) -> bool
func clear_watered_tiles() -> void
```

作物格同步：

```gdscript
func can_plant_crop(cell: Vector2i) -> bool
func plant_crop(cell: Vector2i, crop_id: StringName, crop_stage: int = 0, crop_max_stage: int = FarmTileState.STAGE_NONE) -> bool
func set_crop_stage(cell: Vector2i, crop_stage: int) -> bool
func clear_crop(cell: Vector2i) -> bool
func can_harvest_crop(cell: Vector2i) -> bool
func harvest_crop(cell: Vector2i) -> Dictionary
func can_destroy_crop(cell: Vector2i) -> bool
func destroy_crop(cell: Vector2i) -> Dictionary
```

属性修改与存档：

```gdscript
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void
func set_cell_tillable(cell: Vector2i, tillable: bool) -> void
func set_surface_type(cell: Vector2i, surface_type: StringName) -> void
func export_state() -> Array[Dictionary]
func import_state(entries: Array[Dictionary], clear_existing: bool = true) -> void
```

### 3.3 FarmGrid 输出信号

```gdscript
signal tile_registered(cell: Vector2i, tile_state: FarmTileState)
signal tile_state_changed(cell: Vector2i, tile_state: FarmTileState)
signal grid_initialized()
signal watered_tiles_cleared()
signal crop_planted(cell: Vector2i, crop_id: StringName)
signal crop_harvested(cell: Vector2i, crop_id: StringName, harvest_item_id: StringName, yield_count: int)
signal crop_destroyed(cell: Vector2i, crop_id: StringName)
```

---

## 4. 与其它线程的对接方式

### 4.1 地图线程

地图线程只需要保证两件事：

- `FarmMapController.coordinate_layer_path` 指向正确的坐标参考层。
- `FarmMapController.tillable_source_layer_path` 指向你想作为“可耕地初始化来源”的 `TileMapLayer`。

约定：

- `TileMapLayer` 只负责显示。
- 真正的玩法状态只看 `FarmGrid`。
- 如果地图线程重做了 `SoilLayer` 的布局，`FarmGrid` 初始化区域会随之变化。

可选配置：

- 如果未来要让格子系统接管土壤视觉覆盖，可以打开 `FarmMapController.manage_soil_visuals`。
- 目前该选项默认关闭，不会覆盖你现有地图表现。

### 4.2 工具线程

工具线程现在应只调用 `FarmGrid`，不要自己判断地块合法性。

当前已接好的调用关系：

- `ToolController` 使用 `player.get_target_tile_at_distance()`
- `ToolController` 对 `TILL_SOIL` 调用 `farm_grid.till_cell()`
- `ToolController` 对 `WATER_SOIL` 调用 `farm_grid.water_cell()`

推荐继续沿用：

```gdscript
var target_cell: Vector2i = player.get_target_tile_at_distance(tool_data.interaction_distance)
farm_grid.till_cell(target_cell)
farm_grid.water_cell(target_cell)
```

不要再自行写：

```gdscript
Vector2i(floor(world.x / 32.0), floor(world.y / 32.0))
```

因为统一换算应走 `PlayerController` 或 `FarmGrid`。

### 4.3 作物线程

作物线程与格子系统的接口边界已经预留好：

- 播种后调用 `plant_crop()`
- 生长推进后调用 `set_crop_stage()`
- 作物移除后调用 `clear_crop()`
- 或者直接用 `harvest_crop()` / `destroy_crop()` 走格子内建结果

推荐接法：

```gdscript
farm_grid.plant_crop(cell, crop_id, 0, max_stage)
farm_grid.set_crop_stage(cell, next_stage)
farm_grid.clear_crop(cell)
```

成熟判定目前基于：

- `crop_stage`
- `crop_max_stage`

也就是格子系统只保存“轻量同步状态”，不替代完整作物实例逻辑。

### 4.4 时间线程

跨天时需要调用：

```gdscript
farm_grid.clear_watered_tiles()
```

作用：

- 清除所有地块的 `watered` 标记
- 发射 `watered_tiles_cleared()`

如果作物系统也依赖浇水状态推进，建议顺序是：

1. 作物线程先读取今天的浇水状态并推进成长
2. 时间线程再调用 `farm_grid.clear_watered_tiles()`

### 4.5 存档线程

格子系统已经准备好导入导出：

```gdscript
var entries: Array[Dictionary] = farm_grid.export_state()
farm_grid.import_state(entries, true)
```

当前导出内容包括：

- 地块坐标
- 表面类型
- 是否可耕种
- 是否已锄地
- 是否已浇水
- 是否阻挡
- 当前作物 ID
- 当前作物阶段
- 作物成熟阶段上限

这意味着存档线程不需要读取 `TileMapLayer`，直接保存 `FarmGrid.export_state()` 即可。

### 4.6 玩家 / 交互线程

玩家目标格目前已经做了“三分之一阈值前移”：

- 文件：`scripts/player/PlayerController.gd`
- 参数：`target_tile_advance_ratio = 0.33`

可用接口：

```gdscript
func get_target_tile() -> Vector2i
func get_target_tile_at_distance(distance: float) -> Vector2i
func get_target_world_position_at_distance(distance: float) -> Vector2
```

当前工具判定、黄色调试框、格子交互目标已经统一使用这套逻辑。

---

## 5. 当前线程消费的外部依赖

本线程主动依赖但不拥有的对象：

- `TileMapLayer.local_to_map()`
- `TileMapLayer.map_to_local()`
- `TileMapLayer.get_used_cells()`
- `CropInstance.ACTION_HARVEST`
- `CropInstance.ACTION_DESTROY`
- `PlayerController` 仅由 `FarmMapController` 在出生点对齐时引用

说明：

- 如果 `CropInstance` 的动作常量命名变更，`FarmGrid.harvest_crop()` / `destroy_crop()` 的返回字典需要同步调整。
- 如果地图线程替换坐标参考层，`coordinate_layer_path` 需要同步更新。

---

## 6. 当前限制与未完成项

当前已完成：

- 玩法格子数据源独立于 `TileMapLayer`
- 地图区域初始化
- 32x32 坐标换算
- 锄地 / 浇水 / 作物占用状态
- 存档导入导出
- 基础场景接线

当前未完成或默认关闭：

- `manage_soil_visuals` 视觉覆盖层自动刷新
- 障碍自动从碰撞层批量烘焙进 `blocked`
- 多种地表规则差异化
- 基于作物数据的真实掉落物映射
- 自动化测试

---

## 7. 建议其它线程直接依赖的最小接口

如果其它线程只想拿稳定接口，优先只依赖下面这些：

```gdscript
# 坐标
farm_grid.world_to_cell(world_position)
farm_grid.cell_to_world(cell)

# 地块操作
farm_grid.till_cell(cell)
farm_grid.water_cell(cell)
farm_grid.can_plant_crop(cell)
farm_grid.plant_crop(cell, crop_id, stage, max_stage)
farm_grid.set_crop_stage(cell, stage)
farm_grid.clear_crop(cell)

# 存档
farm_grid.export_state()
farm_grid.import_state(entries)
```

这套接口是当前最稳定、最不容易因为视觉层调整而受影响的部分。
