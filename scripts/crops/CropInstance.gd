extends Node2D
class_name CropInstance

signal growth_advanced(crop_id: StringName, cell: Vector2i, current_frame: int, total_frames: int)
signal crop_matured(crop_id: StringName, cell: Vector2i)
signal crop_harvested(crop_id: StringName, cell: Vector2i, crop_item_id: StringName, yield_count: int)
signal crop_destroyed(crop_id: StringName, cell: Vector2i)
signal crop_watered(crop_id: StringName, cell: Vector2i)

const ACTION_HARVEST: StringName = &"harvest"
const ACTION_WATER: StringName = &"water"
const ACTION_DESTROY: StringName = &"destroy"
const WATER_HINT_BOB_SPEED: float = 2.6
const WATER_HINT_BOB_DISTANCE: float = 3.0
const HARVEST_HINT_PULSE_SPEED: float = 4.2
const HARVEST_HINT_PULSE_MIN: float = 0.72
const HARVEST_HINT_PULSE_MAX: float = 1.08

var crop_data: CropData
var cell: Vector2i = Vector2i.ZERO
var growth_days_accumulated: int = 0
var current_frame: int = 0
var current_stage: int = 0
var watered_today: bool = false
var consecutive_unwatered_days: int = 0
var seed_stage_active: bool = false
var planted_timestamp: int = 0
var is_dead: bool = false
var _resolved_visual_frames: PackedInt32Array = PackedInt32Array()
var _frame_visible_top_pixels: PackedInt32Array = PackedInt32Array()
var _seed_visible_top_pixel: int = -1
var _water_hint_base_position: Vector2 = Vector2.ZERO
var _harvest_hint_base_position: Vector2 = Vector2.ZERO
var _hint_time: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _water_hint: Sprite2D = $WaterHint
@onready var _harvest_hint: Node2D = $HarvestHint


func _ready() -> void:
	z_index = 10
	_update_visual()
	_update_hint_layout()
	_update_hint_visibility()


func _process(delta: float) -> void:
	_hint_time += delta
	_animate_hints()


func initialize(p_crop_data: CropData, p_cell: Vector2i, p_planted_time: int = 0) -> void:
	crop_data = p_crop_data
	cell = p_cell
	growth_days_accumulated = 0
	current_frame = 0
	current_stage = 0
	watered_today = false
	consecutive_unwatered_days = 0
	seed_stage_active = crop_data != null and crop_data.seed_texture != null
	is_dead = false
	planted_timestamp = p_planted_time
	_resolved_visual_frames = PackedInt32Array()
	_frame_visible_top_pixels = PackedInt32Array()
	_seed_visible_top_pixel = -1
	_update_visual()


func advance_day() -> void:
	if is_dead or crop_data == null:
		return

	var was_seed_stage_active: bool = seed_stage_active
	if watered_today:
		consecutive_unwatered_days = 0
		growth_days_accumulated += 1
		if seed_stage_active:
			seed_stage_active = false

		var days_per_frame: int = crop_data.days_per_frame
		var total_frames: int = crop_data.growth_frame_count

		var progressed_growth_days: int = maxi(growth_days_accumulated - 1, 0)
		var new_frame: int = mini(total_frames - 1, int(float(progressed_growth_days) / float(days_per_frame)))

		if was_seed_stage_active or new_frame != current_frame:
			current_frame = new_frame
			_recalculate_stage()
			_update_visual()
			growth_advanced.emit(crop_data.id, cell, current_frame, total_frames)
	else:
		consecutive_unwatered_days += 1

	watered_today = false

	if _check_mature():
		crop_matured.emit(crop_data.id, cell)

	_update_hint_visibility()


func water() -> bool:
	if is_dead or crop_data == null:
		return false

	watered_today = true
	consecutive_unwatered_days = 0
	crop_watered.emit(crop_data.id, cell)
	_update_hint_visibility()
	return true


func is_mature() -> bool:
	return _check_mature()


