extends Control

# --- CONFIGURACIONES ---
const GITHUB_URL := "https://github.com/UnderMind-CO/AquaLearn"

# --- FUNCIONES ---
func _on_credits_pressed() -> void:
	$Window.show()  # Muestra la ventana de créditos
	
func _on_cerrar_pressed() -> void:
	$Window.hide()  # Oculta la ventana de créditos
	queue_free()
	
	
func _on_source_code_pressed() -> void:
	OS.shell_open(GITHUB_URL)
	
func _on_window_close_requested() -> void:
	$Window.hide()  # Oculta la ventana cuando se presiona X
	
