extends Node3D

@onready var podium = $Podium
@onready var car_name = $Camera3D/CanvasLayer/Control/CarName
@onready var car_description = $Camera3D/CanvasLayer/Control/CarDescription
@onready var acceleration_bar = $Camera3D/CanvasLayer/Control/AccBar
@onready var top_speed_bar = $Camera3D/CanvasLayer/Control/TopSpeedBar
@onready var grip_bar = $Camera3D/CanvasLayer/Control/GripBar

var rotation_speed = 30

@onready var car1_model = $Podium/Cars/Bronco
var car1_name = "Canyonero"
var car1_description = "It's the country-fried truck"
var car1_grip = 55.0
var car1_top_speed = 25.0
var car1_acc = 90.0

@onready var car2_model = $Podium/Cars/Datssun
var car2_name = "Sunny"
var car2_description = "Bright, cheerful and youthful"
var car2_grip = 70.0
var car2_top_speed = 35.0
var car2_acc = 45.0

@onready var car3_model = $Podium/Cars/R12
var car3_name = "R12"
var car3_description = "A family four-wheeled time capsule"
var car3_grip = 25.0
var car3_top_speed = 50.0
var car3_acc = 40.0

@onready var car4_model = $Podium/Cars/Lyon
var car4_name = "Feline"
var car4_description = "The european lyon"
var car4_grip = 55.0
var car4_top_speed = 70.0
var car4_acc = 55.0

var car_number = 1

func _ready():
	car_name.text = car1_name
	car_description.text = car1_description
	top_speed_bar.value = car1_top_speed
	grip_bar.value = car1_grip
	acceleration_bar.value = car1_acc

func _process(delta):
	podium.rotate_y(deg_to_rad(rotation_speed * delta))
	# Rotate the object around the Y-axis with the input keys.
	# Activate this if you like
	if Input.is_action_pressed("ui_right"):
		#car_model.rotate_y(deg_to_rad(rotation_speed * delta))
		pass
	if Input.is_action_pressed("ui_left"):
		#car_model.rotate_y(deg_to_rad(-rotation_speed * delta))
		pass
		
	if car_number == 1:
		car_name.text = car1_name
		car_description.text = car1_description
		top_speed_bar.value = lerp(top_speed_bar.value, car1_top_speed, 10 * delta )
		acceleration_bar.value = lerp(acceleration_bar.value, car1_acc, 10 * delta)
		grip_bar.value = lerp(grip_bar.value, car1_grip, 10 * delta)
		
	if car_number == 2:
		car_name.text = car2_name
		car_description.text = car2_description
		top_speed_bar.value = lerp(top_speed_bar.value, car2_top_speed, 10 * delta )
		acceleration_bar.value = lerp(acceleration_bar.value, car2_acc, 10 * delta)
		grip_bar.value = lerp(grip_bar.value, car2_grip, 10 * delta)
		
	if car_number == 3:
		car_name.text = car3_name
		car_description.text = car3_description
		top_speed_bar.value = lerp(top_speed_bar.value, car3_top_speed, 10 * delta )
		acceleration_bar.value = lerp(acceleration_bar.value, car3_acc, 10 * delta)
		grip_bar.value = lerp(grip_bar.value, car3_grip, 10 * delta)
		
	if car_number == 4:
		car_name.text = car4_name
		car_description.text = car4_description
		top_speed_bar.value = lerp(top_speed_bar.value, car4_top_speed, 10 * delta )
		acceleration_bar.value = lerp(acceleration_bar.value, car4_acc, 10 * delta)
		grip_bar.value = lerp(grip_bar.value, car4_grip, 10 * delta)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "bronco_fade_out" and car_number == 2:
		$AnimationPlayer.play("datssun_fade_in")
	if anim_name == "bronco_fade_out" and car_number == 4:
		$AnimationPlayer.play("lyon_fade_in")
	if anim_name == "datssun_fade_out" and car_number == 3:
		$AnimationPlayer.play("r12_fade_in")
	if anim_name == "datssun_fade_out" and car_number == 1:
		$AnimationPlayer.play("bronco_fade_in")
	if anim_name == "r12_fade_out" and car_number == 4:
		$AnimationPlayer.play("lyon_fade_in")
	if anim_name == "r12_fade_out" and car_number == 2:
		$AnimationPlayer.play("datssun_fade_in")
	if anim_name == "lyon_fade_out" and car_number == 1:
		$AnimationPlayer.play("bronco_fade_in")
	if anim_name == "lyon_fade_out" and car_number == 3:
		$AnimationPlayer.play("r12_fade_in")

func _on_previous_btn_pressed():
	# Lock car selection to Bronco (car_number = 1)
	pass

func _on_next_btn_pressed():
	# Lock car selection to Bronco (car_number = 1)
	pass

func _on_select_btn_pressed():
	RaceManager.car_selected = car_number
	#print(RaceManager.car_selected)
	get_tree().change_scene_to_file("res://Scenes/Game/Track1.tscn")
