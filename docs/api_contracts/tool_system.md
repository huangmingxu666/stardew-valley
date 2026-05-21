# ToolController / ToolData 接口契约

> 所属系统：工具系统  
> 脚本路径：`scripts/player/ToolController.gd` / `scripts/data/ToolData.gd`  
> 资源路径：`resources/tools/*.tres`

---

## ToolAction 枚举

```gdscript
enum ToolAction {
	NONE        = 0,  # 无操作
	CHOP        = 1,  # 斧头砍伐（暂未落地玩法）
	TILL_SOIL   = 2,  # 锄地 / 铲除作物（智能路由：有作物→摧毁，无作物→锄地）
	WATER_SOIL  = 3,  # 浇水（同步作用于土壤和作物）
	FISH        = 4,  # 钓鱼（暂未落地玩法）
	HARVEST     = 5,  # 收获成熟作物（空手）
	DESTROY_CROP= 6,  # 显式铲除作物
}
```

---

## 工具落地行为路由表

| primary_action | CropRegistry 有作物 | CropRegistry 无作物 | FarmGrid 行为 |
|:---|:---|:---|:---|
| `TILL_SOIL` | 调用 `crop_registry.destroy_crop(cell)` | 调用 `farm_grid.till_cell(cell)` | — |
| `WATER_SOIL` | 调用 `crop_registry.water_crop(cell)` | — | 同时调用 `farm_grid.water_cell(cell)` |
| `HARVEST` | 调用 `crop_registry.harvest_crop(cell)` | 返回 `success: false` | — |
| `DESTROY_CROP` | 调用 `crop_registry.destroy_crop(cell)` | 返回 `success: false` | — |

---

## 工具资源配置

| 工具 ID | 文件 | primary_action | slot_index |
|:---|:---|:---|:---|
| `shovel` | `resources/tools/shovel.tres` | `TILL_SOIL (2)` | 2 |
| `watering_can` | `resources/tools/watering_can.tres` | `WATER_SOIL (3)` | 3 |
| `bare_hands` | `resources/tools/bare_hands.tres` | `HARVEST (5)` | -1 (无槽位) |
| `axe` | `resources/tools/axe.tres` | `CHOP (1)` | 0 |
| `fishing_rod` | `resources/tools/fishing_rod.tres` | `FISH (4)` | 1 |

---

## ToolController 对外暴露信号 (Signals)

### `selected_tool_changed(tool_id: StringName)`
当前选中工具 ID 变更时触发。

### `selected_tool_data_changed(tool_data: ToolData)`
当前选中工具数据变更时触发（携带完整 ToolData）。

### `tool_use_requested(tool_data: ToolData, target_cell: Vector2i, target_world_position: Vector2)`
工具使用请求发出时触发（在落地行为执行前）。角色动画线程应监听此信号。

### `tool_used(tool_data: ToolData, target_cell: Vector2i, success: bool)`
工具落地行为执行完毕后触发。`success` 反映实际操作是否成功。

---

## ToolController 对外暴露方法 (Public Methods)

### 工具选择

```gdscript
func select_tool_by_slot(slot_index: int) -> void
func select_tool_by_id(tool_id: StringName) -> void
func clear_selected_tool() -> void
```

### 工具查询

```gdscript
func get_selected_tool_id() -> StringName
func get_selected_tool_data() -> ToolData
func get_tool_data(tool_id: StringName) -> ToolData
func get_ordered_tools() -> Array[ToolData]
func has_tool(tool_id: StringName) -> bool
```

### 目标坐标

```gdscript
func get_target_cell() -> Vector2i
func get_target_world_position() -> Vector2
```

### 工具使用

```gdscript
func use_current_tool() -> bool
```
执行当前选中工具的落地行为。内部调用 `_apply_default_tool_action()` 并按上表路由。

---

## 依赖的外部接口（本系统消费）

| 来源 | 方法 | 用途 |
|:---|:---|:---|
| `FarmGrid` | `till_cell(cell) -> bool` | 锄地 |
| `FarmGrid` | `water_cell(cell) -> bool` | 浇水（土壤层） |
| `CropRegistry` | `has_crop_at(cell) -> bool` | 检测格子是否有作物 |
| `CropRegistry` | `water_crop(cell) -> Dictionary` | 为作物浇水 |
| `CropRegistry` | `harvest_crop(cell) -> Dictionary` | 收获成熟作物 |
| `CropRegistry` | `destroy_crop(cell) -> Dictionary` | 铲除作物 |
| `PlayerController` | `get_target_tile_at_distance(dist) -> Vector2i` | 获取目标格子坐标 |
| `PlayerController` | `get_target_world_position_at_distance(dist) -> Vector2` | 获取目标世界坐标 |
| `PlayerController` | `is_tool_use_locked() -> bool` | 检测工具是否被锁定 |
| `PlayerController` | `set_selected_tool_data(data) -> void` | 同步工具视觉 |

---

## 导出配置参数

| 变量 | 类型 | 说明 |
|:---|:---|:---|
| `tool_definitions` | `Array[ToolData]` | 手动配置的工具列表（非空时跳过自动加载） |
| `farm_grid_path` | `NodePath` | 指向 FarmGrid 节点 |
| `crop_registry_path` | `NodePath` | 指向 CropRegistry 节点 |
| `starting_tool_id` | `StringName` | 初始选中工具 ID（空则无工具） |
| `use_legacy_slot_input` | `bool` | 是否启用旧版快捷键切换工具 |
