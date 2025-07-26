extends Node3D

# Car preloads (same as original)
@onready var car1 = preload("res://Scenes/Car/bronco.tscn")
@onready var car2 = preload("res://Scenes/Car/datssun.tscn")
@onready var car3 = preload("res://Scenes/Car/r12.tscn")
@onready var car4 = preload("res://Scenes/Car/lyon.tscn")

# Train preload (NEW)
@onready var train_scene = preload("res://Scenes/Train/train.tscn")

# UI preloads
@onready var podium = preload("res://Scenes/HUD/podium.tscn")
var podium_instance
var show_podium = false

# Instances
var car1_instance
var car2_instance
var car3_instance
var car4_instance
var train_instance

func _ready():
	instantiate_train()
	instantiate_cars()
	setup_player_car()
	initialize_race_manager()

func instantiate_train():
	# Create and position the train
	train_instance = train_scene.instantiate()
	get_parent().add_child(train_instance)
	
	# Position train at the starting line (slightly ahead)
	train_instance.global_transform.origin = $TrainStartPos.global_transform.origin
	train_instance.spawn_at_start()
	
	print("Train spawned and ready!")

func instantiate_cars():
	# Create all car instances
	car1_instance = car1.instantiate()
	get_parent().add_child(car1_instance)
	car1_instance.global_transform.origin = $StartingPos1.global_transform.origin
	
	car2_instance = car2.instantiate()
	get_parent().add_child(car2_instance)
	car2_instance.global_transform.origin = $StartingPos2.global_transform.origin
	
	car3_instance = car3.instantiate()
	get_parent().add_child(car3_instance)
	car3_instance.global_transform.origin = $StartingPos3.global_transform.origin
	
	car4_instance = car4.instantiate()
	get_parent().add_child(car4_instance)
	car4_instance.global_transform.origin = $StartingPos4.global_transform.origin

func setup_player_car():
	# Set the selected car as player-controlled
	match RaceManager.car_selected:
		1: # Canyonero
			car1_instance.is_AI = false
			car1_instance.add_to_group("player")
			car1_instance.cam.current = true
			car1_instance.car_name = "player"
		2: # Sunny
			car2_instance.is_AI = false
			car2_instance.cam.current = true
			car2_instance.add_to_group("player")
			car2_instance.car_name = "player"
		3: # R12
			car3_instance.is_AI = false
			car3_instance.cam.current = true
			car3_instance.add_to_group("player")
			car3_instance.car_name = "player"
		4: # Feline
			car4_instance.is_AI = false
			car4_instance.cam.current = true
			car4_instance.add_to_group("player")
			car4_instance.car_name = "player"

func initialize_race_manager():
	# Get all cars and initialize race data
	RaceManager.cars = get_tree().get_nodes_in_group("car")
	RaceManager.cars_array = []
	
	# Add train reference to race manager
	RaceManager.train_node = train_instance
	
	# Initialize car data for race manager
	for car in RaceManager.cars:
		var car_data = {
			"car_name": car.car_name, 
			"waypoint_checked": car.total_checked, 
			"distance_to_train": car.distance_to_train,
			"distance_to_next_waypoint": car.distance_to_next_waypoint,
			"lap_number": car.current_lap,
			"best_lap": car.best_lap_time,
			"race_time": car.race_time,
			"race_position": car.race_position,
			"caught_train": false
		}
		RaceManager.cars_array.append(car_data)
	
	# Call race manager setup
	RaceManager.on_game_ready()

func _process(delta):
	# Show podium when race ends
	if should_show_podium() and RaceManager.show_podium:
		podium_instance = podium.instantiate()
		add_child(podium_instance)
		RaceManager.show_podium = false

func should_show_podium():
	# Show podium when train is caught OR train escapes
	return (RaceManager.train_caught or (train_instance and train_instance.get_progress() >= 1.0)) and RaceManager.finished_cars == RaceManager.cars_array.size()