func harvest() -> Dictionary:
	if is_dead:
		return _error_result("crop_already_dead", "作物已不存在")

	if crop_data == null:
		return _error_result("no_crop_data", "作物数据缺失")

	if not _check_mature():
		return _error_result("crop_not_mature", "作物尚未成熟，无法收获")

	var yield_count: int = _calculate_yield()
	var harvest_item: ItemData = crop_data.harvest_item
	var harvest_item_id: StringName = harvest_item.id if harvest_item != null else &""
	var crop_id: StringName = crop_data.id

	if crop_data.regrowable:
		growth_days_accumulated = 0
		current_frame = 0
		current_stage = 0
		watered_today = false
		consecutive_unwatered_days = 0
		seed_stage_active = false
		_update_visual()
		crop_harvested.emit(crop_id, cell, harvest_item_id, yield_count)
	else:
		is_dead = true
		crop_harvested.emit(crop_id, cell, harvest_item_id, yield_count)

	_update_hint_visibility()

	return {
		"success": true,
		"action": String(ACTION_HARVEST),
		"crop_id": String(crop_id),
		"crop_item_id": String(harvest_item_id),
		"yield_count": yield_count,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"regrowable": crop_data.regrowable,
	}


func destroy() -> Dictionary:
	if is_dead:
		return _error_result("crop_already_dead", "作物已不存在")

	var crop_id: StringName = crop_data.id if crop_data != null else &""
	is_dead = true
	crop_destroyed.emit(crop_id, cell)
	_update_hint_visibility()

	return {
		"success": true,
		"action": String(ACTION_DESTROY),
		"crop_id": String(crop_id),
		"cell_x": cell.x,
		"cell_y": cell.y,
	}


func get_display_state() -> Dictionary:
	if crop_data == null:
		return {}

	var mature: bool = _check_mature()
	var total_days: int = crop_data.get_total_growth_days()

	return {
		"crop_id": String(crop_data.id),
		"cell_x": cell.x,
		"cell_y": cell.y,
		"current_frame": current_frame,
		"total_frames": crop_data.growth_frame_count,
		"current_stage": current_stage,
		"growth_days_accumulated": growth_days_accumulated,
		"consecutive_unwatered_days": consecutive_unwatered_days,
		"seed_stage_active": seed_stage_active,
		"total_growth_days": total_days,
		"watered_today": watered_today,
		"is_mature": mature,
		"is_dead": is_dead,
		"regrowable": crop_data.regrowable,
		"planted_timestamp": planted_timestamp,
	}


func get_save_state() -> Dictionary:
	var data: Dictionary = get_display_state()
	data.erase("is_mature")
	data.erase("total_growth_days")
	return data


func load_save_state(state: Dictionary) -> void:
	growth_days_accumulated = int(state.get("growth_days_accumulated", 0))
	current_frame = int(state.get("current_frame", 0))
	current_stage = int(state.get("current_stage", 0))
	consecutive_unwatered_days = int(state.get("consecutive_unwatered_days", 0))
	seed_stage_active = bool(state.get("seed_stage_active", false))
	watered_today = bool(state.get("watered_today", false))
	is_dead = bool(state.get("is_dead", false))
	planted_timestamp = int(state.get("planted_timestamp", 0))
	_update_visual()
	_update_hint_visibility()


func _update_visual() -> void:
	if _sprite == null or crop_data == null:
		print(
			"CropInstance.visual skipped | sprite_ready=%s | crop_data_ready=%s"
			% [str(_sprite != null), str(crop_data != null)]
		)
		return

	var texture: Texture2D = crop_data.growth_texture
	var is_seed_visual: bool = _is_seed_visual_active()
	if is_seed_visual:
		texture = crop_data.seed_texture

	if texture == null:
		print("CropInstance.visual skipped | crop_id=%s | reason=no_texture" % String(crop_data.id))
		return

	_sprite.texture = texture
	_sprite.offset = crop_data.seed_visual_offset if is_seed_visual else crop_data.growth_visual_offset

	var display_frame: int = -1
	if is_seed_visual:
		_sprite.region_enabled = false
	else:
		_sprite.region_enabled = true
		var frame_width: int = crop_data.growth_frame_size.x
		var frame_height: int = crop_data.growth_frame_size.y

		display_frame = _resolve_visual_frame_index(clampi(current_frame, 0, crop_data.growth_frame_count - 1))
		_sprite.region_rect = Rect2(
			display_frame * frame_width,
			0,
			frame_width,
			frame_height
		)
	_update_hint_layout()
	_update_hint_visibility()
	print(
		"CropInstance.visual updated | crop_id=%s | seed_stage=%s | frame=%d | texture_size=(%d, %d) | region=(%.1f, %.1f, %.1f, %.1f) | visible=%s"
		% [
			String(crop_data.id),
			str(is_seed_visual),
			display_frame,
			texture.get_width(),
			texture.get_height(),
			_sprite.region_rect.position.x if _sprite.region_enabled else 0.0,
			_sprite.region_rect.position.y if _sprite.region_enabled else 0.0,
			_sprite.region_rect.size.x if _sprite.region_enabled else float(texture.get_width()),
			_sprite.region_rect.size.y if _sprite.region_enabled else float(texture.get_height()),
			str(is_visible_in_tree()),
		]
	)


