# UI 线程接口契约

> 所属系统：UI / HUD / InventoryPanel  
> 主要场景：`scenes/ui/PlayerUi.tscn`、`scenes/ui/HUD.tscn`、`scenes/ui/InventoryPanel.tscn`、`scenes/ui/Slot.tscn`、`scenes/ui/PlayerCustomization.tscn`  
> 主要脚本：`scripts/ui/PlayerUi.gd`、`scripts/ui/HUD.gd`、`scripts/ui/InventoryPanel.gd`、`scripts/ui/SlotUI.gd`、`scripts/ui/PlayerCustomizationSlot.gd`、`scripts/ui/TrashDropArea.gd`

---

## 一、UI 线程职责边界

UI 线程负责：

- `PlayerUi` 总入口、HUD、背包面板、售卖面板入口的打开关闭协调
- HUD 时间、日期、星期、金币、快捷栏显示
- 背包格子显示、背包内部拖拽、背包与可接收 UI 区域的拖拽
- 底部快捷栏显示与数字键选中高亮
- 角色穿搭槽的 UI 接收与显示
- 垃圾桶拖拽接收入口

UI 线程不负责：

- 背包数据的持久化与物品堆叠规则来源
- 物品定义、图标资源、售价、装备类型判断
- 时间推进、睡觉、次日结算
- 玩家移动、工具落地行为
- 售卖队列的价格计算与最终结算

---

## 二、UI 对外提供接口

### 2.1 PlayerUiRoot

脚本：`scripts/ui/PlayerUi.gd`  
场景：`scenes/ui/PlayerUi.tscn`

```gdscript
class_name PlayerUiRoot
```

#### Public Methods

```gdscript
func open_inventory_panel() -> void
func close_inventory_panel() -> void
func close_all_panels() -> bool

func open_shipping_panel() -> void
func close_shipping_panel() -> bool
func is_shipping_panel_open() -> bool
```

#### 输入约定

```text
Tab     打开/关闭 InventoryPanel
Esc     关闭当前 UI 面板
1-0     切换 10 个快捷栏槽位
```

#### 对其它线程的调用方式

需要打开售卖/出货面板的线程应调用：

```gdscript
var player_ui: PlayerUiRoot = get_tree().get_first_node_in_group("player_ui") as PlayerUiRoot
if player_ui != null:
	player_ui.open_shipping_panel()
```

如果场景未维护 `player_ui` group，则调用方需要通过自身契约提供的明确引用传入，避免硬编码 UI 节点路径。

---

### 2.2 HUDController

脚本：`scripts/ui/HUD.gd`  
场景：`scenes/ui/HUD.tscn`

```gdscript
class_name HUDController
```

#### Public Methods

```gdscript
func setup(target_inventory: Inventory, target_time_manager: TimeManager, target_game_state) -> void
func set_gold(value: int) -> void
func set_hotbar_visible(is_visible: bool) -> void
```

#### 显示约定

```text
TopRightTime      读取 TimeManager 当前时间
TopRightSeason    读取 TimeManager 当前日期/星期
TopRightMoney     显示 8 位金币数字，范围 0-99_999_999
HotBar            显示 10 个快捷栏槽位
```

#### 快捷栏约定

HUD 底部快捷栏是只读显示区：

```text
不接收鼠标点击
不作为拖拽源
不作为拖拽目标
不响应 Shift + 左键
只保留 selected 高亮
```

---

### 2.3 InventoryPanelUI

脚本：`scripts/ui/InventoryPanel.gd`  
场景：`scenes/ui/InventoryPanel.tscn`

```gdscript
class_name InventoryPanelUI
```

#### Public Methods

```gdscript
func setup(target_inventory: Inventory, target_game_state) -> void
```

#### 面板内容

```text
Backpack/GridContainer                      背包与快捷栏可交互格子区
Character_and_Information/Information       当前现金与总收入显示
Character_and_Information/Character         角色外观与穿搭槽区域
TrashDropArea                               可选垃圾桶接收区
```

#### 背包格子约定

```text
背包格子允许鼠标拖拽
背包格子允许作为拖拽目标
背包格子默认不显示 hover 高亮
Shift + 左键根据 SlotUI.quick_action_mode 发出快捷操作信号
```

---

### 2.4 SlotUI

脚本：`scripts/ui/SlotUI.gd`  
场景：`scenes/ui/Slot.tscn`

