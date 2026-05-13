extends Node
class_name TimeManager

signal day_started(day: int)
signal day_ended(day: int)
signal hour_changed(day: int, hour: int)
signal time_changed(day: int, hour: int, minute: int)
signal season_changed(season: StringName, season_index: int)
signal faint_requested(day: int)
signal pause_changed(paused: bool)
signal sleep_skip_requested(day: int)
signal sleep_skip_completed(day: int)

const SEASON_SPRING: StringName = &"spring"
const SEASON_SUMMER: StringName = &"summer"
const SEASON_FALL: StringName = &"fall"
const SEASON_WINTER: StringName = &"winter"
const SEASONS: Array[StringName] = [
	SEASON_SPRING,
	SEASON_SUMMER,
	SEASON_FALL,
	SEASON_WINTER,
]
const DAYS_PER_SEASON: int = 28
const DAYS_PER_WEEK: int = 7
const FAINT_HOUR: int = 2
const FAINT_MINUTE: int = 0
const WEEKDAY_LABELS: Array[String] = [
	"星期一",
	"星期二",
	"星期三",
	"星期四",
	"星期五",
	"星期六",
	"星期日",
]

@export_range(1, 999, 1) var starting_day: int = 1
@export_range(0, 23, 1) var starting_hour: int = 8
@export_range(0, 59, 1) var starting_minute: int = 0
@export_range(0.05, 60.0, 0.05) var real_seconds_per_game_minute: float = 1.0
@export var auto_advance_time: bool = true

var current_day: int = 1
var current_hour: int = 8
var current_minute: int = 0

var _elapsed_seconds: float = 0.0
var _pause_reasons: Dictionary = {}
var _last_emitted_hour: int = -1
var _last_emitted_season: StringName = &""
var _faint_triggered_today: bool = false


func _ready() -> void:
	current_day = starting_day
	current_hour = starting_hour
	current_minute = starting_minute
	_last_emitted_hour = current_hour
	_last_emitted_season = get_current_season()
	time_changed.emit(current_day, current_hour, current_minute)
	hour_changed.emit(current_day, current_hour)


func _process(delta: float) -> void:
	if not auto_advance_time or is_time_paused():
		return

	_elapsed_seconds += delta
	while _elapsed_seconds >= real_seconds_per_game_minute:
		_elapsed_seconds -= real_seconds_per_game_minute
		advance_minute()


func set_time(day: int, hour: int, minute: int = 0, emit_signals: bool = true) -> void:
	var previous_season: StringName = get_current_season()
	current_day = max(day, 1)
	current_hour = clampi(hour, 0, 23)
	current_minute = clampi(minute, 0, 59)
	_elapsed_seconds = 0.0
	_faint_triggered_today = false
	if not emit_signals:
		_last_emitted_hour = current_hour
		_last_emitted_season = get_current_season()
		return

	time_changed.emit(current_day, current_hour, current_minute)
	_emit_hour_changed_if_needed(true)
	_emit_season_changed_if_needed(previous_season)
	_check_for_faint()


func advance_minute(minutes: int = 1) -> void:
	if minutes <= 0:
		return

	for _step: int in range(minutes):
		current_minute += 1
		if current_minute >= 60:
			current_minute = 0
			current_hour = (current_hour + 1) % 24

		time_changed.emit(current_day, current_hour, current_minute)
		_emit_hour_changed_if_needed()
		_check_for_faint()


func advance_hour(hours: int = 1) -> void:
	if hours <= 0:
		return

	for _step: int in range(hours):
		advance_minute(60)


func start_next_day() -> void:
	var previous_season: StringName = get_current_season()
	day_ended.emit(current_day)
	current_day += 1
	current_hour = starting_hour
	current_minute = starting_minute
	_elapsed_seconds = 0.0
	_faint_triggered_today = false
	day_started.emit(current_day)
	time_changed.emit(current_day, current_hour, current_minute)
	_emit_hour_changed_if_needed(true)
	_emit_season_changed_if_needed(previous_season)


func request_sleep_skip_to_next_day() -> void:
	sleep_skip_requested.emit(current_day)
	start_next_day()
	sleep_skip_completed.emit(current_day)


func pause_time(reason: StringName = &"default") -> void:
	var was_paused: bool = is_time_paused()
	_pause_reasons[reason] = true
	if not was_paused:
		pause_changed.emit(true)


func resume_time(reason: StringName = &"default") -> void:
	if not _pause_reasons.has(reason):
		return

	_pause_reasons.erase(reason)
	if _pause_reasons.is_empty():
		pause_changed.emit(false)


func clear_time_pauses() -> void:
	if _pause_reasons.is_empty():
		return

	_pause_reasons.clear()
	pause_changed.emit(false)


func is_time_paused() -> bool:
	return not _pause_reasons.is_empty()


func get_day_of_season() -> int:
	return ((current_day - 1) % DAYS_PER_SEASON) + 1


func get_weekday_index() -> int:
	return ((current_day - 1) % DAYS_PER_WEEK) + 1


func get_weekday_label() -> String:
	return WEEKDAY_LABELS[get_weekday_index() - 1]


func get_current_season_index() -> int:
	return floori(float(current_day - 1) / float(DAYS_PER_SEASON)) % SEASONS.size()


func get_current_season() -> StringName:
	return SEASONS[get_current_season_index()]


func is_winter() -> bool:
	return get_current_season() == SEASON_WINTER


func can_plant_in_current_season(allowed_seasons: Array[StringName] = []) -> bool:
	if is_winter():
		return false
	if allowed_seasons.is_empty():
		return true

	return allowed_seasons.has(get_current_season())


func get_time_label() -> String:
	return "%02d:%02d" % [current_hour, current_minute]


func _check_for_faint() -> void:
	if _faint_triggered_today:
		return
	if current_hour != FAINT_HOUR or current_minute != FAINT_MINUTE:
		return

	_faint_triggered_today = true
	faint_requested.emit(current_day)
	start_next_day()


func _emit_hour_changed_if_needed(force: bool = false) -> void:
	if not force and _last_emitted_hour == current_hour:
		return

	_last_emitted_hour = current_hour
	hour_changed.emit(current_day, current_hour)


func _emit_season_changed_if_needed(previous_season: StringName) -> void:
	var current_season: StringName = get_current_season()
	if current_season == previous_season and _last_emitted_season == current_season:
		return

	_last_emitted_season = current_season
	season_changed.emit(current_season, get_current_season_index())