func _resolve_visual_frame_index(target_frame: int) -> int:
	if crop_data == null:
		return target_frame

	if _resolved_visual_frames.size() != crop_data.growth_frame_count:
		_build_visual_frame_lookup()

	if target_frame < 0 or target_frame >= _resolved_visual_frames.size():
		return target_frame

	return _resolved_visual_frames[target_frame]


func _build_visual_frame_lookup() -> void:
	_resolved_visual_frames = PackedInt32Array()
	_frame_visible_top_pixels = PackedInt32Array()
	if crop_data == null or crop_data.growth_texture == null:
		return

	var texture_image: Image = crop_data.growth_texture.get_image()
	if texture_image == null:
		return

	var frame_count: int = crop_data.growth_frame_count
	_resolved_visual_frames.resize(frame_count)
	_frame_visible_top_pixels.resize(frame_count)

	var visible_frames: Array[int] = []
	for frame_index: int in range(frame_count):
		_frame_visible_top_pixels[frame_index] = _get_frame_visible_top_pixel(texture_image, frame_index)
		if _frame_has_visible_pixels(texture_image, frame_index):
			visible_frames.append(frame_index)

	for frame_index: int in range(frame_count):
		if visible_frames.has(frame_index):
			_resolved_visual_frames[frame_index] = frame_index
			continue

		var fallback_frame: int = frame_index
		for candidate_frame: int in visible_frames:
			if candidate_frame >= frame_index:
				fallback_frame = candidate_frame
				break
			fallback_frame = candidate_frame

		_resolved_visual_frames[frame_index] = fallback_frame

	print(
		"CropInstance.visual lookup | crop_id=%s | frames=%s"
		% [String(crop_data.id), str(_resolved_visual_frames)]
	)


func _frame_has_visible_pixels(texture_image: Image, frame_index: int) -> bool:
	if crop_data == null:
		return false

	var frame_width: int = crop_data.growth_frame_size.x
	var frame_height: int = crop_data.growth_frame_size.y
	var start_x: int = frame_index * frame_width
	if start_x + frame_width > texture_image.get_width():
		return false

	for py: int in range(frame_height):
		for px: int in range(frame_width):
			var pixel: Color = texture_image.get_pixel(start_x + px, py)
			if pixel.a > 0.01:
				return true

	return false


func _is_seed_visual_active() -> bool:
	return crop_data != null and seed_stage_active and crop_data.seed_texture != null


func _get_seed_visible_top_pixel() -> int:
	if crop_data == null or crop_data.seed_texture == null:
		return 0

	if _seed_visible_top_pixel >= 0:
		return _seed_visible_top_pixel

	var texture_image: Image = crop_data.seed_texture.get_image()
	if texture_image == null:
		_seed_visible_top_pixel = 0
		return _seed_visible_top_pixel

	for py: int in range(texture_image.get_height()):
		for px: int in range(texture_image.get_width()):
			var pixel: Color = texture_image.get_pixel(px, py)
			if pixel.a > 0.01:
				_seed_visible_top_pixel = py
				return _seed_visible_top_pixel

	_seed_visible_top_pixel = 0
	return _seed_visible_top_pixel


func _get_frame_visible_top_pixel(texture_image: Image, frame_index: int) -> int:
	if crop_data == null:
		return 0

	var frame_width: int = crop_data.growth_frame_size.x
	var frame_height: int = crop_data.growth_frame_size.y
	var start_x: int = frame_index * frame_width
	if start_x + frame_width > texture_image.get_width():
		return 0

	for py: int in range(frame_height):
		for px: int in range(frame_width):
			var pixel: Color = texture_image.get_pixel(start_x + px, py)
			if pixel.a > 0.01:
				return py

	return 0