```gdscript
class_name SlotUI
```

#### Signals

```gdscript
signal quick_equip_requested(section: StringName, index: int)
signal quick_action_requested(action: int, section: StringName, index: int)
```

#### Constants

```gdscript
const DRAG_SECTION_KEY: StringName = &"from_section"
const DRAG_INDEX_KEY: StringName = &"from_index"
const DRAG_SOURCE_KIND_KEY: StringName = &"source_kind"
const DRAG_SOURCE_INVENTORY: StringName = &"inventory"
const DRAG_SOURCE_PENDING: StringName = &"pending"
```

#### Enum

```gdscript
enum QuickActionMode {
	NONE,
	QUICK_EQUIP,
	QUICK_SELL,
	QUICK_WITHDRAW,
}
```

#### Public Methods

```gdscript
func configure(target_inventory: Inventory, target_section: StringName, target_index: int) -> void
func set_quick_action_mode(mode: QuickActionMode) -> void
func set_drag_source_kind(kind: StringName) -> void
func set_stack_provider(provider: Callable = Callable()) -> void
func set_external_drop_handlers(can_drop_checker: Callable = Callable(), drop_handler: Callable = Callable()) -> void
func set_interaction_flags(
	mouse_enabled: bool,
	drag_source_enabled: bool = true,
	drop_target_enabled: bool = true,
	quick_equip_enabled: bool = true,
	hover_highlight_enabled: bool = false
) -> void
func refresh() -> void
func set_selected(is_selected: bool) -> void
```

#### Drag Data Contract

SlotUI 发出的拖拽数据必须是 `Dictionary`，字段如下：

```gdscript
{
	&"source_kind": StringName,
	&"from_section": StringName,
	&"from_index": int,
}
```

接收 SlotUI 拖拽数据的系统必须识别：

```gdscript
data.has(SlotUI.DRAG_SECTION_KEY)
data.has(SlotUI.DRAG_INDEX_KEY)
```

---

### 2.5 PlayerCustomizationSlot

脚本：`scripts/ui/PlayerCustomizationSlot.gd`  
场景：`scenes/ui/PlayerCustomization.tscn`

```gdscript
class_name PlayerCustomizationSlot
```

#### Public Methods

```gdscript
func configure(target_inventory: Inventory, target_slot_id: StringName = &"") -> void
func is_empty() -> bool
func try_equip_from_inventory(from_section: StringName, from_index: int) -> bool
```

#### Slot Id 约定

当前 UI 预留以下穿搭槽 ID：

```text
head
top
accessory
hands
bottom
shoes
```

物品线程后续如需限制装备类型，应在物品数据契约中提供可匹配字段，UI 线程再按 `slot_id` 过滤。

---

### 2.6 TrashDropArea

脚本：`scripts/ui/TrashDropArea.gd`

```gdscript
class_name TrashDropArea
```

#### Signals

```gdscript
signal stack_trashed(section: StringName, index: int)
```

#### Public Methods

```gdscript
func configure(target_inventory: Inventory) -> void
```

#### Drag Data Contract

TrashDropArea 接收与 `SlotUI` 相同的拖拽数据：

```gdscript
{
	&"from_section": StringName,
	&"from_index": int,
}
```

---

## 三、UI 依赖其它线程提供的接口

### 3.1 Inventory

UI 线程需要背包线程提供以下信号：

```gdscript
signal hotbar_changed
signal backpack_changed
signal selected_hotbar_index_changed(index: int)
```

UI 线程需要背包线程提供以下常量：

```gdscript
const SECTION_HOTBAR: StringName
const SECTION_BACKPACK: StringName
```

UI 线程需要背包线程提供以下状态：

```gdscript
var selected_hotbar_index: int
var hotbar_size: int
var backpack_size: int
```

UI 线程需要背包线程提供以下方法：

```gdscript
func get_slot_stack(section: StringName, index: int) -> ItemStack
func set_stack(section: StringName, index: int, stack: ItemStack) -> void
func clear_slot(section: StringName, index: int) -> void
func move_or_swap_stack(from_section: StringName, from_index: int, to_section: StringName, to_index: int) -> bool
func set_selected_hotbar_index(index: int) -> void
func get_selected_hotbar_stack() -> ItemStack
func ensure_default_tool_loadout(tool_definitions: Array[ToolData]) -> void
func find_hotbar_index_by_item_id(item_id: StringName) -> int
```

