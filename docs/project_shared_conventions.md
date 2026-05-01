# 项目共享约定

本文件是项目级公共约定。后续如果并行开发，所有线程先阅读本文件，再阅读各自负责系统的说明。

## 1. 项目目标

当前目标是完成一个可玩的农场垂直切片，验证以下核心循环：

```text
移动 -> 交互 -> 锄地 -> 播种 -> 浇水 -> 睡觉 -> 成长 -> 收获 -> 售卖 -> 购买种子
```

## 2. Godot 基础约定

- Godot 版本：4.6
- 渲染模式：2D 优先
- Tile 尺寸：默认 32x32
- 地图层：使用 `TileMapLayer`
- 地图坐标与格子坐标必须统一

## 3. 命名约定

- 资源 ID：小写蛇形命名，例如 `turnip_seed`
- 脚本类名：大驼峰，例如 `FarmGrid`
- 信号名：过去式或事件式，例如 `day_started`

## 4. 数据边界

- `TileMapLayer` 只负责显示，不作为唯一玩法数据源
- 玩法格子数据由 `FarmGrid` 或同类系统管理
- 物品、作物、工具应数据驱动

## 5. 系统通信

优先使用：

- 明确类型的函数调用
- 信号
- 数据资源
- 统一管理器

避免：

- 跨系统直接改内部变量
- 用节点路径硬找其他系统
- 在玩家脚本中堆叠所有玩法逻辑

## 6. 并行开发约束

默认不要让多个线程同时修改这些核心文件：

- `scenes/world/Farm.tscn`
- `scripts/core/GameState.gd`
- `scripts/core/TimeManager.gd`
- `scripts/player/PlayerController.gd`
- `scripts/farm/FarmGrid.gd`

如果必须修改共享文件，需要先说明影响范围和接口变更。

## 7. GDScript 类型约定

- 成员变量尽量显式标注类型
- 函数返回值尽量显式标注类型
- `:=` 仅在右值类型非常明确时使用
- 来自 `Dictionary.get()`、`get_node_or_null()`、`Resource.get()` 的值优先显式声明类型
