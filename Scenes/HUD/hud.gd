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
		# Get player reference
		var player_nodes = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0]
			update_race_info()
			update_train_chase_status()
	else:
		display_waiting_state()
	
	# Check for race end conditions
	if RaceManager.train_caught or (train_node and train_node.get_progress() >= 1.0):
		show_race_end()

func update_race_info():
	if not player:
		return
		
	time_string = format_time(player.current_lap_time)
	time_string_best = format_time(player.best_lap_time)
	
	# Position relative to other cars
	$Control/Position/Pos.text = str(player.race_position)
	$Control/Position/TotalPos.text = "/" + str(RaceManager.cars.size())
	
	# Time displays
	$Control/Time/LapTime.text = time_string
	$Control/Time/BestTime.text = time_string_best
	
	# Show single lap (always 1/1)
	$Control/Lap/LapNumber.text = "1"
	$Control/Lap/TotalLapNumber.text = "/1"

func update_train_chase_status():
	if not player or not train_node:
		return
		
	# Distance to train
	var distance_to_train = player.distance_to_train
	
	# Update train chase specific UI elements
	$Control/TrainChase/DistanceToTrain.text = "Distance: " + str(int(distance_to_train)) + "m"
	
	# Train progress bar
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
	
	# Speed indicator based on distance
	if distance_to_train < 15.0:
		$Control/TrainChase/SpeedStatus.text = "CATCHING UP!"
		$Control/TrainChase/SpeedStatus.modulate = Color.GREEN
	elif distance_to_train < 50.0:
		$Control/TrainChase/SpeedStatus.text = "IN PURSUIT"
		$Control/TrainChase/SpeedStatus.modulate = Color.YELLOW
	else:
		$Control/TrainChase/SpeedStatus.text = "TOO FAR"
		$Control/TrainChase/SpeedStatus.modulate = Color.RED

func display_waiting_state():
	$Control/Position/Pos.text = "-"
	$Control/Position/TotalPos.text = "/" + str(RaceManager.cars.size()) if RaceManager.cars.size() > 0 else "/4"
	$Control/Time/LapTime.text = "00:00.000"
	$Control/Time/BestTime.text = "00:00.000"
	$Control/Lap/LapNumber.text = "-"
	$Control/Lap/TotalLapNumber.text = "/1"
	$Control/TrainChase/DistanceToTrain.text = "Distance: ---m"
	$Control/TrainChase/TrainProgress.value = 0
	$Control/TrainChase/TrainProgressLabel.text = "Train Progress: 0%"
	$Control/TrainChase/RaceStatus.text = "GET READY..."
	$Control/TrainChase/SpeedStatus.text = "WAITING..."
	$Control/TrainChase/SpeedStatus.modulate = Color.WHITE

func show_race_end():
	if not player:
		return
		
	if RaceManager.train_caught:
		if player.has_caught_train:
			$AnimationPlayer.play("victory")  # Player won
			$Control/Finish/FinalResult.text = "YOU CAUGHT THE TRAIN!"
			$Control/Finish/FinalPosition.text = "WINNER!"
		else:
			$AnimationPlayer.play("finish")  # Someone else caught it
			$Control/Finish/FinalResult.text = "TRAIN WAS CAUGHT"
			$Control/Finish/FinalPosition.text = "Position: " + str(player.race_position)
	else:
		$AnimationPlayer.play("defeat")  # Train escaped
		$Control/Finish/FinalResult.text = "TRAIN ESCAPED!"
		$Control/Finish/FinalPosition.text = "Final Position: " + str(player.race_position)
	
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
