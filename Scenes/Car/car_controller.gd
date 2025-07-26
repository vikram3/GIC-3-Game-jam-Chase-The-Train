extends Node3D

# car model (keeping original structure)
@onready var rig = $Rig
@onready var container = $Container
@onready var model = $Container/Model
@onready var sphere = $Sphere
@onready var raycast = $Container/Model/RayCast3D
@onready var body = $Container/Model/body
@onready var front_wheel_right = $Container/Model/wheelFrontRight
@onready var front_wheel_left = $Container/Model/wheelFrontLeft
@onready var rear_wheel_right = $Container/Model/wheelRearRight
@onready var rear_wheel_left = $Container/Model/wheelRearLeft
@onready var smoke_left = $Container/Model/SmokeLeft
@onready var smoke_right = $Container/Model/SmokeRight
@onready var left_skid_pos = $Container/Model/LeftSkidPos
@onready var right_skid_pos = $Container/Model/RightSkidPos
@onready var skidmarks = preload("res://Scenes/Car/skids.tscn")
@onready var engine_sound = $EngineSFX
@onready var skid_sound = $SkidSFX
@onready var bump_sound = $BumpSFX
@onready var front_lights = $Container/Model/body/FrontLights
@onready var rear_lights = $Container/Model/body/RearLights
@onready var cam = $Rig/Camera3D

# CPU or human
@export var is_AI = false

# car settings
@export var max_speed = 200
@export var brake_force = 0.15
@export var turn_strength = 120
@export var acceleration = 0.7
@export var body_height = 0.67
@export var body_pos = -0.074
@export var is_lights_on = true
@export var car_name = "car"
var speed_target : float = 0.0
var speed : float = 0.0
var torque_velocity : float = 0.0
var skid_threshold = 0.028
var was_accelerating = false

var normal = Vector3(0, 1, 0)
var raycast_normal = Vector3(0, 1, 0)
var body_position = Vector3(0, 0, 0)
var model_rotation = Vector3(0, 0, 0)

# Train chase specific variables
var train_node = null
var distance_to_train = 999999.0
var has_caught_train = false
var chase_mode = false

# waypoints system (modified for train chase)
var waypoints = []
var current_waypoint = 0
@export var target_variance = 1.0
var rng = RandomNumberGenerator.new()

# race values (simplified for single lap)
var race_position = 0
var player_position = 0
var current_lap = 1
var current_lap_time = 0.0
var best_lap_time = 0.0
var race_time = 0.0
var lap_times = []
var distance_to_next_waypoint = 0
var total_checked = 0
var checked = 0
var is_countdown_finished = false
var is_race_finished = false
var is_final_pos_set = false

func _ready():
	waypoints = get_tree().get_nodes_in_group("check")
	train_node = get_tree().get_first_node_in_group("train")
	
	# Load sounds
	engine_sound.stream = preload("res://Assets/SFX/Motor.wav")
	engine_sound.pitch_scale = 0.85
	skid_sound.stream = preload("res://Assets/SFX/Car Brakes.wav")
	skid_sound.pitch_scale = 0.7
	
	# Setup car
	if not is_lights_on:
		front_lights.visible = false
	else:
		front_lights.visible = true
		
	if not is_AI:
		cam.current = true
		car_name = "player"
	else:
		cam.current = false
		car_name = name

func _process(delta):
	if RaceManager.is_countdown_finished and !is_race_finished:
		current_lap_time += delta
		distance_to_next_waypoint = global_position.distance_to(waypoints[current_waypoint].global_position)
		
		# Calculate distance to train
		if train_node:
			distance_to_train = global_position.distance_to(train_node.global_position)
			
			# Check if caught the train
			if distance_to_train <= RaceManager.catch_distance and !has_caught_train:
				catch_train()
		
		update_pos()
	
	elif is_race_finished and !is_final_pos_set:
		current_lap_time = 0.0
		RaceManager.finished_cars += 1
		is_final_pos_set = true
		print(car_name, " finished at position ", race_position)

