extends CanvasLayer

var minutes
var seconds
var milliseconds
var time_string
var time_string_best
var cars
var player
var train_node

@onready var anim = $AnimationPlayer

func _ready():
	cars = get_tree().get_nodes_in_group("car")
	train_node = get_tree().get_first_node_in_group("train")
	anim.play("countdown")
	
func _process(delta):
	if RaceManager.is_countdown_finished:
		player = get_tree().get_nodes_in_group("player")
		if player.size() > 0:
			update_race_info()
			update_train_chase_status()
	else:
		display_waiting_state()
	
	# Check for race end conditions
	if RaceManager.train_caught or (train_node and train_node.get_progress() >= 1.0):
		show_race_end()

func update_race_info():
	time_string = format_time(player[0].current_lap_time)
	time_string_best = format_time(player[0].best_lap_time)
	
	# Position relative to other cars
	$Control/Position/Pos.text = str(player[0].race_position)
	$Control/Position/TotalPos.text = "/" + str(RaceManager.cars_array.size())
	
	# Time displays
	$Control/Time/LapTime.text = time_string
	$Control/Time/BestTime.text = time_string_best
	
	# Show single lap (always 1/1)
	$Control/Lap/LapNumber.text = "1"
	$Control/Lap/TotalLapNumber.text = "/1"

func update_train_chase_status():
	# Distance to train
	var distance_to_train = 0.0
	if train_node and player.size() > 0:
		distance_to_train = player[0].global_position.distance_to(train_node.global_position)
	
	# Update train chase specific UI elements
	$Control/TrainChase/DistanceToTrain.text = "Distance: " + str(int(distance_to_train)) + "m"
	
	# Train progress bar
	if train_node:
		var train_progress = train_node.get_progress()
		$Control/TrainChase/TrainProgress.value = train_progress * 100
		$Control/TrainChase/TrainProgressLabel.text = "Train Progress: " + str(int(train_progress * 100)) + "%"
	
	# Race status
	$Control/TrainChase/RaceStatus.text = RaceManager.get_race_status()
	
	# Change UI colors based on distance
	if distance_to_train < 10.0:
		$Control/TrainChase/DistanceToTrain.modulate = Color.GREEN  # Very close
	elif distance_to_train < 25.0:
		$Control/TrainChase/DistanceToTrain.modulate = Color.YELLOW  # Getting close
	else:
		$Control/TrainChase/DistanceToTrain.modulate = Color.RED  # Far away

func display_waiting_state():
	$Control/Position/Pos.text = "-"
	$Control/Position/TotalPos.text = "/" + str(RaceManager.cars_array.size())
	$Control/Time/LapTime.text = "00:00.000"
	$Control/Time/BestTime.text = "00:00.000"
	$Control/Lap/LapNumber.text = "-"
	$Control/Lap/TotalLapNumber.text = "/1"
	$Control/TrainChase/DistanceToTrain.text = "Distance: ---m"
	$Control/TrainChase/TrainProgress.value = 0
	$Control/TrainChase/TrainProgressLabel.text = "Train Progress: 0%"
	$Control/TrainChase/RaceStatus.text = "GET READY..."

func show_race_end():
	if RaceManager.train_caught:
		if player.size() > 0 and player[0].has_caught_train:
			$AnimationPlayer.play("victory")  # Player won
			$Control/Finish/FinalResult.text = "YOU CAUGHT THE TRAIN!"
			$Control/Finish/FinalPosition.text = "WINNER!"
		else:
			$AnimationPlayer.play("finish")  # Someone else caught it
			$Control/Finish/FinalResult.text = "TRAIN WAS CAUGHT"
			$Control/Finish/FinalPosition.text = "Position: " + str(player[0].race_position)
	else:
		$AnimationPlayer.play("defeat")  # Train escaped
		$Control/Finish/FinalResult.text = "TRAIN ESCAPED!"
		$Control/Finish/FinalPosition.text = "Final Position: " + str(player[0].race_position)
	
	RaceManager.is_player_race_finished = false

func format_time(time_value):
	minutes = time_value / 60
	seconds = fmod(time_value, 60)
	milliseconds = fmod(time_value, 1) * 100
	return "%02d:%02d.%03d" % [minutes, seconds, milliseconds]

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "countdown":
		RaceManager.is_countdown_finished = true
	elif anim_name in ["victory", "finish", "defeat"]:
		RaceManager.show_podium = true