func _get_current_display_frame() -> int:
	if crop_data == null:
		return 0

	return _resolve_visual_frame_index(clampi(current_frame, 0, crop_data.growth_frame_count - 1))


func _get_visible_top_y_for_frame(display_frame: int) -> float:
	if crop_data == null:
		return 0.0

	if _is_seed_visual_active():
		var seed_texture: Texture2D = crop_data.seed_texture
		if seed_texture == null:
			return crop_data.seed_visual_offset.y
		return crop_data.seed_visual_offset.y - (float(seed_texture.get_height()) * 0.5) + float(_get_seed_visible_top_pixel())

	if _frame_visible_top_pixels.size() != crop_data.growth_frame_count:
		_build_visual_frame_lookup()

	var frame_top_pixel: int = 0
	if display_frame >= 0 and display_frame < _frame_visible_top_pixels.size():
		frame_top_pixel = _frame_visible_top_pixels[display_frame]

	return crop_data.growth_visual_offset.y - (float(crop_data.growth_frame_size.y) * 0.5) + float(frame_top_pixel)


func _update_hint_layout() -> void:
	if crop_data == null:
		return

	var display_frame: int = _get_current_display_frame()
	var crop_top_y: float = _get_visible_top_y_for_frame(display_frame)
	_water_hint_base_position = Vector2(0.0, crop_top_y) + crop_data.water_hint_offset
	_harvest_hint_base_position = Vector2(0.0, crop_top_y) + crop_data.harvest_hint_offset

	if _water_hint != null:
		_water_hint.position = _water_hint_base_position

	if _harvest_hint != null:
		_harvest_hint.position = _harvest_hint_base_position


func _update_hint_visibility() -> void:
	var should_show_harvest_hint: bool = not is_dead and _check_mature()
	var should_show_water_hint: bool = (
		not is_dead
		and not should_show_harvest_hint
		and not watered_today
		and consecutive_unwatered_days >= 2
	)

	if _water_hint != null:
		_water_hint.visible = should_show_water_hint

	if _harvest_hint != null:
		_harvest_hint.visible = should_show_harvest_hint


func _animate_hints() -> void:
	if _water_hint != null and _water_hint.visible:
		var bob_offset: float = sin(_hint_time * WATER_HINT_BOB_SPEED) * WATER_HINT_BOB_DISTANCE
		_water_hint.position = _water_hint_base_position + Vector2(0.0, bob_offset)

	if _harvest_hint != null and _harvest_hint.visible:
		var pulse_t: float = (sin(_hint_time * HARVEST_HINT_PULSE_SPEED) + 1.0) * 0.5
		var pulse_scale: float = lerpf(HARVEST_HINT_PULSE_MIN, HARVEST_HINT_PULSE_MAX, pulse_t)
		var bob_offset: float = sin(_hint_time * WATER_HINT_BOB_SPEED * 0.7) * 2.0
		_harvest_hint.position = _harvest_hint_base_position + Vector2(0.0, bob_offset)
		_harvest_hint.scale = Vector2.ONE * pulse_scale
		var pulse_alpha: float = lerpf(0.45, 1.0, pulse_t)
		for child: Node in _harvest_hint.get_children():
			var sprite_child: Sprite2D = child as Sprite2D
			if sprite_child == null:
				continue
			var color: Color = sprite_child.modulate
			color.a = pulse_alpha
			sprite_child.modulate = color


func sync_watered_state(is_watered: bool) -> void:
	watered_today = is_watered
	if is_watered:
		consecutive_unwatered_days = 0
	_update_hint_visibility()


func _recalculate_stage() -> void:
	if crop_data == null:
		return

	current_stage = crop_data.get_stage_for_frame(current_frame)


func _check_mature() -> bool:
	if crop_data == null or is_dead:
		return false

	var total_frames: int = crop_data.growth_frame_count
	var days_per_frame: int = crop_data.days_per_frame
	return current_frame >= total_frames - 1 and growth_days_accumulated >= total_frames * days_per_frame


func _calculate_yield() -> int:
	if crop_data == null:
		return 0

	var min_yield: int = crop_data.harvest_yield_min
	var max_yield: int = crop_data.harvest_yield_max
	if min_yield >= max_yield:
		return min_yield

	return randi_range(min_yield, max_yield)


func _error_result(error_code: StringName, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": String(error_code),
		"error_message": message,
	}