func _physics_process(delta):
	# Original physics code
	container.transform.origin = sphere.transform.origin - Vector3(0, 1, 0)
	model.rotation_degrees = model.rotation_degrees.lerp(model_rotation, delta * 5)

	if Input.is_action_just_pressed("lights"):
		is_lights_on = !is_lights_on

	if is_AI and RaceManager.is_countdown_finished and !is_race_finished:
		ai_train_chase_behavior(delta)
	else:
		# Human player controls (unchanged)
		if Input.is_action_pressed("left") and abs(speed) > 0 and raycast.is_colliding():
			model_rotation.y += turn_strength * delta
		elif Input.is_action_pressed("right") and abs(speed) > 0 and raycast.is_colliding():
			model_rotation.y -= turn_strength * delta
	
	# Apply movement
	speed_target = lerp(speed_target, speed, 4 * delta)
	var forward = model.get_global_transform().basis.z
	
	if !is_race_finished and RaceManager.is_countdown_finished:
		sphere.apply_force(forward * speed_target * 1.25, model.transform.origin)
	
	# Player input handling (unchanged from original)
	if not is_AI:
		handle_player_input(delta)
	
	# Visual effects (unchanged from original)
	handle_visual_effects(delta)
	
	# Ground raycast and alignment (unchanged from original)
	handle_ground_alignment(delta)

func ai_train_chase_behavior(delta):
	if !train_node:
		return
	
	# Determine target: train or next waypoint
	var target_pos
	var target_distance
	
	# If train is close, chase it directly
	if distance_to_train < 50.0:
		target_pos = train_node.global_position
		target_distance = distance_to_train
		chase_mode = true
	else:
		# Otherwise, follow waypoint path to catch up
		target_pos = waypoints[current_waypoint].global_position
		target_distance = global_position.distance_to(target_pos)
		chase_mode = false
	
	# Calculate direction to target
	var target_direction = (target_pos - model.global_transform.origin).normalized()
	var cross = model.global_transform.basis[2].cross(target_direction)
	
	# Steering
	if cross.y > 0.1:
		model_rotation.y += 200 * delta
	elif cross.y < -0.1:
		model_rotation.y -= 200 * delta
	
	# Speed control based on chase mode
	if chase_mode:
		# Full speed when chasing train
		speed = max_speed
	else:
		# Adaptive speed for navigation
		if target_distance > 15:
			speed = max_speed
		elif target_distance > 10:
			speed = max_speed * 0.9
		else:
			speed = max_speed * 0.75

func catch_train():
	has_caught_train = true
	is_race_finished = true
	print(car_name + " caught the train!")
	
	# Play victory sound or effect
	if !is_AI:
		# Player caught the train - special celebration
		RaceManager.is_player_race_finished = true

func handle_player_input(delta):
	# Original player input code with train chase modifications
	if not is_lights_on:
		front_lights.visible = false
		rear_lights.visible = false
	else:
		front_lights.visible = true
		rear_lights.visible = true
	
	if not engine_sound.playing:
		engine_sound.play()
		engine_sound.volume_db = -10
		
	if Input.is_action_pressed("forward"):
		if raycast.is_colliding():
			speed += max_speed * acceleration * delta * 0.85
			was_accelerating = true
		else:
			was_accelerating = false
		speed = min(speed, max_speed)
		
	elif Input.is_action_pressed("back") and raycast.is_colliding():
		if speed > 0:
			speed -= max_speed * brake_force * delta
		else:
			speed = 0
		$Container/Model/body/RearLights/Left/StopLightLeft.light_energy = 10
		$Container/Model/body/RearLights/Right/StopLightRight.light_energy = 10
		
	elif not raycast.is_colliding():
		speed = max(0, speed - max_speed * 0.4 * delta)
		
	elif Input.is_action_just_released("back"):
		$Container/Model/body/RearLights/Left/StopLightLeft.light_energy = 1
		$Container/Model/body/RearLights/Right/StopLightRight.light_energy = 1
	else:
		speed = max(0, speed - max_speed * 0.2 * delta)
	
	if not was_accelerating and not raycast.is_colliding():
		speed = max(speed, speed_target)
	
	# Engine sound
	if speed == 0:
		engine_sound.pitch_scale = 1
	else:
		engine_sound.pitch_scale = lerp(0.85, 1.5, speed / max_speed)

