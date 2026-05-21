# 作物系统 接口契约

> 所属系统：作物系统  
> 脚本路径：`scripts/crops/CropRegistry.gd`、`scripts/crops/CropInstance.gd`  
> 数据资源：`scripts/data/CropData.gd`  
> 场景：`scenes/crops/Crop.tscn`  
> 示例资源：`resources/crops/tomato_crop.tres`

---

## 一、架构概览

作物系统由三层组成：

| 层级 | 文件 | 职责 |
|------|------|------|
| 数据层 | `CropData.gd` | 配置驱动：生长帧数、帧-天数映射、产量等 |
| 实例层 | `CropInstance.gd` | 运行时状态：当前帧、浇水状态、成熟判定、收获/摧毁 |
| 管理层 | `CropRegistry.gd` | 全局注册：工具交互入口、格子同步、存档导入导出 |

**核心数据流：**

```text
ToolController → CropRegistry.handle_tool_action() → CropInstance.harvest/water/destroy
													  → FarmGrid.plant_crop/clear_crop/set_crop_stage
													  → signal: crop_planted / crop_removed / tool_action_completed

TimeManager   → CropRegistry.advance_all_crops_day() → CropInstance.advance_day()
													  → FarmGrid.set_crop_stage()
```

---

## 二、CropRegistry 对外接口

> 脚本路径：`scripts/crops/CropRegistry.gd`  
> 场景节点类型：`Node`

### 2.1 对外暴露信号 (Signals)

#### `crop_planted(cell: Vector2i, crop_id: StringName, planted_timestamp: int)`

播种操作成功且格子状态已同步后触发。**格子系统应监听此信号以刷新视觉层。**

| 参数 | 类型 | 说明 |
|------|------|------|
| `cell` | `Vector2i` | 播种的格子坐标 |
| `crop_id` | `StringName` | 作物数据ID（如 `&"tomato_crop"`） |
| `planted_timestamp` | `int` | Unix时间戳，用于存档一致性校验 |

#### `crop_removed(cell: Vector2i, crop_id: StringName)`

作物被收获（非再生型）或摧毁时触发。格子系统可据此清理地块状态。

#### `tool_action_completed(action: StringName, cell: Vector2i, result: Dictionary)`

每次工具操作完成后触发，携带标准化结果。工具线程可监听此信号获取反馈。

| 参数 | 类型 | 说明 |
|------|------|------|
| `action` | `StringName` | `&"harvest"`、`&"water"`、`&"destroy"` |
| `cell` | `Vector2i` | 目标格子坐标 |
| `result` | `Dictionary` | 标准化操作结果（结构见 2.2） |

---

### 2.2 工具交互接口（核心）

```gdscript
func handle_tool_action(tool_id: StringName, cell: Vector2i) -> Dictionary
```

**这是工具线程与作物系统交互的唯一切入点。** 接收工具ID，自动解析操作类型，委托给对应 CropInstance。

#### 工具ID到操作的映射表

| `tool_id` | 常量 | 解析的操作 | 说明 |
|-----------|------|-----------|------|
| `&""` | `TOOL_HAND` | `harvest` | 空手/无工具 → 收获 |
| `&"watering_can"` | `TOOL_WATERING_CAN` | `water` | 水壶 → 浇水 |
| `&"shovel"` | `TOOL_SHOVEL` | `destroy` | 铲子 → 摧毁作物 |
| 其他 | — | → 返回错误 | 未识别的工具ID |

#### 返回值结构 (成功)

```gdscript
# 收获成功
{
	"success": true,
	"action": "harvest",
	"crop_id": "tomato_crop",
	"crop_item_id": "tomato",       # 收获产物的物品ID
	"yield_count": 1,               # 本次收获数量
	"cell_x": 5,                    # 格子X坐标
	"cell_y": 3,                    # 格子Y坐标
	"regrowable": false             # 是否为可再生作物
}

# 浇水成功
{
	"success": true,
	"action": "water",
	"crop_id": "tomato_crop",
	"cell_x": 5,
	"cell_y": 3
}

# 摧毁成功
{
	"success": true,
	"action": "destroy",
	"crop_id": "tomato_crop",
	"cell_x": 5,
	"cell_y": 3
}

# 铲子对无作物格子（不视为错误）
{
	"success": true,
	"action": "destroy",
	"cell_x": 5,
	"cell_y": 3,
	"note": "cell_has_no_crop"
}
```

