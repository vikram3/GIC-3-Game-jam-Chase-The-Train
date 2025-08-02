extends Node3D

var stored_camera_direction = Basis.IDENTITY
var transition_timer = 0.0
var transition_duration = 2.0 

# Car model nodes
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

var camera_initialized = false
var initial_camera_pos = Vector3.ZERO
var initial_camera_basis = Basis.IDENTITY
var current_show_train_timer = 0.0
var game_started = false

# CPU or human
@export var is_AI = false

# Camera settings - simplified and optimized
@export var camera_distance = 8.0
@export var camera_height = 3.0
@export var camera_smoothing = 3.0
@export var train_focus_strength = 0.7  # How much to focus on train (0-1)

# Car settings
@export var max_speed = 500
@export var brake_force = 0.15
@export var turn_strength = 120
@export var acceleration = 0.7
@export var body_height = 0.67
@export var body_pos = -0.074
@export var is_lights_on = true
@export var car_name = "car"

# Ground detection settings
@export var fall_distance_threshold = 3.0  # How far below last safe position triggers restart
@export var restart_delay = 0.3  # Seconds to wait before restart
var starting_position = Vector3.ZERO
var starting_rotation = Vector3.ZERO
var last_safe_position = Vector3.ZERO
var last_safe_rotation = Vector3.ZERO
var last_safe_time = 0.0
var fall_timer = 0.0
var is_falling = false

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

# Waypoints system
@export var target_variance = 1.0
var waypoints = []
var current_waypoint = 0
var rng = RandomNumberGenerator.new()

# Race values
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

	engine_sound.stream = preload("res://Assets/SFX/Motor.wav")
	engine_sound.pitch_scale = 0.85
	skid_sound.stream = preload("res://Assets/SFX/Car Brakes.wav")
	skid_sound.pitch_scale = 0.7

	front_lights.visible = is_lights_on

	if not is_AI:
		cam.current = true
		car_name = "player"
		# Set mouse to visible mode - no capture needed
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		cam.current = false
		car_name = name

	# Store starting position and rotation as safe defaults
	starting_position = global_position
	starting_rotation = model.rotation_degrees
	last_safe_position = starting_position
	last_safe_rotation = starting_rotation
	last_safe_time = Time.get_ticks_msec() / 1000.0
	
	print(car_name + " starting position: " + str(starting_position))

	setup_train_catch_detection()
	
	# Initialize camera position for player
	if not is_AI:
		initialize_camera()

func initialize_camera():
	# Store the initial camera setup from the editor
	initial_camera_pos = rig.global_transform.origin
	initial_camera_basis = cam.global_transform.basis
	
	# If train exists, start with a cinematic view of the train
	if train_node:
		var train_pos = train_node.get_front_position()
		
		# Position camera for a wide, cinematic shot of the train
		var train_direction = train_node.get_current_direction()
		var camera_offset = Vector3(20.0, 10.0, 20.0)  # Wide angle, slightly above and to the side
		var train_camera_pos = train_pos + camera_offset
		
		rig.global_transform.origin = train_camera_pos
		
		# Look at the train with a slight offset for dynamic feel
		var look_target = train_pos + Vector3(0, 3.0, 0)
		var forward = (look_target - train_camera_pos).normalized()
		var right = forward.cross(Vector3.UP).normalized()
		var up = right.cross(forward).normalized()
		
		cam.global_transform.basis = Basis(right, up, -forward)
		current_show_train_timer = 0.0
		game_started = false  # Start with cinematic train view
	else:
		# No train, immediately position behind car
		game_started = true
		set_camera_behind_car_instantly()
	
	camera_initialized = true

func setup_train_catch_detection():
	var catch_area = Area3D.new()
	var catch_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = RaceManager.catch_distance
	catch_shape.shape = shape
	catch_area.add_child(catch_shape)
	model.add_child(catch_area)
	catch_area.add_to_group("car_body")
	catch_area.area_entered.connect(_on_catch_area_entered)

func _on_catch_area_entered(area):
	if area.is_in_group("train") and !has_caught_train:
		catch_train()

func catch_train():
	has_caught_train = true
	is_race_finished = true
	print(car_name + " caught the train!")
	RaceManager.train_caught = true
	RaceManager.winner_car = self
	RaceManager.end_race_train_caught(self)

	if !is_AI:
		RaceManager.is_player_race_finished = true
		print("PLAYER WINS! Train caught!")

func ai_train_chase_behavior(delta):
	if !train_node:
		return

	var train_front_pos = train_node.get_front_position()
	var train_direction = train_node.get_current_direction()
	var prediction_time = 2.0
	var predicted_train_pos = train_front_pos + (train_direction * train_node.get_speed() * prediction_time)

	var target_pos
	var target_distance

	if distance_to_train < 100.0:
		target_pos = predicted_train_pos
		target_distance = global_position.distance_to(target_pos)
		chase_mode = true
	else:
		target_pos = waypoints[current_waypoint].global_position
		target_distance = global_position.distance_to(target_pos)
		chase_mode = false

	var target_direction = (target_pos - model.global_transform.origin).normalized()
	var cross = model.global_transform.basis[2].cross(target_direction)
	var steer_multiplier = 1.5 if chase_mode else 1.0

	if cross.y > 0.05:
		model_rotation.y += 250 * steer_multiplier * delta
	elif cross.y < -0.05:
		model_rotation.y -= 250 * steer_multiplier * delta

	if chase_mode:
		speed = max_speed
		if distance_to_train < 20.0:
			speed = max_speed * 1.1
	else:
		if target_distance > 20:
			speed = max_speed
		elif target_distance > 15:
			speed = max_speed * 0.95
		else:
			speed = max_speed * 0.8

