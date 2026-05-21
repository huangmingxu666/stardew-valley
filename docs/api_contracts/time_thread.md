# 时间线程 接口契约

> 所属系统：时间线程  
> 核心脚本：`scripts/core/TimeManager.gd`  
> 相关脚本：`scripts/core/SleepTransitionController.gd`、`scripts/core/GameState.gd`、`scripts/ui/HUD.gd`  
> 当前全局单例：`GameTime`、`GameState`、`SleepTransition`

---

## 一、当前职责范围

时间线程当前已经落地以下内容：

- 全局时间推进：游戏内 1 分钟 = 现实 1 秒
- 日期与星期推进：初始为 `1日 / 星期一 / 08:00`
- 季节内部计算：春夏秋冬，每季 28 天
- 凌晨 `02:00` 未睡觉时昏迷，并自动进入下一天 `08:00`
- 睡觉过场中调用 `request_sleep_skip_to_next_day()`
- 时间暂停接口：供过场、剧情、菜单等系统锁住时间
- 新一天开始时自动尝试结算售卖箱收入，并转入 `GameState.add_cash()`
- HUD 时间/日期/星期显示接线

本线程当前不负责：

- 天气系统
- 节日/NPC 日程
- 冬季积雪视觉实现
- 作物成长推进本体
- 售卖箱面板和库存实现

---

## 二、Autoload 约定

### 2.1 `GameTime`

`project.godot` 中已注册：

```text
GameTime="*res://scripts/core/TimeManager.gd"
```

其他线程应优先通过：

```gdscript
var game_time: TimeManager = get_node_or_null("/root/GameTime") as TimeManager
```

不要再手动在场景里新建第二个正式时间管理节点。

### 2.2 `GameState`

`project.godot` 中已注册：

```text
GameState="*res://scripts/core/GameState.gd"
```

时间线程在售卖结算时通过 `/root/GameState` 调用 `add_cash(amount)`。

### 2.3 `SleepTransition`

`project.godot` 中已注册：

```text
SleepTransition="*res://scripts/core/SleepTransitionController.gd"
```

床交互线程应继续通过 `SleepTransition.play_sleep_transition(source)` 触发睡觉，而不是直接改日期。

---

## 三、TimeManager 对外输出接口

> 脚本路径：`scripts/core/TimeManager.gd`

### 3.1 对外信号

```gdscript
signal day_started(day: int)
signal day_ended(day: int)
signal hour_changed(day: int, hour: int)
signal time_changed(day: int, hour: int, minute: int)
signal season_changed(season: StringName, season_index: int)
signal faint_requested(day: int)
signal pause_changed(paused: bool)
signal sleep_skip_requested(day: int)
signal sleep_skip_completed(day: int)
```

推荐接法：

- UI 线程：监听 `time_changed`
- 作物/农场线程：监听 `day_started`
- 剧情/演出线程：监听 `faint_requested`、`pause_changed`
- 统计/日志线程：监听 `day_started`、`day_ended`

### 3.2 对外公开方法

```gdscript
func set_time(day: int, hour: int, minute: int = 0, emit_signals: bool = true) -> void
func advance_minute(minutes: int = 1) -> void
func advance_hour(hours: int = 1) -> void
func start_next_day() -> void
func request_sleep_skip_to_next_day() -> void

func pause_time(reason: StringName = &"default") -> void
func resume_time(reason: StringName = &"default") -> void
func clear_time_pauses() -> void
func is_time_paused() -> bool

func get_day_of_season() -> int
func get_weekday_index() -> int
func get_weekday_label() -> String
func get_current_season_index() -> int
func get_current_season() -> StringName
func is_winter() -> bool
func can_plant_in_current_season(allowed_seasons: Array[StringName] = []) -> bool
func get_time_label() -> String
func commit_shipping_sales() -> void
```

### 3.3 当前时间规则

- 初始状态：`current_day = 1`、`08:00`
- 一周按 `星期一` 到 `星期日`
- 日期只在睡觉或昏迷后推进
- `00:00` 到 `01:59` 仍属于当天
- `02:00` 触发 `faint_requested`，随后自动 `start_next_day()`
- `start_next_day()` 后固定回到 `08:00`

---

## 四、与其它线程的接线点

### 4.1 角色/交互线程

当前依赖接口：

```gdscript
SleepTransition.play_sleep_transition(source: Node = null) -> void
```

当前行为：

- 睡觉交互不直接改 `GameTime`
- 交互线程只负责触发睡觉过场
- 过场中点由 `SleepTransitionController` 调用 `GameTime.request_sleep_skip_to_next_day()`

角色线程如果需要暂停剧情时间，应使用：

```gdscript
GameTime.pause_time(&"cutscene")
GameTime.resume_time(&"cutscene")
```

不要通过 `auto_advance_time = false` 直接硬改运行状态。

### 4.2 UI 线程

当前 HUD 已消费以下接口：

