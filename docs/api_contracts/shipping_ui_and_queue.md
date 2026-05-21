# 售卖 UI / 待售缓存 接口契约

> 所属系统：售卖线程  
> 脚本路径：`scripts/economy/ShippingManager.gd`、`scripts/ui/ShopPanel.gd`、`scripts/economy/ShippingBin.gd`  
> 关联 UI：`scenes/ui/ShopPanel.tscn`、`scenes/ui/PlayerUi.tscn`  
> 关联共享文件：`scripts/ui/PlayerUi.gd`、`scripts/player/PlayerController.gd`、`project.godot`

---

## 一、当前线程已完成内容

本线程当前负责并已落地：

- 售卖箱交互后打开 `ShopPanel`
- 上方 `Shop` 区作为“待售缓存可视化”
- 下方 `Backpack` 区作为玩家背包 30 格出售入口
- `Shift + 左键` 的上下文切换：
  - `InventoryPanel` 内背包格：快速装备
  - `ShopPanel` 下方背包格：快速卖出
  - `ShopPanel` 上方待售格：快速撤回
- 拖拽卖出、拖拽撤回、待售区内部交换/合并
- `ShippingManager.commit_pending_sales()`，供时间线程在次日统一结算

本线程**不负责**：

- 次日入账时机
- 现金结算到 `GameState`
- `F` 交互判定逻辑本身
- `Esc` 统一关 UI 主流程

---

## 二、对外暴露接口（供其它线程调用）

## 2.1 ShippingManager（autoload）

> 节点路径：`/root/ShippingManager`

### 信号

#### `pending_sales_changed`

待售缓存任意变化后触发。UI 线程、时间线程如果需要刷新待售总额或显示，可监听此信号。

### 常量

```gdscript
const SECTION_PENDING: StringName = &"pending"
const DEFAULT_PENDING_SLOT_COUNT: int = 30
```

### 查询接口

```gdscript
func get_pending_stack(index: int) -> ItemStack
func get_pending_stacks() -> Array[ItemStack]
func get_pending_total_value() -> int
```

#### 语义

- `get_pending_stack(index)`：读取指定待售格
- `get_pending_stacks()`：读取全部待售格数组
- `get_pending_total_value()`：返回当前全部待售物总售价，用于 UI 展示或次日结算前预览

### 出售 / 撤回接口

```gdscript
func can_queue_from_inventory(
	inventory: Inventory,
	section: StringName,
	index: int,
	target_index: int = -1
) -> bool

func queue_from_inventory(
	inventory: Inventory,
	section: StringName,
	index: int,
	target_index: int = -1
) -> bool
```

#### 语义

- 从玩家背包或热键栏的某一格，将整组 `ItemStack` 放入待售缓存
- `target_index = -1` 时自动寻找可合并格或空格
- 成功后会从 `Inventory` 原格清空

#### 可出售条件

只有满足下列条件的格子可卖出：

- `ItemStack.source_data is ItemData`
- 对应 `ItemData.sell_price > 0`

因此：

- `ToolData` 工具不可出售
- 没挂真实 `ItemData` 的临时样例栈不可出售
- `sell_price == 0` 的物品不可出售

---

```gdscript
func can_withdraw_to_inventory(
	inventory: Inventory,
	pending_index: int,
	target_section: StringName = Inventory.SECTION_BACKPACK,
	target_index: int = -1
) -> bool

func withdraw_to_inventory(inventory: Inventory, pending_index: int) -> bool

func move_pending_to_inventory(
	inventory: Inventory,
	pending_index: int,
	target_section: StringName,
	target_index: int = -1
) -> bool
```

#### 语义

- 将待售缓存中的某一格撤回到玩家背包
- `withdraw_to_inventory()` 默认自动回收到背包区
- `move_pending_to_inventory()` 支持拖回指定目标格
- 背包满或目标格不可合并时返回 `false`，物品保留在待售区

### 待售区内部整理接口

```gdscript
func can_move_or_merge_pending(from_index: int, to_index: int) -> bool
func move_or_merge_pending(from_index: int, to_index: int) -> bool
```

#### 语义

- 仅用于待售区内部的拖拽整理
- 支持：
  - 空格移动
  - 同类可堆叠物合并
  - 不同物品交换

### 次日结算接口（供时间线程调用）

```gdscript
func commit_pending_sales() -> int
```

#### 语义

- 计算当前全部待售物的总售价
- 清空全部待售缓存
- 返回本次应入账金额
- 本线程**不直接调用** `GameState.add_cash()`，由时间线程在合适时机接入

#### 建议调用时机

- 由时间线程在 `day_started` 时调用
- 再将返回值传给 `GameState.add_cash(amount)`

---

## 2.2 PlayerUiRoot（供角色 / 交互线程调用）

> 脚本：`scripts/ui/PlayerUi.gd`

### 售卖面板接口

```gdscript
func open_shipping_panel() -> void
func close_shipping_panel() -> bool
func is_shipping_panel_open() -> bool
```

#### 语义

- `open_shipping_panel()`：显示 `ShopPanel`，并隐藏 `InventoryPanel`
- `close_shipping_panel()`：关闭 `ShopPanel`，若本次确实关闭了面板则返回 `true`
- `is_shipping_panel_open()`：查询当前售卖面板是否已打开