#### 返回值结构 (失败)

| `error_code` | `error_message` | 触发条件 |
|-------------|-----------------|---------|
| `"unknown_tool"` | `"未识别的工具: xxx"` | `tool_id` 不在映射表中 |
| `"no_crop_at_cell"` | `"该格子没有作物"` | 目标格子无 CropInstance（非铲子操作） |
| `"crop_not_mature"` | `"作物尚未成熟，无法收获"` | 收获操作时作物未成熟 |
| `"crop_already_dead"` | `"作物已不存在"` | 对已死亡作物重复操作 |
| `"no_crop_data"` | `"作物数据缺失"` | CropInstance 的 crop_data 为 null |

```gdscript
# 失败示例
{
	"success": false,
	"error_code": "crop_not_mature",
	"error_message": "作物尚未成熟，无法收获"
}
```

#### 便捷方法

以下方法是 `handle_tool_action` 的语义化封装，返回相同结构：

```gdscript
func water_crop(cell: Vector2i) -> Dictionary      # 等价 handle_tool_action(&"watering_can", cell)
func harvest_crop(cell: Vector2i) -> Dictionary     # 等价 handle_tool_action(&"", cell)
func destroy_crop(cell: Vector2i) -> Dictionary     # 等价 handle_tool_action(&"shovel", cell)
```

---

### 2.3 播种接口

```gdscript
func plant_crop(crop_data_id: StringName, cell: Vector2i, planted_timestamp: int = 0) -> Dictionary
```

执行完整的播种流程：校验格子 → 实例化作物场景 → 同步 FarmGrid → 发射 `crop_planted`。

#### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `crop_data_id` | `StringName` | 作物数据ID，如 `&"tomato_crop"` |
| `cell` | `Vector2i` | 目标格子坐标 |
| `planted_timestamp` | `int` | 播种时间戳（传0则由系统自动填入当前时间） |

#### 返回值

```gdscript
# 成功
{
	"success": true,
	"action": "plant",
	"crop_id": "tomato_crop",
	"cell_x": 5,
	"cell_y": 3,
	"planted_timestamp": 1715000000
}

# 失败 — error_code 对照表
# "unknown_crop"       — crop_data_id 未在注册表中找到
# "no_farm_grid"       — CropRegistry 未绑定 FarmGrid
# "cell_not_plantable" — 格子不可播种（未开垦、已占用、被阻挡）
# "cell_occupied"      — 该格子已有作物实例
# "instantiate_failed" — 作物场景实例化失败
```

---

### 2.4 生长日推进接口

```gdscript
func advance_all_crops_day() -> void
```

遍历所有活跃作物实例，对当日已浇水的作物推进一天生长。由时间系统（`TimeManager`）在新的一天开始时调用。

**调用顺序约束：** 必须在 `FarmGrid.clear_watered_tiles()` **之前**调用，以确保浇水状态在推进前被正确读取。

---

### 2.5 查询接口

```gdscript
func get_crop_data(crop_id: StringName) -> CropData
```
根据ID获取作物数据资源。返回 `null` 表示未注册。

```gdscript
func get_all_crop_ids() -> Array[StringName]
```
获取所有已注册作物数据ID列表。

```gdscript
func get_crop_instance(cell: Vector2i) -> CropInstance
```
获取指定格子的作物运行时实例。返回 `null` 表示该格子无作物。

```gdscript
func has_crop_at(cell: Vector2i) -> bool
```
判断指定格子是否存在活跃作物实例。

```gdscript
func get_all_crop_cells() -> Array[Vector2i]
```
获取所有存在作物的格子坐标列表。

---

### 2.6 数据管理接口

```gdscript
func load_crop_resource(resource_path: String) -> CropData
```
从 `.tres` 路径加载并注册作物数据资源。

```gdscript
func register_crop_data(crop_data: CropData) -> void
```
运行时注册一个已加载的作物数据资源。

---

### 2.7 存档接口

```gdscript
func export_state() -> Array[Dictionary]
```
导出所有作物实例的存档状态。每个元素即为 `CropInstance.get_save_state()` 的输出。

