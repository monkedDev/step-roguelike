extends CharacterBody2D # или Node2D, главное чтоб совпадало с нодой

var max_steps: int = 3
var steps_left: int = 3

var grid_pos = Vector2i.ZERO
var is_moving = false
var tile_size = 16

# ВОТ ЭТИ ДВА СИГНАЛА ДОЛЖНЫ БЫТЬ ТУТ:
signal turn_ended()
signal steps_updated(left)

func _ready():
	reset_turn()

func reset_turn():
	steps_left = max_steps
	steps_updated.emit(steps_left)

func use_action() -> bool:
	if steps_left > 0:
		steps_left -= 1
		steps_updated.emit(steps_left)
		if steps_left == 0:
			turn_ended.emit()
		return true
	return false

func move_to(new_grid_pos: Vector2i):
	is_moving = true
	grid_pos = new_grid_pos
	var target_pixel = Vector2(grid_pos.x * tile_size + 8, grid_pos.y * tile_size + 8)
	var tween = create_tween()
	tween.tween_property(self, "position", target_pixel, 0.1)
	tween.finished.connect(func(): is_moving = false)