---

### 3.2 ItemStack

UI 线程显示格子需要读取以下字段：

```gdscript
var item_id: StringName
var display_name: String
var icon_texture: Texture2D
var quantity: int
var source_data: Resource
```

UI 线程需要调用以下方法：

```gdscript
func is_empty() -> bool
```

---

### 3.3 TimeManager

UI 线程需要时间线程提供以下信号：

```gdscript
signal time_changed(day: int, hour: int, minute: int)
```

UI 线程需要时间线程提供以下状态：

```gdscript
var current_hour: int
var current_minute: int
```

UI 线程需要时间线程提供以下方法：

```gdscript
func get_day_of_season() -> int
func get_weekday_label() -> String
```

推荐节点路径：

```gdscript
/root/GameTime
```

---

### 3.4 GameState

现金状态当前通过 Autoload 暴露：

```gdscript
/root/GameState
```

`GameState` 作为 Autoload 节点使用，不要求 `class_name`。

#### Signals

```gdscript
signal cash_changed(current_cash: int, total_cash: int)
```

#### Public Methods

```gdscript
func get_current_cash() -> int
func get_total_cash() -> int
func set_cash(value: int) -> void
func set_total_cash(value: int) -> void
func set_cash_state(new_current_cash: int, new_total_cash: int) -> void
func add_cash(amount: int) -> void
func spend_cash(amount: int) -> bool
```

#### UI 显示字段

```text
HUD.TopRightMoney                         显示 current_cash
InventoryPanel.Information.Current_cash   显示 current_cash
InventoryPanel.Information.Total_cash     显示 total_cash
```

---

### 3.5 ToolController

UI 线程通过快捷栏同步当前工具选择，需要工具线程提供：

```gdscript
signal selected_tool_changed(tool_id: StringName)

func has_tool(tool_id: StringName) -> bool
func select_tool_by_id(tool_id: StringName) -> void
func clear_selected_tool() -> void
func get_selected_tool_id() -> StringName
```

工具资源加载约定：

```gdscript
const DEFAULT_TOOL_RESOURCE_PATHS: Array[String]
```

---

### 3.6 SceneTransition

UI 面板打开时会申请输入锁，需要过场/输入锁线程提供：

```gdscript
func acquire_input_lock(reason: StringName) -> void
func release_input_lock(reason: StringName) -> void
```

UI 使用的锁原因：

```gdscript
&"inventory_panel"
&"shipping_panel"
```

---

### 3.7 ShopPanelUI

`PlayerUiRoot` 会把背包数据传入售卖面板，并控制面板显示状态。售卖 UI 线程需要保持以下接口：

```gdscript
func setup(target_inventory: Inventory) -> void
```

场景路径：

```text
scenes/ui/ShopPanel.tscn
```

---

## 四、节点结构稳定约定

以下路径被 UI 脚本直接引用，修改节点名或层级时必须同步更新脚本与本契约：

```text
PlayerUi/HUD
PlayerUi/InventoryPanel
PlayerUi/ShopPanel

HUD/Root/HotBar
HUD/Root/HotBar/GridContainer
HUD/Root/TopRight/TopRightTime/HBoxContainer/TimeRow/TimeLeft
HUD/Root/TopRight/TopRightSeason/HBoxContainer/Season
HUD/Root/TopRight/TopRightSeason/HBoxContainer/Week
HUD/Root/TopRight/TopRightMoney/GridContainer/HBoxContainer/HBoxContainer

InventoryPanel/Backpack/GridContainer
InventoryPanel/Character_and_Information/Information/VBoxContainer/Current_cash
InventoryPanel/Character_and_Information/Information/VBoxContainer/Total_cash

SlotUI/Bg
SlotUI/SelectedFrame
SlotUI/Overlay/Icon
SlotUI/Overlay/CountLabel
```

---

## 五、当前限制与后续对接点

```text
穿搭槽当前只保存 UI 本地显示状态，尚未接入正式装备数据模型。
穿搭槽当前不校验衣服/鞋子/饰品类型，等待物品线程提供类型字段。
垃圾桶当前只提供 drop 接收和 stack_trashed 信号，动画可后续接入。
HUD 快捷栏是只读显示，正式物品使用逻辑应由数字键选中后的工具/物品线程处理。
背包 hover tooltip 尚未落地，后续建议由 SlotUI 发 hover 信号，外层面板统一显示说明框。
```
