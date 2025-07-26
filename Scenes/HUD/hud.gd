extends CanvasLayer

var minutes
var seconds
var milliseconds
var time_string
var time_string_best
var cars

@onready var anim = $AnimationPlayer
@onready var player = get_tree().get_nodes_in_group("player") # find the player

func _ready():
	# Get all cars in the "car" group
	cars = get_tree().get_nodes_in_group("car")
	anim.play("countdown")
	
func _process(delta):

	if RaceManager.is_countdown_finished:
		player = get_tree().get_nodes_in_group("player")
		time_string = format_time(player[0].current_lap_time)
		time_string_best = format_time(player[0].best_lap_time)
		$Control/Position/Pos.text = str(player[0].player_position)
		$Control/Position/TotalPos.text = "/" + str(RaceManager.cars_array.size())
		$Control/Time/LapTime.text = time_string
		$Control/Time/BestTime.text = time_string_best
		$Control/Lap/LapNumber.text = str(player[0].current_lap)
		$Control/Lap/TotalLapNumber.text = "/" + str(RaceManager.total_laps)
	else:
		$Control/Position/Pos.text = "-"
		$Control/Position/TotalPos.text = "/" + str(RaceManager.cars_array.size())
		$Control/Time/LapTime.text = "00:00.000"
		$Control/Time/BestTime.text = "00:00.000"
		$Control/Lap/LapNumber.text = "-"
		$Control/Lap/TotalLapNumber.text = "/" + str(RaceManager.total_laps)
	
	if RaceManager.is_player_race_finished:
		$AnimationPlayer.play("finish")
		$Control/Finish/FinalPosition.text = "Finished " + str(player[0].player_position)
		RaceManager.is_player_race_finished = false
	
func format_time(time_value):
	# function to format the time in minutes:seconds.miliseconds
	minutes = time_value / 60
	seconds = fmod(time_value, 60)
	milliseconds = fmod(time_value, 1) * 100
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "countdown":
		RaceManager.is_countdown_finished = true
	if anim_name == "finish":
		RaceManager.show_podium = true
