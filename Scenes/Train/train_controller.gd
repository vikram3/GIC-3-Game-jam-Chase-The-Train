extends Node3D

# Train model components
@onready var train_engine = $TrainEngine  # Main locomotive (leads)
@onready var train_cars = $TrainCars      # Container for following cars
@onready var smoke_effect = $SmokeEffect
@onready var horn_sound = $HornSFX
@onready var train_sound = $TrainSFX
@onready var whistle_sound = $WhistleSFX

# Get all train car nodes
var train_car_nodes = []
var train_segments = []  # Array to hold engine + all cars

# Train movement
var waypoints = []
var current_waypoint = 0
var base_speed = 35.0  # Increased base speed
var current_speed = 5.0
var max_speed = 45.0  # Increased max speed
var acceleration = 0.8

# Train car following system
@export var car_distance = 8.0  # Distance between cars
@export var car_follow_smoothing = 12.0  # How smoothly cars follow

# Path tracking for cars to follow
var path_points = []  # Store positions that engine has been to
var max_path_points = 500  # Increased path history

# Train state
var is_moving = false
var lap_progress = 0.0
var distance_traveled = 0.0
var total_track_distance = 2000.0  # Increased track distance
var horn_timer = 0.0
var horn_interval = 20.0
var is_escaping = false

# Collision detection
var collision_area = null

func _ready():
	waypoints = get_tree().get_nodes_in_group("check")
	add_to_group("train")
	
	# Get all train car nodes
	setup_train_cars()
	
	# Setup sounds
	setup_sounds()
	
	# Initialize path tracking with enough history for all cars
	path_points = []
	max_path_points = max(500, train_car_nodes.size() * 60)
	
	# Setup collision detection
	setup_collision_detection()
	
	# Start train engine sound
	if train_sound and train_sound.stream:
		train_sound.play()
		train_sound.volume_db = -5
	
	print("Train initialized: Engine + ", train_car_nodes.size(), " cars")

func setup_train_cars():
	# Build array of all train segments (engine first, then cars)
	if train_engine:
		train_segments.append(train_engine)
	
	# Get all children of TrainCars container
	if train_cars:
		for child in train_cars.get_children():
			if child is MeshInstance3D or child is Node3D or child is CharacterBody3D:
				train_car_nodes.append(child)
				train_segments.append(child)
	
	print("Train setup: Engine + ", train_car_nodes.size(), " cars")
	
	# Sort cars by their position in scene tree to ensure proper order
	train_car_nodes.sort_custom(func(a, b): return a.get_index() < b.get_index())

func setup_collision_detection():
	# Add collision area to train engine for catching detection
	if train_engine:
		collision_area = Area3D.new()
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(12, 6, 20)  # Larger collision area
		collision_shape.shape = shape
		
		collision_area.add_child(collision_shape)
		train_engine.add_child(collision_area)
		collision_area.add_to_group("train")
		
		# Connect signals for collision detection
		collision_area.area_entered.connect(_on_collision_area_entered)
		collision_area.body_entered.connect(_on_collision_body_entered)

func _on_collision_area_entered(area):
	if area.is_in_group("car_body"):
		var car = area.get_parent().get_parent()  # Navigate to car controller
		if car and car.has_method("catch_train"):
			car.catch_train()

func _on_collision_body_entered(body):
	if body.is_in_group("car") or body.name.contains("car"):
		if body.has_method("catch_train"):
			body.catch_train()

func setup_sounds():
	# Load sound files if they exist
	if train_sound:
		# train_sound.stream = preload("res://Assets/SFX/TrainEngine.wav")
		pass
	if horn_sound:
		# horn_sound.stream = preload("res://Assets/SFX/TrainHorn.wav")
		pass
	if whistle_sound:
		# whistle_sound.stream = preload("res://Assets/SFX/TrainWhistle.wav")
		pass

func _process(delta):
	if RaceManager.is_countdown_finished and !RaceManager.train_caught:
		move_train_engine(delta)
		move_train_cars(delta)
		update_effects(delta)
		handle_sounds(delta)
		check_chase_status()

