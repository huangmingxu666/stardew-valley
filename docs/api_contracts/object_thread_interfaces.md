# Object Thread Interfaces

## Scope

This document summarizes the systems currently implemented or extended from the object-thread side, the output interfaces already exposed to other threads, and the expected integration points.

Current responsibility covered here:

- Building entry / exit scene transitions
- Indoor scene spawn routing
- Sleep / bed interaction and sleep fade transition
- Shipping bin object interaction
- Basic item / crop resource definitions
- World drop / pickup behavior is no longer described here in detail; use `docs/api_contracts/world_drop_and_pickup.md`

## Implemented Object Systems

### World drop / pickup

Canonical document:

- `res://docs/api_contracts/world_drop_and_pickup.md`

Boundary reminder:

- This file no longer duplicates world drop runtime details
- If another thread needs drop scatter / pickup timing / inventory ingest rules, read the canonical drop contract instead of extending this document

### Door / building transition

Files:

- `res://scripts/objects/Door.gd`
- `res://scenes/objects/Door.tscn`
- `res://scripts/objects/SceneExitArea.gd`
- `res://scripts/core/SceneTransitionState.gd`
- `res://scripts/world/SceneSpawnController.gd`

Purpose:

- `Door` handles interact-to-enter scene travel.
- `SceneExitArea` handles touch-to-exit scene travel.
- `SceneTransitionState` stores the pending destination and spawn marker, and also provides short input locking around transitions.
- `SceneSpawnController` reads the pending spawn marker after scene load and places the player.

Key exported fields:

- `Door.destination_scene_path: String`
- `Door.destination_spawn_marker: StringName`
- `Door.record_current_scene_as_return: bool`
- `SceneExitArea.destination_scene_path: String`
- `SceneExitArea.destination_spawn_marker: StringName`
- `SceneExitArea.use_recorded_return_scene: bool`

Key callable interface:

- `SceneTransition.travel_to_scene(scene_path: String, spawn_marker: StringName = &"")`
- `SceneTransition.record_return_scene(scene_path: String)`
- `SceneTransition.get_recorded_return_scene() -> String`
- `SceneTransition.acquire_input_lock(reason: StringName = &"default")`
- `SceneTransition.release_input_lock(reason: StringName = &"default")`
- `SceneTransition.is_input_locked() -> bool`

Integration expectations:

- Scene / map thread places `Door.tscn` or `SceneExitArea` in scenes and configures destination scene paths and spawn marker names.
- Any scene that needs deterministic entry position should contain named `Marker2D` nodes and a `SceneSpawnController`.

### Bed / sleep transition

Files:

- `res://scripts/objects/Furniture/Bed/bed.gd`
- `res://scenes/objects/Bed.tscn`
- `res://scripts/core/SleepTransitionController.gd`
- `res://scripts/core/TimeManager.gd`

Purpose:

- `Bed` is a standard `Interactable`.
- Pressing the player interaction key on the bed triggers a black fade in / fade out transition to represent sleeping.
- The sleep transition resolves a `TimeManager` and requests advancing to the next day at fade midpoint.

Key callable interface:

- `SleepTransition.play_sleep_transition(source: Node = null)`
- `SleepTransition.is_playing() -> bool`
- `TimeManager.request_sleep_skip_to_next_day()`

Signals exposed for other threads:

- `SleepTransition.sleep_transition_started(source: Node)`
- `SleepTransition.sleep_transition_midpoint(source: Node, time_manager: TimeManager)`
- `SleepTransition.sleep_transition_finished(source: Node)`
- `TimeManager.sleep_skip_requested(day: int)`
- `TimeManager.sleep_skip_completed(day: int)`
- Existing time signals remain available:
  - `day_started(day: int)`
  - `day_ended(day: int)`
  - `hour_changed(day: int, hour: int)`
  - `time_changed(day: int, hour: int, minute: int)`

Integration expectations:

- Time thread can keep using `TimeManager.start_next_day()` internally, but should prefer listening to `sleep_skip_requested` / `sleep_skip_completed` if sleep needs extra bookkeeping.
- UI thread can listen to `SleepTransition.sleep_transition_midpoint(...)` if extra sleep UI or settlement panels need to appear inside the blackout window.

### Shipping bin

Files:

- `res://scripts/economy/ShippingBin.gd`
- `res://scenes/objects/ShippingBin.tscn`
- `res://scripts/economy/ShippingManager.gd`

Purpose:

- `ShippingBin` is a world interactable.
- Entering range opens the lid animation.
- Interacting delegates to player-side UI opening.
- `ShippingManager` stores pending sale stacks and resolves overnight sale totals.