func update_safe_position():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if raycast.is_colliding() and \
	   abs(sphere.linear_velocity.y) < 5.0 and \
	   global_position.y > (starting_position.y - 2.0) and \
	   current_time - last_safe_time > 1.0:
		
		last_safe_position = global_position
		last_safe_rotation = model.rotation_degrees
		last_safe_time = current_time

func check_ground_and_restart(delta):
	update_safe_position()
	
	var current_pos = global_position
	var distance_from_safe = last_safe_position.y - current_pos.y
	
	# Check if car is below y=0 or has fallen too far from safe position
	if current_pos.y < 0.0 or distance_from_safe > fall_distance_threshold:
		if not is_falling:
			is_falling = true
			fall_timer = 0.0
			print(car_name + " FALLING DETECTED! Fallen below y=0 or " + str(distance_from_safe) + " units below safe position!")
		
		fall_timer += delta
		
		if fall_timer >= restart_delay:
			restart_car()
	else:
		is_falling = false
		fall_timer = 0.0
	
	# Emergency restart for extreme falls
	if distance_from_safe > 20.0:
		print(car_name + " EMERGENCY RESTART - fell too far!")
		restart_car()

func restart_car():
	print(car_name + " restarting!")
	print("Last safe position: " + str(last_safe_position))
	print("Current position: " + str(global_position))
	
	var restart_pos = last_safe_position
	var restart_rot = last_safe_rotation
	
	if restart_pos == Vector3.ZERO:
		restart_pos = starting_position
		restart_rot = starting_rotation
	
	global_position = restart_pos + Vector3(0, 1.0, 0)
	model.rotation_degrees = restart_rot
	model_rotation = restart_rot
	
	sphere.linear_velocity = Vector3.ZERO
	sphere.angular_velocity = Vector3.ZERO
	
	speed = 0.0
	speed_target = 0.0
	torque_velocity = 0.0
	
	is_falling = false
	fall_timer = 0.0
	
	skid_sound.stop()
	smoke_left.emitting = false
	smoke_right.emitting = false
	
	print(car_name + " restart complete at: " + str(global_position))

func set_camera_behind_car_instantly():
	var car_pos = model.global_transform.origin
	var car_forward = model.global_transform.basis.z
	
	var target_pos = car_pos - (car_forward * camera_distance) + (Vector3.UP * camera_height)
	rig.global_transform.origin = target_pos
	
	var look_target = car_pos + Vector3.UP
	var camera_forward = (look_target - target_pos).normalized()
	var camera_right = camera_forward.cross(Vector3.UP).normalized()
	var camera_up = camera_right.cross(camera_forward).normalized()
	
	cam.global_transform.basis = Basis(camera_right, camera_up, -camera_forward)
	stored_camera_direction = cam.global_transform.basis

func update_perfect_camera(delta):
	if not camera_initialized:
		return
		
	if not game_started:
		if train_node:
			current_show_train_timer += delta
			
			# Cinematic orbiting effect around the train
			var train_pos = train_node.get_front_position()
			var orbit_angle = current_show_train_timer * 0.2  # Slow orbit for cinematic effect
			var camera_offset = Vector3(
				20.0 * cos(orbit_angle),
				10.0,
				20.0 * sin(orbit_angle)
			)
			var train_camera_pos = train_pos + camera_offset
			
			rig.global_transform.origin = rig.global_transform.origin.lerp(train_camera_pos, delta * 2.0)
			
			var look_target = train_pos + Vector3(0, 3.0, 0)
			var forward = (look_target - rig.global_transform.origin).normalized()
			var right = forward.cross(Vector3.UP).normalized()
			var up = right.cross(forward).normalized()
			
			cam.global_transform.basis = cam.global_transform.basis.slerp(Basis(right, up, -forward), delta * 3.0)
			
			# Transition to player after 5 seconds or when countdown finishes
			if current_show_train_timer > 5.0 or RaceManager.is_countdown_finished:
				game_started = true
				transition_timer = 0.0  # Start transition
				print("Starting camera transition to player car")
		else:
			game_started = true
			set_camera_behind_car_instantly()
	else:
		# Handle transition to player car
		if transition_timer < transition_duration:
			transition_timer += delta
			var t = transition_timer / transition_duration
			t = smoothstep(0.0, 1.0, t)  # Smoothstep for natural easing
			
			var car_pos = model.global_transform.origin
			var car_forward = model.global_transform.basis.z
			var target_pos = car_pos - (car_forward * camera_distance) + (Vector3.UP * camera_height)
			
			# Interpolate position
			rig.global_transform.origin = rig.global_transform.origin.lerp(target_pos, t)
			
			# Interpolate rotation
			var look_target = car_pos + Vector3.UP
			var camera_forward = (look_target - rig.global_transform.origin).normalized()
			var camera_right = camera_forward.cross(Vector3.UP).normalized()
			var camera_up = camera_right.cross(camera_forward).normalized()
			var target_basis = Basis(camera_right, camera_up, -camera_forward)
			cam.global_transform.basis = cam.global_transform.basis.slerp(target_basis, t)
			
			if transition_timer >= transition_duration:
				print("Camera transition to player car complete")
		else:
			# Normal player camera tracking
			update_player_camera(delta)