```gdscript
func import_state(entries: Array[Dictionary]) -> void
```
从存档数据恢复所有作物实例。会**先清空**当前所有实例再逐个恢复。未知的 `crop_id` 将被跳过并打印警告。

---

## 三、CropInstance 对外接口

> 脚本路径：`scripts/crops/CropInstance.gd`  
> 场景根节点类型：`Node2D`（含 `CropInstance` 脚本）

### 3.1 信号

| 信号 | 参数 | 触发时机 |
|------|------|---------|
| `growth_advanced` | `crop_id: StringName, cell: Vector2i, current_frame: int, total_frames: int` | 生长帧发生变化 |
| `crop_matured` | `crop_id: StringName, cell: Vector2i` | 作物达到完全成熟状态 |
| `crop_harvested` | `crop_id: StringName, cell: Vector2i, crop_item_id: StringName, yield_count: int` | 收获操作完成 |
| `crop_destroyed` | `crop_id: StringName, cell: Vector2i` | 摧毁操作完成 |
| `crop_watered` | `crop_id: StringName, cell: Vector2i` | 当日浇水完成 |

### 3.2 公开方法

```gdscript
func initialize(p_crop_data: CropData, p_cell: Vector2i, p_planted_time: int = 0) -> void
```
初始化作物实例。设置数据、坐标、时间戳；若配置了 `seed_texture`，播种当天先显示独立种子态。

```gdscript
func advance_day() -> void
```
推进一天结算。若 `watered_today == true` 则推进一天生长并重置连续缺水计数；若当前仍处于独立种子态，则第一次浇水后的次日切入生长序列第0帧。若未浇水则只累计连续缺水天数，不推进生长。

```gdscript
func water() -> bool
```
标记当日已浇水。返回 `false` 表示作物已死亡或数据缺失。

```gdscript
func sync_watered_state(is_watered: bool) -> void
```
将运行时浇水状态与外部地块状态同步。用于“先浇地后播种”或读档恢复后对齐当天湿润状态。

```gdscript
func is_mature() -> bool
```
判断作物是否已完全成熟（当前帧达到最后一帧且累计生长天数 >= `total_frames × days_per_frame`）。

```gdscript
func harvest() -> Dictionary
```
执行收获操作。非再生型作物收获后 `is_dead = true`；再生型作物重置至第0帧。返回标准化结果字典。

```gdscript
func destroy() -> Dictionary
```
执行摧毁操作。标记 `is_dead = true`，发射 `crop_destroyed` 信号。

```gdscript
func get_display_state() -> Dictionary
```
获取完整运行时状态（用于UI展示、调试）。

```gdscript
func get_save_state() -> Dictionary
```
获取存档用状态（比 `get_display_state` 少 `is_mature` 和 `total_growth_days`）。

```gdscript
func load_save_state(state: Dictionary) -> void
```
从存档字典恢复生长进度、浇水状态等。

### 3.3 公开属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `crop_data` | `CropData` | 作物数据资源引用 |
| `cell` | `Vector2i` | 所在格子坐标 |
| `growth_days_accumulated` | `int` | 累计生长天数（仅浇水日计入） |
| `current_frame` | `int` | 当前生长帧索引（0-based） |
| `current_stage` | `int` | 当前生长阶段索引（0-based） |
| `watered_today` | `bool` | 当日是否已浇水 |
| `consecutive_unwatered_days` | `int` | 连续未浇水天数；达到 2 后，第三天开始显示缺水提醒 |
| `seed_stage_active` | `bool` | 当前是否仍处于独立种子显示阶段 |
| `planted_timestamp` | `int` | 播种时的Unix时间戳 |
| `is_dead` | `bool` | 是否已死亡（收获/摧毁后） |

---

## 四、CropData 对外接口

> 脚本路径：`scripts/data/CropData.gd`  
> 类型：`Resource`

