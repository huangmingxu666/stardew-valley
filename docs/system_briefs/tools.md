# 工具系统

## 职责

- 锄头开垦
- 水壶浇水
- 种子播种
- 收获成熟作物
- 铲除作物

## 目标产出

- `scripts/player/ToolController.gd`
- `scripts/data/ToolData.gd`
- `resources/tools/*.tres`

## 当前线程接口约定

- 工具定义放在 `resources/tools/*.tres`
- `ToolController` 启动时会自动加载默认工具资源
- `ToolController.get_selected_tool_data()` 返回当前工具数据
- `ToolController.use_current_tool()` 会尝试执行默认地块行为
- `ToolController.tool_use_requested` 始终发出，方便角色线程接动画和状态
- 当前默认落地行为包含：
  - `shovel` (TILL_SOIL) -> 有作物时 `CropRegistry.destroy_crop()`，无作物时 `FarmGrid.till_cell()`
  - `watering_can` (WATER_SOIL) -> `CropRegistry.water_crop()` + `FarmGrid.water_cell()`
  - `bare_hands` (HARVEST) -> `CropRegistry.harvest_crop()`
- `axe` 和 `fishing_rod` 目前只完成数据注册，不在这个线程里写死玩法
- `ToolController` 通过 `@export_node_path` 自动查找 `FarmGrid` 和 `CropRegistry`，也支持场景树自动遍历
