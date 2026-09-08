extends Node2D

# --- Переменные настроек ---
var tile_size = 16
var map_size = Vector2i(35, 35)
var fill_percent = 0.40

# --- Очередь ходов ---
enum Turn { PLAYER, ENEMY }
var current_turn = Turn.PLAYER

# --- Ссылки на объекты и массивы (То, что забыл Орнит) ---
var floor_tiles: Array[Vector2i] = [] # Хранит координаты всех раскопанных полов
var player: CharacterBody2D = null    # Ссылка на созданного игрока
var exit_sprite: Sprite2D = null      # Ссылка на спрайт выхода
var exit_grid_pos: Vector2i = Vector2i.ZERO # Сетка координат выхода

# --- Контейнеры для порядка в дереве узлов ---
var markers_container: Node2D
var walls_container: Node2D
var floor_container: Node2D

# --- Предзагрузка сцены игрока ---
@onready var player_scene = preload("res://scenes/player.tscn")

func _ready():
	randomize()
	
	# Создаем контейнеры, чтобы ноды не путались
	markers_container = Node2D.new()
	walls_container = Node2D.new()
	floor_container = Node2D.new()
	
	add_child(markers_container)
	add_child(walls_container)
	add_child(floor_container)
	
	# Запуск генерации
	generate_new_cave_level()

func generate_new_cave_level():
	# КРИТИЧЕСКИЙ ФИКС: Очищаем старый уровень перед генерацией нового!
	floor_tiles.clear()
	for child in floor_container.get_children(): child.queue_free()
	for child in walls_container.get_children(): child.queue_free()
	if exit_sprite != null:
		exit_sprite.queue_free()
		exit_sprite = null

	# Алгоритм "Пьяного мастера" (Раскопка пещеры)
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

	# Спавним спрайты полов и стен на основе сетки
	for x in range(map_size.x):
		for y in range(map_size.y):
			var pos = Vector2i(x, y)
			if pos in floor_tiles:
				add_floor(pos)
			else:
				add_wall(pos)

	# Создаем игрока, если его еще нет в игре
	if player == null:
		player = player_scene.instantiate()
		player.tile_size = tile_size
		player.turn_ended.connect(_on_player_turn_ended)
		player.steps_updated.connect(_on_player_steps_updated)
		add_child(player)

	# Ставим игрока в самую первую раскопанную точку пещеры
	var start_cell = floor_tiles.front()
	player.grid_pos = start_cell
	player.position = Vector2(start_cell.x * tile_size + 8, start_cell.y * tile_size + 8)
	player.reset_turn()

	# ФИКС: Запоминаем координату выхода и спавним его в самом конце пещеры
	exit_grid_pos = floor_tiles.back()
	exit_sprite = Sprite2D.new()
	exit_sprite.texture = load("res://sprites/move.png")
	exit_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	exit_sprite.position = Vector2(exit_grid_pos.x * tile_size + 8, exit_grid_pos.y * tile_size + 8)
	add_child(exit_sprite)

	# Обновляем маркеры доступных ходов вокруг игрока
	update_navigation_markers()

func add_floor(pos):
	var sprite = Sprite2D.new()
	sprite.texture = load("res://sprites/step_select.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(pos.x * tile_size + 8, pos.y * tile_size + 8)
	floor_container.add_child(sprite)

func add_wall(pos):
	var sprite = Sprite2D.new()
	sprite.texture = load("res://sprites/wall.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = Vector2(pos.x * tile_size + 8, pos.y * tile_size + 8)
	walls_container.add_child(sprite)

func update_navigation_markers():
	for child in markers_container.get_children():
		child.queue_free()

	if current_turn != Turn.PLAYER: return

	var dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in dirs:
		var check_pos = player.grid_pos + dir
		if check_pos in floor_tiles:
			var marker = Sprite2D.new()
			marker.texture = load("res://sprites/empty_tile.png")
			marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			marker.position = Vector2(check_pos.x * tile_size + 8, check_pos.y * tile_size + 8)
			markers_container.add_child(marker)

func _unhandled_input(event):
	if current_turn != Turn.PLAYER or player.is_moving: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var global_click = get_global_mouse_position()
		var clicked_pos = Vector2i(floor(global_click.x / tile_size), floor(global_click.y / tile_size))

		var dist = (clicked_pos - player.grid_pos).abs()
		if dist.x + dist.y == 1 and clicked_pos in floor_tiles:
			if player.use_action():
				player.move_to(clicked_pos)
				
				# Небольшое ожидание завершения шага игрока перед проверкой условий
				await get_tree().create_timer(0.13).timeout

				# Проверяем, наступил ли игрок на выход
				if player.grid_pos == exit_grid_pos:
					print("Спуск на следующий уровень...")
					generate_new_cave_level()
					return

				update_navigation_markers()

func _on_player_steps_updated(left):
	pass

func _on_player_turn_ended():
	current_turn = Turn.ENEMY
	update_navigation_markers()
	await get_tree().create_timer(0.4).timeout
	current_turn = Turn.PLAYER
	player.reset_turn()
	update_navigation_markers()