### 4.1 导出配置属性

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `id` | `StringName` | `&""` | 作物唯一标识，如 `&"tomato_crop"` |
| `display_name` | `String` | `""` | 展示名称 |
| `description` | `String` | `""` | 描述文本 |
| `seed_item` | `ItemData` | — | 对应的种子物品资源 |
| `harvest_item` | `ItemData` | — | 收获产物物品资源 |
| `seed_texture` | `Texture2D` | — | 播种当天显示的独立种子贴图；配置后优先于生长序列第0帧 |
| `seed_visual_offset` | `Vector2` | `(0,0)` | 种子贴图绘制偏移，通常与高株生长贴图分开调 |
| `growth_texture` | `Texture2D` | — | 生长帧精灵表（水平条带） |
| `growth_frame_size` | `Vector2i` | `(32,32)` | 单帧像素尺寸 |
| `growth_visual_offset` | `Vector2` | `(0,0)` | 作物精灵绘制偏移，单位像素；负Y表示整体上移 |
| `water_hint_offset` | `Vector2` | `(0,-10)` | 缺水提示相对“当前帧可见顶部”的微调偏移 |
| `harvest_hint_offset` | `Vector2` | `(0,-12)` | 成熟提示相对“当前帧可见顶部”的微调偏移 |
| `growth_frame_count` | `int` | `1` | 生长帧总数（范围 1-64） |
| `stage_frame_counts` | `PackedInt32Array` | `[1]` | 每个阶段的帧数分布 |
| `days_per_stage` | `PackedInt32Array` | `[1]` | 每个阶段的持续天数 |
| **`days_per_frame`** | `int` | `1` | **每帧对应的天数（1-30）** |
| `regrowable` | `bool` | `false` | 是否可反复收获 |
| `regrow_days` | `int` | `0` | 再生所需天数 |
| `harvest_yield_min` | `int` | `1` | 最小收获数量 |
| `harvest_yield_max` | `int` | `1` | 最大收获数量 |
| `seasons` | `PackedStringArray` | `[]` | 可种植季节（原型暂不使用） |
| `metadata` | `Dictionary` | `{}` | 扩展元数据 |

### 4.2 计算方法

```gdscript
func get_total_growth_days() -> int
```
返回完全成熟所需总天数：`growth_frame_count × days_per_frame`。  
例：7帧 × 1天/帧 = 7天；7帧 × 5天/帧 = 35天。

```gdscript
func get_stage_for_frame(frame: int) -> int
```
根据当前帧索引计算所属阶段。基于 `stage_frame_counts` 的累积分布。

```gdscript
func get_days_required_for_frame(target_frame: int) -> int
```
达到指定帧所需的天数：`(target_frame + 1) × days_per_frame`。

```gdscript
func is_frame_mature(frame: int) -> bool
```
判定指定帧索引是否达到成熟帧（`frame >= growth_frame_count - 1`）。

```gdscript
func get_display_name() -> String
func get_stage_count() -> int
func is_harvest_yield_valid() -> bool
```

---

## 五、番茄作物配置示例

> 资源路径：`resources/crops/tomato_crop.tres`

| 配置项 | 值 | 说明 |
|--------|-----|------|
| `id` | `&"tomato_crop"` | 作物ID |
| `seed_texture` | `Seed_Tomato_32x32.png` | 播种当天显示的独立番茄种子贴图 |
| `seed_visual_offset` | `(0, -4)` | 32x32 种子贴图对齐到与高株相同的地面基线 |
| `growth_frame_size` | `(32, 64)` | 每帧画布 32x64，适配高苗/成熟株混合高度 |
| `growth_visual_offset` | `(0, -20)` | 向上抬 20 像素，使根部落回耕地基线 |
| `water_hint_offset` | `(0, -10)` | 缺水水滴在当前帧可见顶部基础上再抬 10 像素 |
| `harvest_hint_offset` | `(0, -12)` | 成熟提示在当前帧可见顶部基础上再抬 12 像素 |
| `growth_frame_count` | `7` | 7帧生长动画 |
| `days_per_frame` | `1`（默认） | 每帧对应1天，共7天成熟 |
| `stage_frame_counts` | `[1, 3, 3]` | 阶段0=1帧（种子）→阶段1=3帧（生长）→阶段2=3帧（成熟） |
| `days_per_stage` | `[2, 2, 2]` | 阶段级配置（当 days_per_frame=1 时，帧级配置优先） |
| `harvest_yield_min/max` | `1` / `1` | 每次收获1个番茄 |
| `regrowable` | `false` | 非再生型 |
| `seed_item` | `tomato_seed.tres` | 种子物品 |
| `harvest_item` | `tomato.tres` | 番茄产物（售价200金币） |

