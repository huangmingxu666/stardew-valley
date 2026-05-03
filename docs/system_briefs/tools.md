# 工具系统

## 职责

- 锄头开垦
- 水壶浇水
- 种子播种
- 收获成熟作物

## 目标产出

- `scripts/player/ToolController.gd`
- `scripts/data/ToolData.gd`

## 当前线程接口约定

- 工具定义放在 `resources/tools/*.tres`
- `ToolController` 启动时会自动加载默认工具资源
- `ToolController.get_selected_tool_data()` 返回当前工具数据
- `ToolController.use_current_tool()` 会尝试执行默认地块行为
- `ToolController.tool_use_requested` 始终发出，方便角色线程接动画和状态
- 当前默认落地行为只包含：
  - `shovel` -> `FarmGrid.till_cell()`
  - `watering_can` -> `FarmGrid.water_cell()`
- `axe` 和 `fishing_rod` 目前只完成数据注册，不在这个线程里写死玩法
