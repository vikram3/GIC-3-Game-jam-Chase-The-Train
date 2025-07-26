extends Node3D

# Train model components
@onready var train_engine = $TrainEngine
@onready var train_cars = $TrainCars  # Multiple train cars
@onready var smoke_effect = $SmokeLeft
@onready var horn_sound = $HornSFX
@onready var train_sound = $TrainSFX
@onready var whistle_sound = $WhistleSFX

# Train movement
var waypoints = []
var current_waypoint = 0
var base_speed = 5.0
var current_speed = 0.0
var max_speed = 10.0
var acceleration = 0.5
var horn_timer = 0.0
var horn_interval = 15.0  # Horn every 15 seconds

# Train state
var is_moving = false
var lap_progress = 0.0
var distance_traveled = 0.0
var total_track_distance = 1000.0  # Approximate track length

# Visual effects
var smoke_intensity = 1.0
var is_escaping = false

func _ready():
	# Get waypoints for train movement
	waypoints = get_tree().get_nodes_in_group("check")
	add_to_group("train")
	
	# Setup train sounds
	train_sound.stream = preload("res://Assets/SFX/Train/trainEngine.mp3")  # You'll need to add this
	horn_sound.stream = preload("res://Assets/SFX/Train/trainHorn.mp3")    # You'll need to add this
	whistle_sound.stream = preload("res://Assets/SFX/Train/TrainWhistle.mp3") # You'll need to add this
	
	# Start train engine sound
	if train_sound.stream:
		train_sound.play()
		train_sound.volume_db = -5

func _process(delta):
	if RaceManager.is_countdown_finished and !RaceManager.train_caught:
		move_train(delta)
		update_effects(delta)
		horn_timer += delta
		
		# Play horn occasionally
		if horn_timer >= horn_interval:
			play_horn()
			horn_timer = 0.0
		
		# Check if train is being chased closely
		check_chase_status()

func move_train(delta):
	if waypoints.size() == 0:
		return
	
	# Calculate target position
	var target_pos = waypoints[current_waypoint].global_position
	var distance_to_waypoint = global_position.distance_to(target_pos)
	
	# Accelerate train over time
	var target_speed = min(base_speed + (acceleration * RaceManager.train_lap_time), max_speed)
	current_speed = lerp(current_speed, target_speed, 2.0 * delta)
	
	# Move towards waypoint
	var direction = (target_pos - global_position).normalized()
	global_position += direction * current_speed * delta
	
	# Rotate train to face movement direction
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 3.0 * delta)
	
	# Check if reached waypoint
	if distance_to_waypoint < 5.0:
		advance_waypoint()
	
	# Update progress
	distance_traveled += current_speed * delta
	lap_progress = distance_traveled / total_track_distance
	
	# Clamp progress to 0-1
	if lap_progress >= 1.0:
		lap_progress = 1.0
		on_lap_completed()

func advance_waypoint():
	current_waypoint += 1
	if current_waypoint >= waypoints.size():
		current_waypoint = 0
		# Train completed a lap
		on_lap_completed()

func on_lap_completed():
	print("Train completed the lap!")
	play_whistle()
	RaceManager.end_race_train_escaped()

func update_effects(delta):
	pass
	# Update smoke based on speed
	#if smoke_effect:
		#smoke_intensity = current_speed / max_speed
		#smoke_effect.process_material.emission = lerp(smoke_effect.process_material.emission, smoke_intensity * 100, delta * 2)
	
	# Update train sound pitch based on speed
	if train_sound.playing:
		var pitch = lerp(0.8, 1.4, current_speed / max_speed)
		train_sound.pitch_scale = pitch

func check_chase_status():
	var closest_distance = 999999.0
	var closest_car = null
	
	# Find closest car
	for car in RaceManager.cars:
		var distance = global_position.distance_to(car.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_car = car
	
	# If car is very close, increase train speed (panic mode)
	if closest_distance < 20.0:
		if !is_escaping:
			is_escaping = true
			base_speed *= 1.2  # 20% speed boost when being chased
			play_whistle()  # Panic whistle
	elif closest_distance > 50.0:
		if is_escaping:
			is_escaping = false
			base_speed = 150.0  # Return to normal speed

func play_horn():
	if horn_sound.stream and !horn_sound.playing:
		horn_sound.play()

func play_whistle():
	if whistle_sound.stream:
		whistle_sound.play()

func get_speed():
	return current_speed

func get_progress():
	return lap_progress

func is_caught():
	return RaceManager.train_caught

# Function to spawn train at starting position
func spawn_at_start():
	if waypoints.size() > 0:
		global_position = waypoints[0].global_position
		current_waypoint = 1  # Next waypoint to go to