**调整 `days_per_frame` 示例：** 若改为 `5`，则番茄需 7×5=35 天才成熟。无需修改其他配置。

---

## 六、与外部系统的集成约定

### 6.1 工具系统 (ToolController) 集成

```gdscript
# ToolController._apply_default_tool_action() 中建议加入：
if crop_registry.has_crop_at(target_cell):
	var result: Dictionary = crop_registry.handle_tool_action(tool_data.id, target_cell)
	return result.success
```

也可监听信号获取异步反馈：

```gdscript
crop_registry.tool_action_completed.connect(_on_crop_action_completed)

func _on_crop_action_completed(action: StringName, cell: Vector2i, result: Dictionary) -> void:
	if result.success and action == &"harvest":
		var yield_count: int = result.yield_count
		var item_id: String = result.crop_item_id
		# 将产物加入背包
```

### 6.2 格子系统 (FarmGrid) 同步

| 操作 | CropRegistry 调用的 FarmGrid 方法 | 信号 |
|------|----------------------------------|------|
| 播种 | `plant_crop(cell, crop_id, 0)` | `crop_planted` |
| 生长帧变化 | `set_crop_stage(cell, current_frame)` | `growth_advanced` |
| 收获（非再生型） | `clear_crop(cell)` | `crop_removed` |
| 摧毁 | `clear_crop(cell)` | `crop_removed` |

### 6.3 时间系统 (TimeManager) 集成

```gdscript
# TimeManager 在新的一天开始时调用：
func _advance_day() -> void:
	crop_registry.advance_all_crops_day()
	farm_grid.clear_watered_tiles()
```

### 6.4 存档系统 (SaveManager) 集成

```gdscript
# 存档
var crop_states: Array[Dictionary] = crop_registry.export_state()

# 读档
crop_registry.import_state(crop_states)
```

---

## 七、导出配置参数 (CropRegistry)

| 变量 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `auto_load_crops` | `bool` | `true` | 是否在 `_ready` 时自动加载 `crop_resource_paths` 中的资源 |
| `crop_resource_paths` | `Array[String]` | `["res://resources/crops/tomato_crop.tres"]` | 默认加载的作物资源路径列表 |
| `farm_grid_path` | `NodePath` | — | 指向 `FarmGrid` 节点的路径。留空则自动搜索场景树 |

---

## 八、异常处理策略

| 场景 | 处理方式 |
|------|---------|
| 未注册的 `crop_id` | 返回 `error_code: "unknown_crop"` |
| `FarmGrid` 未绑定 | 返回 `error_code: "no_farm_grid"` |
| 播种时格子不可用 | 返回 `error_code: "cell_not_plantable"` 或 `"cell_occupied"` |
| 对无作物格子收获/浇水 | 返回 `error_code: "no_crop_at_cell"`（铲子除外，视为成功） |
| 收获未成熟作物 | 返回 `error_code: "crop_not_mature"` |
| 对已死亡作物操作 | 返回 `error_code: "crop_already_dead"` |
| 存档恢复时 `crop_id` 未注册 | 跳过该条目并 `push_warning` |
| 作物场景实例化失败 | 返回 `error_code: "instantiate_failed"` |

所有错误返回均遵循统一格式：`{ "success": false, "error_code": "xxx", "error_message": "yyy" }`。

---

## 九、依赖的外部接口（本系统消费）

| 来源 | 方法/属性 | 用途 |
|------|----------|------|
| `FarmGrid` | `can_plant_crop(cell) -> bool` | 播种前校验 |
| `FarmGrid` | `plant_crop(cell, crop_id, stage)` | 播种后同步格子状态 |
| `FarmGrid` | `set_crop_stage(cell, stage)` | 生长帧变化时同步 |
| `FarmGrid` | `clear_crop(cell)` | 作物移除后清理格子 |
| `FarmGrid` | `cell_to_world(cell) -> Vector2` | 实例定位 |
| `CropData` (Resource) | 全部导出属性 | 配置驱动 |
| `ItemData` (Resource) | `id` | 收获产物和种子物品标识 |
