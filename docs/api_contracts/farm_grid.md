# FarmGrid 接口契约

> 所属系统：农场格子  
> 脚本路径：`scripts/farm/FarmGrid.gd` / `scripts/farm/FarmTileState.gd`

---

## 对外暴露信号 (Signals)

### `tile_registered(cell: Vector2i, tile_state: FarmTileState)`
格子首次被注册到格子系统时触发。

### `tile_state_changed(cell: Vector2i, tile_state: FarmTileState)`
格子任何状态变化时触发（包括地面状态、作物状态）。

### `grid_initialized()`
格子初始化完成时触发。

### `watered_tiles_cleared()`
所有浇水状态被清除时触发（通常用于跨天重置）。

### `crop_planted(cell: Vector2i, crop_id: StringName)`
作物被种植到格子上时触发。

### `crop_harvested(cell: Vector2i, crop_id: StringName, harvest_item_id: StringName, yield_count: int)`
作物被收获时触发。

### `crop_destroyed(cell: Vector2i, crop_id: StringName)`
作物被铲除时触发。

---

## FarmGrid 对外暴露方法 (Public Methods)

### 坐标转换

```gdscript
func world_to_cell(world_position: Vector2) -> Vector2i
func cell_to_world(cell: Vector2i, centered: bool = true) -> Vector2
```

### 格子注册

```gdscript
func register_tillable_rect(area: Rect2i, surface_type: StringName = &"") -> void
func register_tillable_cells(cells: Array[Vector2i], surface_type: StringName = &"") -> void
func register_tile(cell: Vector2i, tillable: bool = false, surface_type: StringName = &"", blocked: bool = false) -> FarmTileState
```

### 格子查询

```gdscript
func has_tile(cell: Vector2i) -> bool
func get_tile_state(cell: Vector2i) -> FarmTileState
func get_or_create_tile_state(cell: Vector2i) -> FarmTileState
func get_all_cells() -> Array[Vector2i]
func get_tillable_cells() -> Array[Vector2i]
func is_cell_tillable(cell: Vector2i) -> bool
func is_cell_blocked(cell: Vector2i) -> bool
```

### 地面操作（锄地/浇水）

```gdscript
func can_till_cell(cell: Vector2i) -> bool
func till_cell(cell: Vector2i) -> bool
func clear_tilled_cell(cell: Vector2i) -> bool           # 重置地面状态（含作物）
func can_water_cell(cell: Vector2i) -> bool
func water_cell(cell: Vector2i) -> bool
func clear_watered_tiles() -> void                       # 清除所有浇水状态
```

### 作物操作（种植/生长/收获/铲除）

```gdscript
func can_plant_crop(cell: Vector2i) -> bool
func plant_crop(cell: Vector2i, crop_id: StringName, crop_stage: int = 0, crop_max_stage: int = FarmTileState.STAGE_NONE) -> bool
func set_crop_stage(cell: Vector2i, crop_stage: int) -> bool
func clear_crop(cell: Vector2i) -> bool                  # 仅清除作物数据（不改变地面状态）
func can_harvest_crop(cell: Vector2i) -> bool
func harvest_crop(cell: Vector2i) -> Dictionary          # 收获成熟作物，返回 {success, action, crop_id, crop_item_id, yield_count, cell_x, cell_y}
func can_destroy_crop(cell: Vector2i) -> bool
func destroy_crop(cell: Vector2i) -> Dictionary          # 铲除作物，返回 {success, action, crop_id, cell_x, cell_y}
```

### 格子属性设置

```gdscript
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void
func set_cell_tillable(cell: Vector2i, tillable: bool) -> void
func set_surface_type(cell: Vector2i, surface_type: StringName) -> void
```

### 序列化

```gdscript
func export_state() -> Array[Dictionary]
func import_state(entries: Array[Dictionary], clear_existing: bool = true) -> void
```

---

## FarmTileState 对外暴露

### 常量

```gdscript
const SURFACE_GRASS: StringName = &"grass"
const SURFACE_SOIL: StringName = &"soil"
const SURFACE_WATER: StringName = &"water"
const STAGE_NONE: int = -1
```

### 状态字段

```gdscript
@export var cell: Vector2i
@export var surface_type: StringName
@export var tillable: bool
@export var tilled: bool
@export var watered: bool
@export var blocked: bool
@export var crop_id: StringName               # 当前作物 ID，空串表示无作物
@export var crop_stage: int                   # 当前生长阶段（0-based），STAGE_NONE 表示无作物
@export var crop_max_stage: int               # 成熟所需最大阶段（0-based），STAGE_NONE 表示未设置
```

### 状态查询

```gdscript
func can_till() -> bool                       # tillable && !blocked && !tilled && !has_crop
func can_water() -> bool                      # tilled && !blocked
func can_plant() -> bool                      # tilled && !blocked && !has_crop
func can_harvest() -> bool                    # tilled && !blocked && has_crop && is_crop_mature
func can_destroy_crop() -> bool               # has_crop
func has_crop() -> bool                       # crop_id != &""
func is_crop_mature() -> bool                 # crop_max_stage > STAGE_NONE && crop_stage >= crop_max_stage
```

### 状态变更

```gdscript
func set_crop(next_crop_id: StringName, next_crop_stage: int = 0, next_max_stage: int = STAGE_NONE) -> void
func clear_crop() -> void
func reset_for_new_day() -> void              # watered = false
func reset_ground_state() -> void             # tilled = false, watered = false, clear_crop
```

### 序列化

```gdscript
func duplicate_state() -> FarmTileState
func to_dictionary() -> Dictionary
static func from_dictionary(data: Dictionary) -> FarmTileState
```

---

## 依赖的外部接口（本系统消费）

| 来源 | 方法/常量 | 用途 |
|------|----------|------|
| `CropInstance` | `ACTION_HARVEST`, `ACTION_DESTROY` | 收获/铲除结果字典中的 action 字段 |

---

## 工具系统接入指南

当 `ToolController` 执行工具动作需要与 FarmGrid 交互时，建议的映射关系：

| ToolAction | FarmGrid 方法 | 说明 |
|-----------|--------------|------|
| `TILL_SOIL` | `till_cell()` | 锄地 |
| `WATER_SOIL` | `water_cell()` | 浇水 |
| （新添加）HARVEST | `harvest_crop()` | 空手收获成熟作物 |
| （新添加）DESTROY_CROP | `destroy_crop()` | 铲除未成熟作物 |

作物系统接入指南：

| 操作 | FarmGrid 方法 | 说明 |
|------|-------------|------|
| 播种 | `plant_crop(cell, crop_id, 0, max_stage)` | 传入 `crop_max_stage` 以支持成熟判定 |
| 每日成长 | `set_crop_stage(cell, new_stage)` | 作物系统每日推进后更新格子阶段 |
