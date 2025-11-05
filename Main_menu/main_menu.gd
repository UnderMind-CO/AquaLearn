extends Control

func _on_btn_play_pressed() -> void:
	get_tree().change_scene_to_file("res://game/scenes/main_scene_game.tscn")


func _on_btn_opciones_pressed() -> void:
	var opciones = preload("res://Main_menu/options.tscn").instantiate()
	add_child(opciones)


func _on_btn_salir_pressed() -> void:
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
