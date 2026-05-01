extends Resource
class_name FrameAnimationClip

@export var start_frame: int = 0
@export var end_frame: int = 0
@export_range(1, 16, 1) var step: int = 1
@export_range(1.0, 30.0, 0.5) var fps: float = 8.0
@export var ping_pong: bool = false
@export var loop: bool = true

var _cached_frames: Array[int] = []
var _frames_dirty: bool = true

func build_frames() -> Array[int]:
	if not _frames_dirty and not _cached_frames.is_empty():
		return _cached_frames.duplicate()

	var frames: Array[int] = []
	if step <= 0:
		return frames

	if start_frame <= end_frame:
		for frame_index: int in range(start_frame, end_frame + 1, step):
			frames.append(frame_index)
	else:
		for frame_index: int in range(start_frame, end_frame - 1, -step):
			frames.append(frame_index)

	if ping_pong and frames.size() > 2:
		for reverse_index: int in range(frames.size() - 2, 0, -1):
			frames.append(frames[reverse_index])

	_cached_frames = frames.duplicate()
	_frames_dirty = false
	return frames

func get_frame_count() -> int:
	return build_frames().size()

func get_frame_at_index(frame_index: int) -> int:
	var frames: Array[int] = build_frames()
	if frames.is_empty():
		return start_frame

	var clamped_index: int = clampi(frame_index, 0, frames.size() - 1)
	return frames[clamped_index]

func get_frame_at_time(elapsed_time: float) -> int:
	var frames: Array[int] = build_frames()
	if frames.is_empty():
		return start_frame
	if fps <= 0.0:
		return frames[0]

	var raw_index: int = int(floor(elapsed_time * fps))
	if loop:
		raw_index %= frames.size()
	else:
		raw_index = clampi(raw_index, 0, frames.size() - 1)

	return frames[raw_index]
