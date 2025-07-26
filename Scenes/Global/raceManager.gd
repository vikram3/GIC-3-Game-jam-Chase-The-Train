extends Node

@export var total_laps = 2

@onready var cars = []  # Use an array to store the car info
@onready var cars_array = [] # This is the array to be sorted

var finished_cars = 0
var is_game_ready = false
var is_countdown_finished = false
var car_selected = null # car picked in the car selection screen
var is_player_race_finished = false
var show_podium = false

func _ready():
	pass

func _process(delta):
	# Loop through each car and update its data in the array
	if finished_cars < cars_array.size():
		for i in range(cars_array.size()):
			var car = cars[i]
			var car_data = {
				"car_name": car.car_name,
				"waypoint_checked": car.total_checked,
				"distance_to_next_waypoint": car.distance_to_next_waypoint,
				"lap_number": car.current_lap,
				"best_lap": car.best_lap_time,
				"race_time": car.race_time,
				"race_position": car.race_position
				}
			cars_array[i] = car_data
		
		# sort the cars to get the race positions
		bubble_sort(cars_array)
	
	else:
		# sort the cars to get the final race positions
		final_bubble_sort(cars_array)
	
	# for debugging, print the race positions
	#print_pos()

func bubble_sort(arr):
	# Algorithm to sort elements of an array
	var n = arr.size()
	for i in range(n - 1):
		for j in range(n - i - 1):
			if compare_items(arr[j], arr[j + 1]) > 0:
				# Swap the elements
				var temp = arr[j]
				arr[j] = arr[j + 1]
				arr[j + 1] = temp
				
func compare_items(a, b):
	# 1- Sort the cars by the lap number. The car with more laps checkes go first.
	# 2- Sort the cars by the waypoints checked. The car with more waypoints 
	# 	 checked go first
	# 3- If cars have the same number of waypoints checked, then sort them
	#    by the distance to the next waypoint
	
	if a["lap_number"] > b["lap_number"]:
		return -1
	elif a["lap_number"] < b["lap_number"]:
		return 1
	else:
		if a["waypoint_checked"] > b["waypoint_checked"]:
			return -1
		elif a["waypoint_checked"] < b["waypoint_checked"]:
			return 1
		else:
			if a["distance_to_next_waypoint"] < b["distance_to_next_waypoint"]:
				return -1
			elif a["distance_to_next_waypoint"] > b["distance_to_next_waypoint"]:
				return 1
			else:
				return 0

func print_pos():
	print("positions")
	for item in cars_array:
		print(item)

func on_game_ready():
	# Get all cars in the "car" group
	cars = get_tree().get_nodes_in_group("car")
	
	# Initialize an empty array to store the car data
	cars_array = []
	
#	# Loop through each car and add its data to the array
	for car in cars:
		var car_data = {
			"car_name": car.car_name, 
			"waypoint_checked": car.total_checked, 
			"distance_to_next_waypoint": car.distance_to_next_waypoint,
			"lap_number": car.current_lap,
			"best_lap": car.best_lap_time,
			"race_time": car.race_time,
			"race_position": car.race_position
		}
		cars_array.append(car_data)
	
	# Sort the array using the Bubble Sort algorithm
	bubble_sort(cars_array)

func final_bubble_sort(arr):
	# Algorithm to sort elements of an array
	var n = arr.size()
	for i in range(n - 1):
		for j in range(n - i - 1):
			if final_sorting(arr[j], arr[j + 1]) > 0:
				# Swap the elements
				var temp = arr[j]
				arr[j] = arr[j + 1]
				arr[j + 1] = temp

func final_sorting(a, b):
	# Sort the cars by total race time to get a more accurate race positions
	if a["race_time"] < b["race_time"]:
		return -1
	elif a["race_time"] > b["race_time"]:
		return 1
	else:
		return 0
