extends Node3D

@onready var car1 = preload("res://Scenes/Car/bronco.tscn")
@onready var car2 = preload("res://Scenes/Car/datssun.tscn")
@onready var car3 = preload("res://Scenes/Car/r12.tscn")
@onready var car4 = preload("res://Scenes/Car/lyon.tscn")
@onready var podium = preload("res://Scenes/HUD/podium.tscn")
var podium_instance
var show_podium = false

var car1_instance
var car2_instance
var car3_instance
var car4_instance

func _ready():
	instantiate_cars()
	
	#Canyonero
	if RaceManager.car_selected == 1:
		car1_instance.is_AI = false
		car1_instance.add_to_group("player")
		car1_instance.cam.current = true
		car1_instance.car_name = "player"
	#Sunny
	elif RaceManager.car_selected == 2:
		car2_instance.is_AI = false
		car2_instance.cam.current = true
		car2_instance.add_to_group("player")
		car2_instance.car_name = "player"
	#R12
	elif RaceManager.car_selected == 3:
		car3_instance.is_AI = false
		car3_instance.cam.current = true
		car3_instance.add_to_group("player")
		car3_instance.car_name = "player"
	#Feline
	elif RaceManager.car_selected == 4:
		car4_instance.is_AI = false
		car4_instance.cam.current = true
		car4_instance.add_to_group("player")
		car4_instance.car_name = "player"
		
	# Get all cars in the "car" group
	RaceManager.cars = get_tree().get_nodes_in_group("car")
	
	# Loop through each car and add its data to the array
	for car in RaceManager.cars:
		var car_data = {
			"car_name": car.car_name, 
			"waypoint_checked": car.total_checked, 
			"distance_to_next_waypoint": car.distance_to_next_waypoint,
			"lap_number": car.current_lap,
			"best_lap": car.best_lap_time,
			"race_time": car.race_time,
			"race_position": car.race_position
		}
		RaceManager.cars_array.append(car_data)
	

func _process(delta):
	# show podium screen
	if RaceManager.finished_cars == RaceManager.cars_array.size() and RaceManager.show_podium:
		podium_instance = podium.instantiate()
		add_child(podium_instance)
		RaceManager.show_podium = false

func instantiate_cars():
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
