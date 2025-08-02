extends Node3D

# Car preloads (same as original)
@onready var car1 = preload("res://Scenes/Car/bronco.tscn")
@onready var car2 = preload("res://Scenes/Car/datssun.tscn")
@onready var car3 = preload("res://Scenes/Car/r12.tscn")
@onready var car4 = preload("res://Scenes/Car/lyon.tscn")

# Train preload
@onready var train_scene = preload("res://Scenes/Train/train.tscn")

# UI preloads
@onready var podium = preload("res://Scenes/HUD/podium.tscn")
var podium_instance
var show_podium = false

# Auto-restart variables
var restart_timer: Timer
var podium_display_time = 5.0  # Show podium for 5 seconds before restart
var game_ended = false

# Instances
var car1_instance
var car2_instance
var car3_instance
var car4_instance
var train_instance

func _ready():
	# Setup restart timer
	setup_restart_timer()
	
	# Order is important: train first, then cars, then setup
	instantiate_train()
	await get_tree().process_frame  # Wait one frame for train to initialize
	instantiate_cars()
	setup_player_car()
	initialize_race_manager()

func setup_restart_timer():
	# Create timer for auto-restart
	restart_timer = Timer.new()
	restart_timer.wait_time = podium_display_time
	restart_timer.one_shot = true
	restart_timer.timeout.connect(_on_restart_timer_timeout)
	add_child(restart_timer)

func instantiate_train():
	# Create and position the train
	train_instance = train_scene.instantiate()
	get_parent().add_child(train_instance)
	
	# Make sure train spawns at correct position
	var train_start_pos = $TrainStartPos
	if train_start_pos:
		# Add the train start position to a group so train can find it
		train_start_pos.add_to_group("train_start")
		print("Train start position set: ", train_start_pos.global_position)
	else:
		print("WARNING: TrainStartPos node not found! Train may spawn at wrong position.")
	
	# Initialize train at start position
	train_instance.spawn_at_start()
	
	print("Train instantiated and positioned!")

func instantiate_cars():
	# Create all car instances with proper spacing from train
	car1_instance = car1.instantiate()
	get_parent().add_child(car1_instance)
	car1_instance.global_transform.origin = $StartingPos1.global_transform.origin
	car1_instance.add_to_group("car")
	
	car2_instance = car2.instantiate()
	get_parent().add_child(car2_instance)
	car2_instance.global_transform.origin = $StartingPos2.global_transform.origin
	car2_instance.add_to_group("car")
	
	car3_instance = car3.instantiate()
	get_parent().add_child(car3_instance)
	car3_instance.global_transform.origin = $StartingPos3.global_transform.origin
	car3_instance.add_to_group("car")
	
	car4_instance = car4.instantiate()
	get_parent().add_child(car4_instance)
	car4_instance.global_transform.origin = $StartingPos4.global_transform.origin
	car4_instance.add_to_group("car")
	
	print("All cars instantiated and positioned!")

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
	
	print("Player car setup complete: Car ", RaceManager.car_selected)

func initialize_race_manager():
	# Get all cars and initialize race data
	await get_tree().process_frame  # Ensure all nodes are ready
	
	RaceManager.cars = get_tree().get_nodes_in_group("car")
	RaceManager.cars_array = []
	
	# Add train reference to race manager
	RaceManager.train_node = train_instance
	
	# Initialize car data for race manager
	for car in RaceManager.cars:
		var car_data = {
			"car_name": car.car_name, 
			"waypoint_checked": car.total_checked, 
			"distance_to_train": 999999.0,  # Will be calculated in first update
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
	
	print("Race Manager initialized with ", RaceManager.cars.size(), " cars and train")

func _process(delta):
	# Show podium when race ends
	if should_show_podium() and RaceManager.show_podium and !show_podium and !game_ended:
		show_podium = true
		game_ended = true
		podium_instance = podium.instantiate()
		add_child(podium_instance)
		RaceManager.show_podium = false
		
		# Start countdown to restart
		restart_timer.start()
		print("Showing podium - race ended. Restarting in ", podium_display_time, " seconds...")

func should_show_podium():
	# Show podium when train is caught OR train escapes OR all cars finish
	var train_escaped = train_instance and train_instance.get_progress() >= 1.0
	var all_cars_finished = RaceManager.finished_cars >= RaceManager.cars_array.size()
	
	return (RaceManager.train_caught or train_escaped or all_cars_finished)

func _on_restart_timer_timeout():
	# Clean up current game state
	cleanup_game_state()
	
	# Reset RaceManager state
	reset_race_manager()
	
	# Restart the current scene
	print("Auto-restarting game...")
	get_tree().reload_current_scene()

func cleanup_game_state():
	# Remove podium if it exists
	if podium_instance and is_instance_valid(podium_instance):
		podium_instance.queue_free()
	
	# Clean up car instances
	if car1_instance and is_instance_valid(car1_instance):
		car1_instance.queue_free()
	if car2_instance and is_instance_valid(car2_instance):
		car2_instance.queue_free()
	if car3_instance and is_instance_valid(car3_instance):
		car3_instance.queue_free()
	if car4_instance and is_instance_valid(car4_instance):
		car4_instance.queue_free()
	
	# Clean up train instance
	if train_instance and is_instance_valid(train_instance):
		train_instance.queue_free()

func reset_race_manager():
	# Reset all RaceManager variables to initial state
	RaceManager.cars = []
	RaceManager.cars_array = []
	RaceManager.train_node = null
	RaceManager.train_caught = false
	RaceManager.show_podium = false
	RaceManager.finished_cars = 0
	RaceManager.race_started = false
	RaceManager.race_time = 0.0
	
	# Reset any other RaceManager variables you might have
	# Add more resets here if your RaceManager has additional state variables

# Optional: Add manual restart functionality (e.g., if player presses R key)
func _input(event):
	if event.is_action_pressed("ui_accept") and show_podium:  # Enter key during podium
		print("Manual restart triggered")
		restart_timer.stop()
		_on_restart_timer_timeout()

# Optional: Allow configuring restart delay
func set_restart_delay(seconds: float):
	podium_display_time = seconds
	if restart_timer:
		restart_timer.wait_time = podium_display_time
