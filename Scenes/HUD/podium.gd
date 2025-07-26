extends CanvasLayer

var minutes
var seconds
var milliseconds
var race_time_string_1
var race_time_string_2
var race_time_string_3
var race_time_string_4

func _ready():
	display_train_chase_results()

func display_train_chase_results():
	# Title based on outcome
	if RaceManager.train_caught:
		$Control/Title.text = "TRAIN CAUGHT!"
		$Control/Subtitle.text = "Winner: " + RaceManager.winner_car.car_name
	else:
		$Control/Title.text = "TRAIN ESCAPED!"
		$Control/Subtitle.text = "Nobody caught the train this time..."
	
	# Format race times
	race_time_string_1 = format_time(RaceManager.cars_array[0].race_time)
	race_time_string_2 = format_time(RaceManager.cars_array[1].race_time)
	race_time_string_3 = format_time(RaceManager.cars_array[2].race_time)
	race_time_string_4 = format_time(RaceManager.cars_array[3].race_time)
	
	# Display results with special indicators
	$Control/RaceStats/Stats/Car1.text = get_car_display_name(0)
	$Control/RaceStats/Stats/Car2.text = get_car_display_name(1)
	$Control/RaceStats/Stats/Car3.text = get_car_display_name(2)
	$Control/RaceStats/Stats/Car4.text = get_car_display_name(3)
	
	$Control/RaceStats/Stats/RaceTime1.text = get_result_text(0)
	$Control/RaceStats/Stats/RaceTime2.text = get_result_text(1)
	$Control/RaceStats/Stats/RaceTime3.text = get_result_text(2)
	$Control/RaceStats/Stats/RaceTime4.text = get_result_text(3)
	
	# Color code the results
	apply_result_colors()
	
	# Train statistics
	display_train_stats()

func get_car_display_name(index):
	var car_data = RaceManager.cars_array[index]
	var display_name = car_data.car_name
	
	if car_data.caught_train:
		display_name += " 🏆"  # Trophy for winner
	
	return display_name

func get_result_text(index):
	var car_data = RaceManager.cars_array[index]
	
	if car_data.caught_train:
		return "CAUGHT TRAIN! (" + format_time(car_data.race_time) + ")"
	else:
		var final_distance = car_data.distance_to_train
		return format_time(car_data.race_time) + " (+" + str(int(final_distance)) + "m)"

func apply_result_colors():
	# Winner gets gold color
	if RaceManager.cars_array[0].caught_train:
		$Control/RaceStats/Stats/Car1.modulate = Color.GOLD
		$Control/RaceStats/Stats/RaceTime1.modulate = Color.GOLD
	
	# Others get standard colors based on position
	$Control/RaceStats/Stats/Car1.modulate = Color.WHITE
	$Control/RaceStats/Stats/Car2.modulate = Color.LIGHT_GRAY
	$Control/RaceStats/Stats/Car3.modulate = Color.GRAY
	$Control/RaceStats/Stats/Car4.modulate = Color.DIM_GRAY

func display_train_stats():
	var train_time = format_time(RaceManager.race_end_time)
	var train_status = "ESCAPED" if !RaceManager.train_caught else "CAUGHT"
	
	$Control/TrainStats/TrainResult.text = "Train Status: " + train_status
	$Control/TrainStats/TrainTime.text = "Train Time: " + train_time
	
	if RaceManager.train_caught:
		var catch_time = format_time(RaceManager.race_end_time)
		$Control/TrainStats/CatchTime.text = "Caught at: " + catch_time
	else:
		$Control/TrainStats/CatchTime.text = "Train completed full lap"

func format_time(time_value):
	minutes = time_value / 60
	seconds = fmod(time_value, 60)
	milliseconds = fmod(time_value, 1) * 100
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]

func _on_restart_button_pressed():
	# Reset race manager
	RaceManager.finished_cars = 0
	RaceManager.is_countdown_finished = false
	RaceManager.train_caught = false
	RaceManager.winner_car = null
	RaceManager.show_podium = false
	
	# Restart the race
	get_tree().change_scene_to_file("res://Scenes/Game/Track1.tscn")

func _on_menu_button_pressed():
	# Reset race manager
	RaceManager.finished_cars = 0
	RaceManager.is_countdown_finished = false
	RaceManager.train_caught = false
	RaceManager.winner_car = null
	RaceManager.show_podium = false
	
	# Go back to main menu
	get_tree().change_scene_to_file("res://Scenes/Menus/main_menu.tscn")
