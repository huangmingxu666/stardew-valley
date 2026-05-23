# 商店系统 接口契约

> 所属系统：商店与经济系统  
> 脚本路径：`scripts/economy/ShopInventory.gd`、`scripts/objects/ShopCounter.gd`、`scripts/ui/ShopBuyPanel.gd`  
> 关联 UI：`scenes/ui/ShopBuyPanel.tscn`、`scenes/ui/PlayerUi.tscn`  
> 关联数据：`resources/items/Plant/Tomato/tomato_seed.tres`、`resources/items/turnip_seed.tres`、`resources/items/pumpkin_seed.tres`  
> 关联场景：`scenes/objects/ShopHouse/ShopHouseInterior.tscn`

---

## 一、架构与设计约束

商店系统支持玩家通过场景中的柜台交互来打开商店购买界面，使用金币购买种子，扣款后直接放入背包中。

1. **种子物品配置**：
   - 所有的商品必须是 `ItemData` 资源。
   - 价格解析规则：首选使用 `ItemData.buy_price` 作为买价；若其为 0，则退回使用 `ItemData.sell_price * 2` 作为买价。
2. **购买原子操作**：
   - 扣除金币与物品放入背包的操作必须具有原子性。
   - 在执行购买时，必须先验证金币是否足够，然后执行 `Inventory.add_item_data`。只有在确认物品能够完全放入背包（`fully_added`）之后，才调用 `GameState.spend_cash` 执行真正的扣款，以避免“付钱后物品丢失”或“物品放入背包但没付钱”的问题。
3. **输入与时间锁**：
   - 商店面板开启时，必须调用 `SceneTransition.acquire_input_lock(&"shop_panel")` 锁定玩家移动，并调用 `time_manager.pause_time(&"shop_panel")` 暂停游戏时间。
   - 商店面板关闭时，必须释放对应的输入锁和时间暂停。

---

## 二、数据层接口 (ShopInventory)

### 2.1 数据结构

```gdscript
class ShopEntry:
	var item_data: ItemData
	var price: int
	var stock: int  # -1 表示无限库存
```

### 2.2 对外信号 (Signals)

```gdscript
# 购买成功时触发
signal shop_purchase_completed(item_id: StringName, quantity: int, total_cost: int)

# 购买失败时触发
signal shop_purchase_failed(item_id: StringName, reason: String)
```

### 2.3 暴露方法 (Public Methods)

```gdscript
# 获取当前商店的全部商品条目
func get_entries() -> Array[ShopEntry]

# 判断是否可以购买指定数量的商品（包含金币和库存校验）
func can_purchase(entry_index: int, quantity: int, available_cash: int) -> bool

# 执行购买操作（入包、扣款、扣库存）
# 返回字典：{ "success": bool, "item_data": ItemData, "quantity": int, "total_cost": int }
func purchase(entry_index: int, quantity: int, inventory: Inventory = null) -> Dictionary
```

---

## 三、UI 层接口 (ShopBuyPanel)

### 3.1 场景与脚本

- 场景路径：`scenes/ui/ShopBuyPanel.tscn`
- 脚本类型：`Control` (`ShopBuyPanel`)
- 关联节点名：`Player_UI/ShopBuyPanel`

### 3.2 信号

```gdscript
# 当玩家点击关闭按钮或按下 ESC 时触发
signal close_requested
```

### 3.3 暴露方法

```gdscript
# 绑定商店数据源与玩家背包，并生成动态的商品列表行
func setup(shop_inv: ShopInventory, player_inv: Inventory) -> void

# 重新刷新金币显示及按钮可点击状态（金币不足时按钮灰化显示“金币不足”）
func refresh() -> void
```

---

## 四、玩家 UI 根集成 (PlayerUiRoot)

### 4.1 新增公开方法

`PlayerUi.gd` 中新增了以下公共方法供其它系统（如交互系统）调用：

```gdscript
# 打开商店面板，传入关联的商店库存数据
func open_shop_panel(shop_inventory: ShopInventory) -> void

# 关闭商店面板，如果确实执行了关闭操作则返回 true
func close_shop_panel() -> bool

# 查询商店面板当前是否开启
func is_shop_panel_open() -> bool
```

---

## 五、柜台交互 (ShopCounter)

- 场景路径：`scenes/objects/ShopHouse/ShopCounter.tscn`
- 脚本继承：`Interactable`

### 5.1 导出属性

```gdscript
# 绑定此柜台所关联的商品数据源节点 ShopInventory
@export var shop_inventory: ShopInventory
```

### 5.2 交互行为

当玩家靠近柜台并按下交互键（默认 `F`）时，`ShopCounter` 将：
1. 自动在当前场景中搜索 `PlayerUiRoot` 实例。
2. 调用 `player_ui.open_shop_panel(shop_inventory)` 并将自身的库存数据传入。

---

## 六、异常与边界情况处理

| 异常情况 | 系统表现 | 恢复机制 |
|---------|---------|---------|
| 金币不足购买商品 | 购买按钮自动禁用，提示“金币不足”；如强行调用购买接口，返回 `success = false` 且触发 `shop_purchase_failed` 信号。 | 无状态变更，不扣除金币与库存。 |
| 玩家背包已满 | 点击购买时提示“购买失败: 背包已满”，返回 `success = false`。 | 无状态变更，不扣除金币与库存。 |
| 时间锁与输入锁 | 商店开启时，时间停止，主角不能移动；关闭时释放锁定。 | 即使通过 `ESC` 或直接点击面板 `X` 关闭均能正常恢复，不会残留锁定。 |
| 未绑定库存数据源 | 终端打印 `push_error`，交互不执行任何操作。 | 柜台在 Inspector 中必须指定有效的 `ShopInventory` 引用。 |