func move_train_engine(delta):
	if waypoints.size() == 0 or !train_engine:
		return
	
	# Calculate target position for engine
	var target_pos = waypoints[current_waypoint].global_position
	var distance_to_waypoint = train_engine.global_position.distance_to(target_pos)
	
	# Dynamic speed based on being chased and race time
	var speed_multiplier = 1.0
	if is_escaping:
		speed_multiplier = 1.5
	
	# Calculate speed with improved acceleration
	var time_factor = min(RaceManager.train_lap_time * 0.1, 1.0)
	var target_speed = (base_speed + (acceleration * RaceManager.train_lap_time * 10)) * speed_multiplier
	target_speed = min(target_speed, max_speed)
	
	current_speed = lerp(current_speed, target_speed, 3.0 * delta)
	
	# Move engine towards waypoint
	var direction = (target_pos - train_engine.global_position).normalized()
	var movement = direction * current_speed * delta
	
	# Record position BEFORE moving (for proper car following)
	record_path_point(train_engine.global_position, direction)
	
	# Move the engine
	train_engine.global_position += movement
	
	# Rotate engine to face movement direction smoothly
	if direction.length() > 0.1:
		var target_rotation = atan2(direction.x, direction.z)
		train_engine.rotation.y = lerp_angle(train_engine.rotation.y, target_rotation, 5.0 * delta)
	
	# Check if reached waypoint
	if distance_to_waypoint < 8.0:  # Increased threshold
		advance_waypoint()
	
	# Update progress more accurately
	distance_traveled += current_speed * delta
	lap_progress = min(distance_traveled / total_track_distance, 1.0)

func move_train_cars(delta):
	if path_points.size() < 2:
		return
	
	# Each car follows the recorded path at appropriate distance
	for i in range(train_car_nodes.size()):
		var car = train_car_nodes[i]
		var target_distance = car_distance * (i + 1)
		
		# Get position and direction from path
		var path_data = get_path_data_at_distance(target_distance)
		
		if path_data.position != Vector3.ZERO:
			# Smoothly move car to target position
			car.global_position = car.global_position.lerp(path_data.position, car_follow_smoothing * delta)
			
			# Rotate car to face the path direction
			if path_data.direction.length() > 0.1:
				var target_rotation = atan2(path_data.direction.x, path_data.direction.z)
				car.rotation.y = lerp_angle(car.rotation.y, target_rotation, 8.0 * delta)

func record_path_point(position: Vector3, direction: Vector3):
	# Only record if position has changed significantly
	if path_points.size() == 0 or path_points[0].position.distance_to(position) > 0.3:
		var path_data = {
			"position": position,
			"direction": direction.normalized()
		}
		
		path_points.push_front(path_data)
		
		# Limit path history
		if path_points.size() > max_path_points:
			path_points.pop_back()

func get_path_data_at_distance(target_distance: float) -> Dictionary:
	if path_points.size() < 2:
		return {"position": Vector3.ZERO, "direction": Vector3.FORWARD}
	
	var accumulated_distance = 0.0
	
	# Walk back through path points until we reach the target distance
	for i in range(path_points.size() - 1):
		var current_data = path_points[i]
		var next_data = path_points[i + 1]
		var segment_distance = current_data.position.distance_to(next_data.position)
		
		if segment_distance < 0.1:
			continue
			
		if accumulated_distance + segment_distance >= target_distance:
			# The target position is somewhere in this segment
			var remaining_distance = target_distance - accumulated_distance
			var segment_ratio = remaining_distance / segment_distance
			
			# Interpolate position and direction
			var position = next_data.position.lerp(current_data.position, segment_ratio)
			var direction = next_data.direction.lerp(current_data.direction, segment_ratio).normalized()
			
			return {"position": position, "direction": direction}
		
		accumulated_distance += segment_distance
	
	# Return last available data
	if path_points.size() > 0:
		return path_points[path_points.size() - 1]
	
	return {"position": Vector3.ZERO, "direction": Vector3.FORWARD}

func advance_waypoint():
	current_waypoint += 1
	if current_waypoint >= waypoints.size():
		current_waypoint = 0
		on_lap_completed()

func on_lap_completed():
	if !RaceManager.train_caught:
		print("Train escaped! Lap completed.")
		play_whistle()
		# Don't call end race here - let RaceManager handle it based on progress

