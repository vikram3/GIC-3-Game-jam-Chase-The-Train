extends Node

# Train Chase Game Settings
@export var total_laps = 1  # Single lap only
@export var train_speed = 80  # Train's base speed (increased)
@export var train_acceleration = 0.8
@export var train_max_speed = 160
@export var catch_distance = 8.0  # Distance needed to "catch" the train (increased)

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
		check_train_catch()
		
		# Check if train completed lap
		if train_node and train_node.get_progress() >= 1.0 and !train_caught:
			end_race_train_escaped()
	
	# Update car positions relative to train
	if finished_cars < cars_array.size() and !train_caught:
		update_car_positions()

func update_car_positions():
	for i in range(cars_array.size()):
		if i < cars.size():
			var car = cars[i]
			var car_data = {
				"car_name": car.car_name,
				"waypoint_checked": car.total_checked,
				"distance_to_train": calculate_distance_to_train(car),
				"distance_to_next_waypoint": car.distance_to_next_waypoint,
				"lap_number": car.current_lap,
				"best_lap": car.best_lap_time,
				"race_time": car.current_lap_time,
				"race_position": car.race_position,
				"caught_train": car.has_caught_train if "has_caught_train" in car else false
			}
			cars_array[i] = car_data
	
	# Sort cars by distance to train (closest first)
	train_chase_sort(cars_array)
	
	# Update race positions
	for i in range(cars.size()):
		if i < cars_array.size():
			cars[i].race_position = i + 1

func calculate_distance_to_train(car):
	if train_node and train_node.has_method("get_front_position"):
		return car.global_position.distance_to(train_node.get_front_position())
	elif train_node:
		return car.global_position.distance_to(train_node.global_position)
	return 999999.0

func check_train_catch():
	# Check each car for train catching
	for i in range(cars.size()):
		var car = cars[i]
		var distance_to_train = calculate_distance_to_train(car)
		
		# Multiple ways to catch the train
		if (distance_to_train <= catch_distance or 
		   (train_node and train_node.has_method("can_be_caught_by") and train_node.can_be_caught_by(car.global_position))) and !train_caught:
			
			train_caught = true
			winner_car = car
			car.has_caught_train = true
			end_race_train_caught(car)
			break

func end_race_train_caught(catching_car):
	print(catching_car.car_name + " caught the train and wins!")
	race_end_time = train_lap_time
	
	# Set winner position
	catching_car.race_position = 1
	catching_car.is_race_finished = true
	
	# Set other cars' positions based on distance to train
	var other_cars = []
	for car in cars:
		if car != catching_car:
			other_cars.append({
				"car": car,
				"distance": calculate_distance_to_train(car)
			})
	
	# Sort other cars by distance to train
	other_cars.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Assign positions
	for i in range(other_cars.size()):
		other_cars[i].car.race_position = i + 2
		other_cars[i].car.is_race_finished = true
	
	finished_cars = cars.size()
	show_podium = true

func end_race_train_escaped():
	print("Train escaped! Race over!")
	race_end_time = train_lap_time
	
	# Final sort by distance to train when race ended
	var car_distances = []
	for car in cars:
		car_distances.append({
			"car": car,
			"distance": calculate_distance_to_train(car)
		})
	
	# Sort by distance (closest first)
	car_distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Assign final positions
	for i in range(car_distances.size()):
		car_distances[i].car.race_position = i + 1
		car_distances[i].car.is_race_finished = true
	
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
	await get_tree().process_frame  # Wait for all nodes to be ready
	
	cars = get_tree().get_nodes_in_group("car")
	cars_array = []
	
	# Find train node
	train_node = get_tree().get_first_node_in_group("train")
	if !train_node:
		print("ERROR: No train found in scene!")
		return
	else:
		print("RaceManager: Found train node")
	
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
	print("RaceManager ready: ", cars.size(), " cars registered")

func get_train_progress():
	if train_node and train_node.has_method("get_progress"):
		return train_node.get_progress()
	return 0.0

func get_race_status():
	if train_caught:
		return "TRAIN CAUGHT!"
	elif get_train_progress() >= 1.0:
		return "TRAIN ESCAPED!"
	else:
		var progress_percent = int(get_train_progress() * 100)
		return "CHASING TRAIN... (" + str(progress_percent) + "%)"
