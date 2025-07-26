extends CanvasLayer

var minutes
var seconds
var milliseconds
var race_time_string_1
var race_time_string_2
var race_time_string_3
var race_time_string_4

func _ready():
	race_time_string_1 = format_time(RaceManager.cars_array[0].race_time)
	race_time_string_2 = format_time(RaceManager.cars_array[1].race_time)
	race_time_string_3 = format_time(RaceManager.cars_array[2].race_time)
	race_time_string_4 = format_time(RaceManager.cars_array[3].race_time)
		
	$Control/RaceStats/Stats/Car1.text = RaceManager.cars_array[0].car_name
	$Control/RaceStats/Stats/Car2.text = RaceManager.cars_array[1].car_name
	$Control/RaceStats/Stats/Car3.text = RaceManager.cars_array[2].car_name
	$Control/RaceStats/Stats/Car4.text = RaceManager.cars_array[3].car_name
	
	$Control/RaceStats/Stats/RaceTime1.text = race_time_string_1
	$Control/RaceStats/Stats/RaceTime2.text = race_time_string_2
	$Control/RaceStats/Stats/RaceTime3.text = race_time_string_3
	$Control/RaceStats/Stats/RaceTime4.text = race_time_string_4

	print(RaceManager.cars_array)
	
func _process(delta):
	pass

func format_time(time_value):
	# function to format the time in minutes:seconds.miliseconds
	minutes = time_value / 60
	seconds = fmod(time_value, 60)
	milliseconds = fmod(time_value, 1) * 100
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]
