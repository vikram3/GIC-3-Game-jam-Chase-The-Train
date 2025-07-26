extends Node

# Train Chase Game Settings
@export var total_laps = 1  # Single lap only
@export var train_speed = 150  # Train's base speed
@export var train_acceleration = 0.5
@export var train_max_speed = 200
@export var catch_distance = 5.0  # Distance needed to "catch" the train

@onready var cars = []
@onready var cars_array = []
@onready var train_node = null  # Reference to train

var finished_cars = 0
var is_game_ready = false
var is_countdown_finished = false
var car_selected = null
var is_player_race_finished = false
var show_podium = false
var train_caught = false
var winner_car = null
var race_end_time = 0.0

# Train chase specific variables
var train_current_waypoint = 0
var train_waypoints = []
var train_progress = 0.0  # Progress around the track (0-1)
var train_lap_time = 0.0

func _ready():
	# Get train waypoints (same as car waypoints but for train AI)
	train_waypoints = get_tree().get_nodes_in_group("check")

func _process(delta):
	if is_countdown_finished and !train_caught:
		train_lap_time += delta
		update_train_position(delta)
		check_train_catch()
	
	# Update car positions relative to train
	if finished_cars < cars_array.size() and !train_caught:
		for i in range(cars_array.size()):
			var car = cars[i]
			var car_data = {
				"car_name": car.car_name,
				"waypoint_checked": car.total_checked,
				"distance_to_train": calculate_distance_to_train(car),
				"distance_to_next_waypoint": car.distance_to_next_waypoint,
				"lap_number": car.current_lap,
				"best_lap": car.best_lap_time,
				"race_time": car.race_time,
				"race_position": car.race_position,
				"caught_train": car.has_caught_train if "has_caught_train" in car else false
			}
			cars_array[i] = car_data
		
		# Sort cars by distance to train (closest first)
		train_chase_sort(cars_array)
	
	# Check if race should end (train completes lap or someone catches it)
	if train_progress >= 1.0 and !train_caught:
		end_race_train_escaped()

func update_train_position(delta):
	if train_node and train_waypoints.size() > 0:
		# Move train along waypoints
		var target_pos = train_waypoints[train_current_waypoint].global_position
		var distance_to_waypoint = train_node.global_position.distance_to(target_pos)
		
		# Move towards current waypoint
		var direction = (target_pos - train_node.global_position).normalized()
		var current_speed = min(train_speed + (train_acceleration * train_lap_time), train_max_speed)
		
		train_node.global_position += direction * current_speed * delta
		
		# Check if reached waypoint
		if distance_to_waypoint < 3.0:
			train_current_waypoint += 1
			if train_current_waypoint >= train_waypoints.size():
				train_current_waypoint = 0
				train_progress = 1.0  # Completed lap
			else:
				train_progress = float(train_current_waypoint) / float(train_waypoints.size())

func calculate_distance_to_train(car):
	if train_node:
		return car.global_position.distance_to(train_node.global_position)
	return 999999.0

func check_train_catch():
	for car in cars:
		var distance_to_train = calculate_distance_to_train(car)
		if distance_to_train <= catch_distance:
			train_caught = true
			winner_car = car
			car.has_caught_train = true
			end_race_train_caught(car)
			break

func end_race_train_caught(catching_car):
	print(catching_car.car_name + " caught the train and wins!")
	race_end_time = train_lap_time
	
	# Set final positions
	for i in range(cars.size()):
		var car = cars[i]
		if car == catching_car:
			car.race_position = 1
			car.is_race_finished = true
		else:
			# Sort remaining cars by distance to train
			car.race_position = i + 2  # 2nd place onwards
			car.is_race_finished = true
	
	finished_cars = cars.size()
	show_podium = true

func end_race_train_escaped():
	print("Train escaped! Race over!")
	race_end_time = train_lap_time
	
	# Final sort by distance to train when race ended
	train_chase_sort(cars_array)
	
	for i in range(cars.size()):
		cars[i].race_position = i + 1
		cars[i].is_race_finished = true
	
	finished_cars = cars.size()
	show_podium = true

func train_chase_sort(arr):
	# Sort by: 1. If caught train (winner), 2. Distance to train (closest first)
	var n = arr.size()
	for i in range(n - 1):
		for j in range(n - i - 1):
			if compare_train_chase(arr[j], arr[j + 1]) > 0:
				var temp = arr[j]
				arr[j] = arr[j + 1]
				arr[j + 1] = temp

func compare_train_chase(a, b):
	# Winner (caught train) always comes first
	if a["caught_train"] and !b["caught_train"]:
		return -1
	elif !a["caught_train"] and b["caught_train"]:
		return 1
	# If neither or both caught train, sort by distance to train
	elif a["distance_to_train"] < b["distance_to_train"]:
		return -1
	elif a["distance_to_train"] > b["distance_to_train"]:
		return 1
	else:
		return 0

func on_game_ready():
	cars = get_tree().get_nodes_in_group("car")
	cars_array = []
	
	# Find train node
	train_node = get_tree().get_first_node_in_group("train")
	if !train_node:
		print("Warning: No train found in scene!")
	
	for car in cars:
		var car_data = {
			"car_name": car.car_name, 
			"waypoint_checked": car.total_checked, 
			"distance_to_train": calculate_distance_to_train(car),
			"distance_to_next_waypoint": car.distance_to_next_waypoint,
			"lap_number": car.current_lap,
			"best_lap": car.best_lap_time,
			"race_time": car.race_time,
			"race_position": car.race_position,
			"caught_train": false
		}
		cars_array.append(car_data)
	
	train_chase_sort(cars_array)

func get_train_progress():
	return train_progress

func get_race_status():
	if train_caught:
		return "TRAIN CAUGHT!"
	elif train_progress >= 1.0:
		return "TRAIN ESCAPED!"
	else:
		return "CHASING TRAIN..."
