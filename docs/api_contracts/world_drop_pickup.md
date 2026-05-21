# world_drop_pickup.md 已废弃

> 本文件保留为旧入口跳转说明，避免其它线程继续引用已经分散或过期的上下文。  
> 当前世界掉落物 / 拾取 / 入包的权威契约文档为：  
> [world_drop_and_pickup.md](./world_drop_and_pickup.md)

---

## 使用规则

- 以后新增或修改世界掉落物行为，只更新 `world_drop_and_pickup.md`
- 本文件不再维护实现细节
- 如果本文件与主契约文档出现冲突，以 `world_drop_and_pickup.md` 为准

---

## 当前已收口的内容

主契约文档已经统一说明：

- `WorldDropManager` 的职责与上游依赖
- `WorldItemPickup` 的空中阶段 / 落地后拾取规则
- `Inventory.add_stack()` / `add_item_data()` 的正式入包接口
- 场景接线与联调清单