func handle_sounds(delta):
	horn_timer += delta
	
	# Play horn occasionally
	if horn_timer >= horn_interval:
		play_horn()
		horn_timer = 0.0
		# Reset timer with some randomness
		horn_interval = randf_range(15.0, 25.0)
	
	# Update train sound pitch based on speed
	if train_sound and train_sound.playing:
		var pitch = lerp(0.6, 1.6, current_speed / max_speed)
		train_sound.pitch_scale = pitch

func update_effects(delta):
	# Update smoke and other effects based on speed
	if smoke_effect:
		smoke_effect.emitting = current_speed > 20.0
		if smoke_effect.emitting:
			# Adjust particle emission based on speed
			var emission_rate = lerp(10, 50, current_speed / max_speed)
			# smoke_effect.emission_rate = emission_rate

func check_chase_status():
	var closest_distance = 999999.0
	var closest_car = null
	
	# Find closest car to engine
	for car in RaceManager.cars:
		var distance = train_engine.global_position.distance_to(car.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_car = car
	
	# Increase speed if being chased closely
	if closest_distance < 30.0 and !is_escaping:
		is_escaping = true
		print("Train is being chased! Speeding up...")
		play_whistle()
	elif closest_distance > 60.0 and is_escaping:
		is_escaping = false
		print("Train relaxing speed...")

func play_horn():
	if horn_sound and horn_sound.stream and !horn_sound.playing:
		horn_sound.play()

func play_whistle():
	if whistle_sound and whistle_sound.stream:
		whistle_sound.play()

func get_speed():
	return current_speed

func get_progress():
	return lap_progress

func is_caught():
	return RaceManager.train_caught

func spawn_at_start():
	# Find the train start position node
	var train_start_node = $TrainStartPos
	if !train_start_node:
		# Fallback: look for a node named TrainStartPos in the scene
		train_start_node = get_node_or_null("../TrainStartPos")
	
	var start_position
	if train_start_node:
		start_position = train_start_node.global_position
		print("Train spawning at train start position: ", start_position)
	else:
		# If no specific train start, use first waypoint but offset
		if waypoints.size() > 0:
			start_position = waypoints[0].global_position + Vector3(0, 2, -20)  # Offset from first waypoint
			print("No train start position found, using waypoint offset: ", start_position)
		else:
			start_position = Vector3(0, 0, 0)
			print("No waypoints or train start found, using origin")
	
	# Position engine at start
	if train_engine:
		train_engine.global_position = start_position
		
		# Initialize path with the starting position
		var initial_direction = Vector3(0, 0, 1)  # Default forward direction
		if waypoints.size() > 0:
			initial_direction = (waypoints[0].global_position - start_position).normalized()
		
		# Create initial path history
		for i in range(50):
			var back_position = start_position - (initial_direction * i * 0.5)
			record_path_point(back_position, initial_direction)
		
		# Position cars behind engine
		for i in range(train_car_nodes.size()):
			var car = train_car_nodes[i]
			var car_position = start_position - (initial_direction * car_distance * (i + 1))
			car.global_position = car_position
			car.rotation.y = atan2(initial_direction.x, initial_direction.z)
		
		# Set initial waypoint target
		if waypoints.size() > 0:
			current_waypoint = 0
			# Find closest waypoint to start position
			var closest_dist = 999999.0
			for j in range(waypoints.size()):
				var dist = start_position.distance_to(waypoints[j].global_position)
				if dist < closest_dist:
					closest_dist = dist
					current_waypoint = j
		
		print("Train spawned: Engine at ", start_position, " + ", train_car_nodes.size(), " cars")

# Get the front of the train (engine) position for collision detection
func get_front_position():
	if train_engine:
		return train_engine.global_position
	return global_position

# Method for cars to check if they can catch the train
func can_be_caught_by(car_position: Vector3) -> bool:
	if !train_engine:
		return false
	
	var distance = train_engine.global_position.distance_to(car_position)
	return distance <= RaceManager.catch_distance

# Get the train's current direction (useful for AI)
func get_current_direction() -> Vector3:
	if waypoints.size() > 0 and train_engine:
		var target = waypoints[current_waypoint].global_position
		return (target - train_engine.global_position).normalized()
	return Vector3.FORWARD