func update_player_camera(delta):
	var car_pos = model.global_transform.origin
	var car_forward = model.global_transform.basis.z
	
	var target_pos = car_pos - (car_forward * camera_distance) + (Vector3.UP * camera_height)
	
	rig.global_transform.origin = rig.global_transform.origin.lerp(target_pos, delta * camera_smoothing)
	
	var look_target = car_pos + Vector3.UP
	var camera_forward = (look_target - rig.global_transform.origin).normalized()
	var camera_right = camera_forward.cross(Vector3.UP).normalized()
	var camera_up = camera_right.cross(camera_forward).normalized()
	
	var target_basis = Basis(camera_right, camera_up, -camera_forward)
	cam.global_transform.basis = cam.global_transform.basis.slerp(target_basis, delta * camera_smoothing)

func _process(delta):
	check_ground_and_restart(delta)
	
	if RaceManager.is_countdown_finished and !is_race_finished:
		current_lap_time += delta
		distance_to_next_waypoint = global_position.distance_to(waypoints[current_waypoint].global_position)

		if train_node:
			distance_to_train = global_position.distance_to(train_node.get_front_position())
			if (distance_to_train <= RaceManager.catch_distance or train_node.can_be_caught_by(global_position)) and !has_caught_train:
				catch_train()

		update_pos()
	elif is_race_finished and !is_final_pos_set:
		current_lap_time = 0.0
		RaceManager.finished_cars += 1
		is_final_pos_set = true
		print(car_name, " finished at position ", race_position)

	if not is_AI:
		update_perfect_camera(delta)

func _physics_process(delta):
	container.transform.origin = sphere.transform.origin - Vector3(0, 1, 0)
	model.rotation_degrees = model.rotation_degrees.lerp(model_rotation, delta * 5)

	if Input.is_action_just_pressed("lights"):
		is_lights_on = !is_lights_on

	if is_AI and RaceManager.is_countdown_finished and !is_race_finished:
		ai_train_chase_behavior(delta)
	else:
		if Input.is_action_pressed("left") and abs(speed) > 0 and raycast.is_colliding():
			model_rotation.y += turn_strength * delta
		elif Input.is_action_pressed("right") and abs(speed) > 0 and raycast.is_colliding():
			model_rotation.y -= turn_strength * delta

	speed_target = lerp(speed_target, speed, 4 * delta)
	var forward = model.get_global_transform().basis.z
	if !is_race_finished and RaceManager.is_countdown_finished:
		sphere.apply_force(forward * speed_target * 1.25, model.transform.origin)

	if not is_AI:
		handle_player_input(delta)

	handle_visual_effects(delta)
	handle_ground_alignment(delta)

func handle_player_input(delta):
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

	if speed == 0:
		engine_sound.pitch_scale = 1
	else:
		engine_sound.pitch_scale = lerp(0.85, 1.5, speed / max_speed)

func handle_visual_effects(delta):
	var rotation_velocity = (model_rotation - model.rotation_degrees).y
	front_wheel_left.rotation_degrees.y = rotation_velocity * 1.3
	front_wheel_right.rotation_degrees.y = rotation_velocity * 1.3
	front_wheel_left.rotation.x += 0.05 * speed * delta
	front_wheel_right.rotation.x += 0.05 * speed * delta
	rear_wheel_left.rotate_x(0.05 * speed * delta)
	rear_wheel_right.rotate_x(0.05 * speed * delta)

	body_position = Vector3(0, body_height, body_pos)
	if !raycast.is_colliding():
		body_position += Vector3(0, 0.1, 0)
	body.transform.origin = body.transform.origin.lerp(body_position, delta * 15)

	var torque = (speed / 20) - sphere.linear_velocity.length()
	torque_velocity = clamp(lerp(torque_velocity, torque, 2 * delta), -5, 5)
	body.rotation_degrees = Vector3((torque_velocity * 0.9), 0, 0)
	body.rotate_object_local(Vector3(0, 0, 1), rotation_velocity / 200)

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

func handle_ground_alignment(delta):
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
	if area.is_in_group("finish") and checked == waypoints.size():
		if !has_caught_train:
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
	for i in range(RaceManager.cars_array.size()):
		if RaceManager.cars_array[i].car_name == "player":
			player_position = i + 1
			race_position = i + 1
		if RaceManager.cars_array[i].car_name == name:
			race_position = i + 1

# Helper function for smoothstep easing
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