### 已接入的统一关闭接口

```gdscript
func close_all_panels() -> bool
```

`Esc` 的统一关闭逻辑由角色线程已接到此接口。本线程已让 `close_shipping_panel()` 接入该统一流程。

---

## 2.3 ShippingBin（供交互链路使用）

> 脚本：`scripts/economy/ShippingBin.gd`

### 交互入口

```gdscript
func interact(player: PlayerController) -> void
```

#### 当前行为

```text
ShippingBin.interact()
→ PlayerController.request_open_shipping_panel()
→ PlayerUiRoot.open_shipping_panel()
```

这条链路已经落地，交互线程不需要重复实现售卖箱 UI 打开逻辑。

---

## 三、其它线程需要对接的部分

## 3.1 时间线程

### 必须对接

- 读取 `/root/ShippingManager`
- 在次日开始时调用：

```gdscript
var shipping_manager: Node = get_node_or_null("/root/ShippingManager")
if shipping_manager != null:
	var earned: int = shipping_manager.call("commit_pending_sales")
	if earned > 0:
		GameState.add_cash(earned)
```

### 对接结果

- 次日统一结算
- 待售缓存清空
- 金币一次性到账

### 注意

- 本线程没有修改 `GameState.gd`
- 本线程不负责“结算动画 / 结算弹窗”

---

## 3.2 角色线程

### 已可直接调用

```gdscript
func request_open_shipping_panel() -> bool
func request_close_all_ui() -> bool
```

> 当前在 `PlayerController.gd` 中已存在

### 角色线程无需再做

- 不需要直接查找 `ShopPanel`
- 不需要自己改 `visible`
- 不需要自己管理输入锁和快捷栏显隐

### 角色线程仍需保证

- `F` 交互行为仍然走统一 `interact()` 流程
- 如果后续加入“打开 UI 后角色不能移动”，继续沿用现有 `SceneTransition` 输入锁体系

---

## 3.3 交互线程

### 已可直接复用

统一交互接口保持不变：

```gdscript
can_interact(player)
interact(player)
get_prompt()
```

售卖箱现在已经是标准 `Interactable`，不需要为售卖系统额外加第二套交互协议。

---

## 3.4 物品 / 背包线程

### 必须满足的出售前置条件

- 背包中的可售卖物必须使用真实 `ItemData`
- 生成 `ItemStack` 时必须走：

```gdscript
ItemStack.from_item_data(item_data, amount)
```

### 原因

`ShippingManager` 判断是否可出售时依赖：

```gdscript
var item_data: ItemData = stack.source_data as ItemData
return item_data != null and item_data.sell_price > 0
```

如果物品线程仍然往背包里塞“只有图标和名字的临时 ItemStack”，那这些格子会被判定为不可出售。

### 物品线程需要提供

- 真实 `ItemData` 资源
- `sell_price`
- 正确的 `source_data`

---

## 四、UI 行为约定

## 4.1 Shift + 左键

### InventoryPanel

- 背包区：快速装备

### ShopPanel

- 下方 `Backpack` 区：快速卖出到待售区
- 上方 `Shop` 区：快速撤回到背包

## 4.2 拖拽规则

- 下方背包 → 上方待售区：允许
- 上方待售区 → 下方背包：允许
- 上方待售区内部：允许交换 / 合并
- 背包区与待售区之间：**不允许跨区交换不同物品**
  - 只允许放入空槽
  - 或放入同类且容量足够的槽

## 4.3 面板显示规则

- 打开 `ShopPanel` 时自动关闭 `InventoryPanel`
- 打开 `InventoryPanel` 时自动关闭 `ShopPanel`
- `Esc` 统一走 `close_all_panels()`

---

## 五、联调检查清单

联调时至少确认以下几点：

### 打开 / 关闭

- 靠近售卖箱按 `F` 能打开 `ShopPanel`
- `Esc` 能关闭 `ShopPanel`
- `Tab` 打开背包时不会和 `ShopPanel` 叠在一起

### 出售

- 有真实 `ItemData.sell_price > 0` 的物品可卖
- 工具不可卖
- 样例临时栈若无 `source_data` 则不可卖

### 缓存

- 关闭 `ShopPanel` 后待售缓存不丢
- 重新打开 `ShopPanel` 后待售区内容还在

### 次日结算

- 时间线程调用 `commit_pending_sales()` 后返回正确金额
- 结算后待售区清空

---

## 六、当前实现涉及的共享点

本线程已经修改或依赖了以下共享位置，压缩上下文后其它线程需要注意：

- `project.godot`
  - 新增 autoload：`ShippingManager`
- `scripts/ui/PlayerUi.gd`
  - 新增 `open_shipping_panel()` / `close_shipping_panel()` / `is_shipping_panel_open()`
  - `close_all_panels()` 已兼容关闭售卖面板
- `scripts/player/PlayerController.gd`
  - 已存在 `request_open_shipping_panel()`
- `scripts/economy/ShippingBin.gd`
  - 已接到 `request_open_shipping_panel()`

如果后续线程需要改这些位置，优先保持以上接口名不变。