```gdscript
GameTime.current_hour
GameTime.current_minute
GameTime.get_day_of_season()
GameTime.get_weekday_label()
GameState.cash_changed(current_cash, total_cash)
GameState.get_current_cash()
```

当前 HUD 显示规则：

- 时间：`08:00`
- 日期：`1日`
- 星期：`星期一`

如果后续 UI 线程要增加季节名展示，可直接调用：

```gdscript
GameTime.get_current_season()
GameTime.get_current_season_index()
```

### 4.3 作物/种植线程

当前已提供的判断接口：

```gdscript
GameTime.get_current_season() -> StringName
GameTime.is_winter() -> bool
GameTime.can_plant_in_current_season(allowed_seasons: Array[StringName] = []) -> bool
```

约定用途：

- 种子播种前做季节合法性校验
- 冬季禁种逻辑优先走 `can_plant_in_current_season()`
- 冬季地表积雪视觉应监听 `season_changed`

当前未接入：

- `day_started -> 作物成长推进`
- `day_started -> 清理已浇水地块`

这部分应由作物/农场线程继续对接，不在本线程文档之外另起一套时间源。

### 4.4 售卖线程

时间线程当前已经预留并调用：

```gdscript
var shipping_manager: Node = get_node_or_null("/root/ShippingManager")
if shipping_manager != null and shipping_manager.has_method("commit_pending_sales"):
	var result = shipping_manager.call("commit_pending_sales")
```

售卖线程需要满足的最小契约：

```gdscript
func commit_pending_sales() -> int
```

或返回可安全转为现金的 `float`。

时间线程行为：

- 在 `day_started` 时自动调用 `commit_shipping_sales()`
- 如果 `ShippingManager` 不存在，不报错，直接跳过
- 返回值 `<= 0` 时，不调用 `GameState.add_cash()`
- 成功结算后调用：

```gdscript
GameState.add_cash(amount)
```

因此售卖线程不要自己在睡觉时直接改现金，避免重复结算。

### 4.5 存档线程

当前时间线程尚未提供专门的存档包装方法，但存档线程可直接读取：

```gdscript
GameTime.current_day
GameTime.current_hour
GameTime.current_minute
GameState.current_cash
GameState.total_cash
```

恢复读档时建议通过：

```gdscript
GameTime.set_time(day, hour, minute, true)
GameState.set_cash_state(current_cash, total_cash)
```

不要直接改内部变量后跳过信号，否则 HUD 和其它监听者不会刷新。

---

## 五、GameState 对外接口

> 脚本路径：`scripts/core/GameState.gd`

当前公开信号：

```gdscript
signal cash_changed(current_cash: int, total_cash: int)
```

当前公开方法：

```gdscript
func get_current_cash() -> int
func get_total_cash() -> int
func set_cash(value: int) -> void
func set_total_cash(value: int) -> void
func set_cash_state(new_current_cash: int, new_total_cash: int) -> void
func add_cash(amount: int) -> void
func spend_cash(amount: int) -> bool
```

与时间线程相关的唯一硬依赖是：

```gdscript
func add_cash(amount: int) -> void
```

---

## 六、SleepTransition 对时间线程的调用链

当前调用链如下：

```text
Bed / sleep interact
→ SleepTransition.play_sleep_transition()
→ sleep_transition_midpoint(source, time_manager)
→ GameTime.request_sleep_skip_to_next_day()
→ GameTime.start_next_day()
→ day_started(day)
→ commit_shipping_sales()
```

这条链已经落地。其它线程如果需要“睡觉推进到下一天”，应复用这条链，不要跳过中间过程。

---

## 七、当前已知边界与注意事项

- `scripts/core/TimeManager.gd` 属于共享核心文件，后续线程修改前先说明接口影响。
- 售卖线程当前尚未把 `ShippingManager` 提交到仓库；时间线程已做兼容，不存在时不会报错。
- 当前 `commit_pending_sales()` 只约定返回总金额，不约定返回明细。
- 如果后续需要“当天收入明细弹窗”，建议售卖线程额外提供查询接口，不要修改 `add_cash()` 语义。
- 如果后续要在剧情中冻结时间，统一使用 `pause_time(reason)` / `resume_time(reason)`，避免多个线程互相覆盖暂停状态。

---

## 八、建议其它线程直接复用的接法

### 新一天逻辑

```gdscript
var game_time: TimeManager = get_node_or_null("/root/GameTime") as TimeManager
if game_time != null and not game_time.day_started.is_connected(_on_day_started):
	game_time.day_started.connect(_on_day_started)
```

### 时间暂停

```gdscript
GameTime.pause_time(&"dialogue")
GameTime.resume_time(&"dialogue")
```

### 季节播种判断

```gdscript
if not GameTime.can_plant_in_current_season(allowed_seasons):
	return false
```

### 睡觉推进新一天

```gdscript
SleepTransition.play_sleep_transition(self)
```