Key callable interface:

- `ShippingManager.get_pending_stack(index: int) -> ItemStack`
- `ShippingManager.get_pending_stacks() -> Array[ItemStack]`
- `ShippingManager.get_pending_total_value() -> int`
- `ShippingManager.can_queue_from_inventory(...) -> bool`
- `ShippingManager.queue_from_inventory(...) -> bool`
- `ShippingManager.can_withdraw_to_inventory(...) -> bool`
- `ShippingManager.withdraw_to_inventory(...) -> bool`
- `ShippingManager.move_pending_to_inventory(...) -> bool`
- `ShippingManager.can_move_or_merge_pending(from_index: int, to_index: int) -> bool`
- `ShippingManager.move_or_merge_pending(from_index: int, to_index: int) -> bool`
- `ShippingManager.commit_pending_sales() -> int`

Signals exposed:

- `ShippingManager.pending_sales_changed`

Integration expectations:

- UI thread should provide `PlayerUiRoot.open_shipping_panel()` and `PlayerUiRoot.close_shipping_panel()`.
- `PlayerController.request_open_shipping_panel()` already delegates to the UI root if those methods exist.
- Economy / time thread should call `commit_pending_sales()` during overnight resolution and handle the returned gold amount.

## Data Resources

### Item data

File:

- `res://scripts/data/ItemData.gd`

Current fields:

- `id: StringName`
- `display_name: String`
- `description: String`
- `icon_texture: Texture2D`
- `stackable: bool`
- `max_stack: int`
- `item_kind: ItemData.ItemKind`
- `buy_price: int`
- `sell_price: int`
- `metadata: Dictionary`

Current `ItemKind` values:

- `GENERIC`
- `SEED`
- `CROP`
- `TOOL`
- `MATERIAL`

### Crop data

File:

- `res://scripts/data/CropData.gd`

Current fields:

- `id: StringName`
- `display_name: String`
- `description: String`
- `seed_item: ItemData`
- `harvest_item: ItemData`
- `growth_texture: Texture2D`
- `growth_frame_size: Vector2i`
- `growth_frame_count: int`
- `stage_frame_counts: PackedInt32Array`
- `days_per_stage: PackedInt32Array`
- `days_per_frame: int`
- `regrowable: bool`
- `regrow_days: int`
- `harvest_yield_min: int`
- `harvest_yield_max: int`
- `seasons: PackedStringArray`
- `metadata: Dictionary`

Important extension point:

- `regrowable` and `regrow_days` are already present for future crops such as grape.

### Current tomato resource set

Files:

- `res://resources/items/Plant/Tomato/tomato_seed.tres`
- `res://resources/items/Plant/Tomato/tomato.tres`
- `res://resources/crops/Plant/Tomato/tomato_crop.tres`

Purpose:

- This is the reference layout for future crop resource organization.
- Recommended structure is one folder per crop under both `resources/items/Plant/` and `resources/crops/Plant/`.

## UI / Input Coordination Points

Files touched from this thread:

- `res://scripts/ui/PlayerUi.gd`
- `res://scripts/ui/InventoryPanel.gd`
- `res://scenes/ui/HUD.tscn`

Purpose:

- Inventory panel opening now acquires an input lock through `SceneTransition` so dragging items does not also trigger player tool use.
- Backpack bottom row is mapped to the same hotbar data as the always-visible HUD hotbar.

Integration expectations:

- UI thread should continue using `Inventory.SECTION_HOTBAR` as the canonical source for quick-access slots.
- Any modal UI that must suppress player actions can reuse:
  - `SceneTransition.acquire_input_lock(reason)`
  - `SceneTransition.release_input_lock(reason)`

## Scene Placement Notes

Current scenes affected:

- `res://scenes/world/Farm.tscn`
- `res://scenes/objects/FarmerHouseInterior.tscn`
- `res://scenes/objects/farmer_home.tscn`

Current expectations:

- Farm interior exit uses `SceneExitArea`.
- Building entry uses `Door`.
- Bed must be instanced into the interior scene manually or by scene-thread placement if not already present.

## Recommended Next Owners

- Time thread:
  - expand `request_sleep_skip_to_next_day()`
  - connect overnight sale settlement and crop growth
- UI thread:
  - implement shipping panel open / close methods
  - optionally respond to sleep transition signals
- Crops / farm thread:
  - consume `CropData` formally for planting, stage advancement, and harvest
- Scene / map thread:
  - place bed and future furniture / interactive objects into interiors
