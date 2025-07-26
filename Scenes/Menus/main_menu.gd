extends Node3D

func _on_start_btn_pressed():
	get_tree().change_scene_to_file("res://Scenes/Menus/car_selection_screen.tscn")
