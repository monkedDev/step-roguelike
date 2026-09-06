extends Node2D

var tile_size = 16
var floor_tiles: Array = []

var map_size = Vector2i(35, 35)
var fill_percent = 0.40 

var player_scene = preload("res://scenes/player.tscn")
var player: Node2D = null

enum Turn { PLAYER, ENEMY }
var current_turn = Turn.PLAYER

var markers_container: Node2D = null
var walls_container: Node2D = null
var floor_container: Node2D = null

var exit_grid_pos = Vector2i.ZERO
var exit_sprite: Sprite2D = null

func _ready():
	randomize()
	
	markers_container = Node2D.new()
	add_child(markers_container)
	
	walls_container = Node2D.new()
	add_child(walls_container)
	
	floor_container = Node2D.new()
	add_child(floor_container)
	
	generate_new_cave_level()

func generate_new_cave_level():
	floor_tiles.clear()
	
	for child in walls_container.get_children(): child.queue_free()
	for child in floor_container.get_children(): child.queue_free()
	if exit_sprite != null:
		exit_sprite.queue_free()
		exit_sprite = null
		
	# Алгоритм "Пьяницы" копает пещеру в памяти
	var cells_to_dig = int(map_size.x * map_size.y * fill_percent)
	var dug_cells = 0
	var current_pos = map_size / 2
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	while dug_cells < cells_to_dig:
		if not current_pos in floor_tiles:
			floor_tiles.append(current_pos)
			dug_cells += 1
		current_pos += directions[randi() % directions.size()]
		current_pos.x = clamp(current_pos.x, 1, map_size.x - 2)
		current_pos.y = clamp(current_pos.y, 1, map_size.y - 2)
		
	# ЖЕСТКАЯ ОТРИСОВКА СПРАЙТАМИ: Больше никаких скрытых ID в Godot!
	for x in range(map_size.x):
		for y in range(map_size.y):
			var check_pos = Vector2i(x, y)
			
			if check_pos in floor_tiles:
				var floor_sprite = Sprite2D.new()
				floor_sprite.texture = load("res://sprites/step_select.png")
				floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				floor_sprite.centered = true
				floor_sprite.position = Vector2(x * tile_size + 8, y * tile_size + 8)
				floor_container.add_child(floor_sprite)
			else:
				var wall_sprite = Sprite2D.new()
				wall_sprite.texture = load("res://sprites/wall.png")
				wall_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				wall_sprite.centered = true
				wall_sprite.position = Vector2(x * tile_size + 8, y * tile_size + 8)
				walls_container.add_child(wall_sprite)

	# Спавн игрока (БЕЗОПАСНЫЙ ВАРИАНТ)
	if player == null:
		player = player_scene.instantiate()
		player.tile_size = tile_size
		player.turn_ended.connect(_on_player_turn_ended)
		player.steps_updated.connect(_on_player_steps_updated)
		add_child(player)
		
	# ИСПРАВЛЕНО: Используем .front() вместо скрытых скобок разметки
	var start_cell = floor_tiles.front()
	player.grid_pos = start_cell
	
	var spawn_px = start_cell.x * tile_size + 8
	var spawn_py = start_cell.y * tile_size + 8
	player.position = Vector2(spawn_px, spawn_py)
	
	player.reset_turn()
	
	# Точка выхода (ИСПРАВЛЕНО: Используем .back())
	exit_grid_pos = floor_tiles.back()
	exit_sprite = Sprite2D.new()
	exit_sprite.texture = load("res://sprites/move.png")
	exit_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	exit_sprite.position = Vector2(exit_grid_pos.x * tile_size + 8, exit_grid_pos.y * tile_size + 8)
	add_child(exit_sprite)
	
	update_navigation_markers()

func _unhandled_input(event):
	if current_turn != Turn.PLAYER or player.is_moving: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var global_click_pos = get_global_mouse_position()
		var clicked_grid_pos = Vector2i(floor(global_click_pos.x / tile_size), floor(global_click_pos.y / tile_size))
		
		var distance = (clicked_grid_pos - player.grid_pos).abs()
		var is_neighbor = (distance.x + distance.y == 1)
		
		if is_neighbor and clicked_grid_pos in floor_tiles:
			if player.use_action():
				player.move_to(clicked_grid_pos)
				await get_tree().create_timer(0.13).timeout
				
				if player.grid_pos == exit_grid_pos:
					print("Спуск на следующий уровень...")
					generate_new_cave_level()
					return
					
				update_navigation_markers()

func update_navigation_markers():
	for child in markers_container.get_children():
		child.queue_free()
		
	if current_turn != Turn.PLAYER: return
	
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var check_pos = player.grid_pos + dir
		if check_pos in floor_tiles:
			var marker = Sprite2D.new()
			marker.texture = load("res://sprites/empty_tile.png")
			marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			marker.position = Vector2(check_pos.x * tile_size + 8, check_pos.y * tile_size + 8)
			markers_container.add_child(marker)

func _on_player_steps_updated(left):
	pass

func _on_player_turn_ended():
	current_turn = Turn.ENEMY
	update_navigation_markers()
	await get_tree().create_timer(0.4).timeout
	current_turn = Turn.PLAYER
	player.reset_turn()
	update_navigation_markers()
