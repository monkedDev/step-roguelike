extends Node2D

@onready var grid_map: TileMapLayer = $GridMap
@onready var ap_container: HBoxContainer = $UI/HBoxContainer # Путь к твоему контейнеру иконок

var player_scene = preload("res://scenes/player.tscn")
var player: Node2D = null

var map_size = Vector2i(40, 40)
var fill_percent = 0.45 
var tile_size = 16
var floor_tiles: Array = []

enum Turn { PLAYER, ENEMY }
var current_turn = Turn.PLAYER

var markers_container: Node2D = null

func _ready():
	randomize()
	
	# Контейнер для подсветки клеток вокруг игрока
	markers_container = Node2D.new()
	add_child(markers_container)
	
	generate_cave()
	spawn_player()

func generate_cave():
	# Забиваем всё стенами (wall.png - ID источника 1)
	for x in range(map_size.x):
		for y in range(map_size.y):
			grid_map.set_cell(Vector2i(x, y), 1, Vector2i(0, 0))
	
	var cells_to_dig = int(map_size.x * map_size.y * fill_percent)
	var dug_cells = 0
	var current_pos = map_size / 2
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while dug_cells < cells_to_dig:
		if not current_pos in floor_tiles:
			floor_tiles.append(current_pos)
			# Рисуем пол (empty_tile.png - ID источника 0)
			grid_map.set_cell(current_pos, 0, Vector2i(0, 0))
			dug_cells += 1
		current_pos += directions[randi() % directions.size()]
		current_pos.x = clamp(current_pos.x, 1, map_size.x - 2)
		current_pos.y = clamp(current_pos.y, 1, map_size.y - 2)

func spawn_player():
	if floor_tiles.is_empty(): return
	
	player = player_scene.instantiate()
	player.grid_pos = floor_tiles.front()
	player.tile_size = tile_size
	
	player.turn_ended.connect(_on_player_turn_ended)
	player.steps_updated.connect(_on_player_steps_updated)
	
	add_child(player)
	player.position = Vector2(player.grid_pos * tile_size) + Vector2(8, 8)
	
	player.reset_turn()
	update_navigation_markers()

func _unhandled_input(event):
	if current_turn != Turn.PLAYER or player.is_moving: return
	
	var move_dir = Vector2i.ZERO
	if event.is_action_pressed("ui_up"):    move_dir = Vector2i.UP
	if event.is_action_pressed("ui_down"):  move_dir = Vector2i.DOWN
	if event.is_action_pressed("ui_left"):  move_dir = Vector2i.LEFT
	if event.is_action_pressed("ui_right"): move_dir = Vector2i.RIGHT
	
	if move_dir != Vector2i.ZERO:
		var target_pos = player.grid_pos + move_dir
		
		if target_pos in floor_tiles:
			if player.use_action():
				player.move_to(target_pos)
				await get_tree().create_timer(0.12).timeout
				update_navigation_markers()

# Подсветка клеток вокруг выжившего
func update_navigation_markers():
	for child in markers_container.get_children():
		child.queue_free()
	
	if current_turn != Turn.PLAYER: return
	
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var check_pos = player.grid_pos + dir
		if check_pos in floor_tiles:
			var marker = Sprite2D.new()
			marker.texture = load("res://sprites/step_select.png")
			marker.position = Vector2(check_pos.x * tile_size + 8, check_pos.y * tile_size + 8)
			markers_container.add_child(marker)

# Иконки-ромбики на экране
func _on_player_steps_updated(left):
	# Удаляем старые иконки из контейнера UI
	for child in ap_container.get_children():
		child.queue_free()
	
	# Рисуем столько ромбиков, сколько шагов осталось
	for i in range(left):
		var texture_rect = TextureRect.new()
		texture_rect.texture = load("res://sprites/step_select.png")
		# ИСПРАВЛЕНО: Правильный пиксельный фильтр без мыла
		texture_rect.texture_filter = Control.TEXTURE_FILTER_NEAREST
		ap_container.add_child(texture_rect)

func _on_player_turn_ended():
	current_turn = Turn.ENEMY
	update_navigation_markers()
	
	# Очищаем иконки на ход врага
	for child in ap_container.get_children():
		child.queue_free()
	
	await get_tree().create_timer(0.5).timeout
	
	current_turn = Turn.PLAYER
	player.reset_turn()
	update_navigation_markers()