func handle_visual_effects(delta):
	# Original visual effects code (wheels, body tilt, etc.)
	var rotation_velocity = (model_rotation - model.rotation_degrees).y
	
	# Wheel turning and rotation
	front_wheel_left.rotation_degrees.y = rotation_velocity * 1.3
	front_wheel_right.rotation_degrees.y = rotation_velocity * 1.3
	front_wheel_left.rotation.x += 0.05 * speed * delta
	front_wheel_right.rotation.x += 0.05 * speed * delta
	rear_wheel_left.rotate_x(0.05 * speed * delta)
	rear_wheel_right.rotate_x(0.05 * speed * delta)
	
	# Body position and rotation
	body_position = Vector3(0, body_height, body_pos)
	if !raycast.is_colliding():
		body_position += Vector3(0, 0.1, 0)
	body.transform.origin = body.transform.origin.lerp(body_position, delta * 15)
	
	var torque = (speed / 20) - sphere.linear_velocity.length()
	torque_velocity = clamp(lerp(torque_velocity, torque, 2 * delta), -5, 5)
	body.rotation_degrees = Vector3((torque_velocity * 0.9), 0, 0)
	body.rotate_object_local(Vector3(0, 0, 1), rotation_velocity / 200)
	
	# Skidding effects
	var velocity = sphere.linear_velocity
	var forward = model.get_global_transform().basis.z
	var lateral_velocity = velocity - forward * velocity.dot(forward)
	var lateral_speed = lateral_velocity.length()
	var slip_angle = atan2(lateral_speed, speed_target)
	
	if (abs(slip_angle) > skid_threshold) and lateral_speed > 1.0 and raycast.is_colliding():
		add_tire_tracks()
		smoke_left.emitting = true
		smoke_right.emitting = true
		if not skid_sound.playing and not is_AI:
			skid_sound.play()
	else:
		skid_sound.stop()
		smoke_left.emitting = false
		smoke_right.emitting = false
	
	# Camera follow
	rig.transform.origin = rig.transform.origin.lerp(container.transform.origin, delta * 5)

func handle_ground_alignment(delta):
	# Original ground alignment code
	normal = normal.lerp(raycast_normal, delta * 8)
	container.global_transform = alignNormal(container.global_transform, normal)
	
	if raycast.is_colliding():
		raycast_normal = raycast.get_collision_normal()
	else:
		raycast_normal = raycast_normal.lerp(Vector3(0, 1, 0) + (model.get_transform().basis.z / 2), delta * 4)

func alignNormal(_container, _normal):
	_container.basis.y = _normal
	_container.basis.x = -_container.basis.z.cross(_normal)
	_container.basis = _container.basis.orthonormalized()
	return _container

func add_tire_tracks():
	# Original tire tracks code
	var left_skidmarks_instance = skidmarks.instantiate()
	var right_skidmarks_instance = skidmarks.instantiate()
	get_parent().add_child(left_skidmarks_instance)
	get_parent().add_child(right_skidmarks_instance)
	left_skidmarks_instance.global_transform.origin = left_skid_pos.global_transform.origin
	right_skidmarks_instance.global_transform.origin = right_skid_pos.global_transform.origin
	
	var r = get_rotation()
	left_skidmarks_instance.set_rotation(r)
	right_skidmarks_instance.set_rotation(r)

func _on_area_3d_area_entered(area):
	# Modified for single lap train chase
	if area.is_in_group("finish") and checked == waypoints.size():
		if !has_caught_train:
			# Player finished lap but didn't catch train
			is_race_finished = true
			if !is_AI:
				RaceManager.is_player_race_finished = true
		current_lap_time = 0
		checked = 0
		
	elif area.is_in_group("check"):
		if area.checkpoint_number == current_waypoint:
			checked += 1
			total_checked += 1
			set_next_target()
	
	# Train collision detection
	if area.is_in_group("train") and !has_caught_train:
		catch_train()
	
	if area.is_in_group("car_body") and !is_AI and !bump_sound.is_playing():
		bump_sound.play()

func set_next_target():
	if current_waypoint == waypoints.size() - 1:
		current_waypoint = 0
	else:
		current_waypoint += 1
	randomize_ai_target()

func randomize_ai_target():
	if is_AI:
		waypoints[current_waypoint].global_transform.origin += Vector3(
			rng.randf_range(-target_variance, target_variance), 
			0, 
			rng.randf_range(-target_variance, target_variance)
		)

func update_pos():
	# Update race position based on distance to train
	for i in range(RaceManager.cars_array.size()):
		if RaceManager.cars_array[i].car_name == "player":
			player_position = i + 1
			race_position = i + 1
		if RaceManager.cars_array[i].car_name == name:
			race_position = i + 1
