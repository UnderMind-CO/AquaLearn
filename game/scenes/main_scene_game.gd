extends Node2D

# ========== VARIABLES DEL SISTEMA DE AGUA ==========
var agua_en_tanque = 80.0  # Litros actuales
var capacidad_maxima = 100.0  # Litros máximos
var agua_total_desperdiciada = 0.0
var agua_total_usada_correctamente = 0.0

# ========== SISTEMA DE PUNTOS Y NIVEL ==========
var puntos = 0
var nivel_actual = 1
var errores_cometidos = 0

# ========== SISTEMA DE MISIONES ==========
var mision_actual = {}
var misiones_completadas = 0

# ========== VÁLVULAS Y SUS PROPÓSITOS ==========
# IMPORTANTE: Los nombres en las claves deben coincidir con los nombres de los nodos Area2D
var valvulas = {
	"ValvulaCisterna": {
		"abierta": false,
		"flujo": 5.0,  # Litros por segundo
		"proposito": "almacenamiento",
		"necesita_agua": 0.0,
		"sprite_node": null
	},
	"ValvulaLavado": {
		"abierta": false,
		"flujo": 10.0,
		"proposito": "limpieza",
		"necesita_agua": 0.0,
		"sprite_node": null
	},
	"ValvulaDesague": {
		"abierta": false,
		"flujo": 15.0,
		"proposito": "desague",
		"necesita_agua": 0.0,
		"sprite_node": null
	}
}

# ========== SISTEMA DE CLIMA/RECARGA ==========
var tiempo_hasta_lluvia = 10.0
var esta_lloviendo = false

# ========== REFERENCIAS A NODOS UI ==========
@onready var guia = $CanvasLayer2/Guia
@onready var label_agua = $CanvasLayer2/Guia/CanvasLayer/HUD/LabelAgua
@onready var label_puntos = $CanvasLayer2/Guia/CanvasLayer/HUD/LabelPuntos
@onready var label_mision = $CanvasLayer2/Guia/CanvasLayer/HUD/LabelMision
@onready var tanque_sprite = $TanqueAgua

# ========== LISTA DE MISIONES POSIBLES ==========
var lista_misiones = [
	{
		"descripcion": "Riega las plantas con exactamente 25 litros",
		"valvula": "ValvulaPlantas",  # Debe coincidir con el nombre del nodo
		"cantidad_exacta": 25.0,
		"margen_error": 3.0,
		"puntos_recompensa": 50,
		"consejo_inicial": "Las plantas necesitan agua, pero no demasiada. ¡Cuidado con no desperdiciar!",
		"consejo_error": "¡Has usado demasiada agua! Las plantas se pueden ahogar con exceso de riego."
	},
	{
		"descripcion": "Llena la cisterna con 40 litros para emergencias",
		"valvula": "ValvulaCisterna",
		"cantidad_exacta": 40.0,
		"margen_error": 5.0,
		"puntos_recompensa": 60,
		"consejo_inicial": "Almacenar agua es inteligente, pero llena solo lo necesario.",
		"consejo_error": "La cisterna se desbordó. Siempre calcula cuánta agua necesitas."
	},
	{
		"descripcion": "Usa 30 litros para lavar el patio",
		"valvula": "ValvulaLavado",
		"cantidad_exacta": 30.0,
		"margen_error": 4.0,
		"puntos_recompensa": 55,
		"consejo_inicial": "Para limpiar eficientemente, usa solo el agua necesaria.",
		"consejo_error": "¡Demasiada agua! Podrías haber usado menos para limpiar igual de bien."
	}
]

func _ready():
	print("🌊 Juego de Conservación del Agua - Versión Mejorada")
	conectar_valvulas()
	iniciar_nueva_mision()
	actualizar_interfaz()
	mostrar_mensaje_guia("¡Bienvenido! Soy tu guía del agua. Te enseñaré a usar este recurso de manera responsable. ¡Presta atención a las misiones!", 4.0)

func conectar_valvulas():
	# Conectar señales de cada válvula disponible en la escena
	for valvula_nombre in valvulas.keys():
		var valvula_node = get_node_or_null(valvula_nombre)  # Busca por el nombre exacto
		if valvula_node:
			valvulas[valvula_nombre]["sprite_node"] = valvula_node
			if valvula_node.has_signal("input_event"):
				valvula_node.input_event.connect(_on_valvula_clicked.bind(valvula_nombre))
		else:
			print("⚠️ No se encontró el nodo: " + valvula_nombre)

func _process(delta):
	# ========== ACTUALIZAR FLUJO DE AGUA ==========
	for valvula_nombre in valvulas.keys():
		var valvula = valvulas[valvula_nombre]
		if valvula["abierta"]:
			var agua_usada = valvula["flujo"] * delta
			
			# Verificar si hay suficiente agua en el tanque
			if agua_en_tanque >= agua_usada:
				agua_en_tanque -= agua_usada
				valvula["necesita_agua"] += agua_usada
				
				# Verificar si es la válvula de la misión actual
				if mision_actual.has("valvula") and mision_actual["valvula"] == valvula_nombre:
					# Está usando la válvula correcta
					agua_total_usada_correctamente += agua_usada
				else:
					# Está desperdiciando agua en válvula incorrecta
					agua_total_desperdiciada += agua_usada
					if int(agua_total_desperdiciada) % 10 == 0 and agua_total_desperdiciada > 0:
						errores_cometidos += 1
						mostrar_mensaje_guia("⚠️ ¡Cuidado! Estás usando la válvula incorrecta. Lee bien la misión.", 2.0)
			else:
				# No hay suficiente agua
				agua_en_tanque = 0
				cerrar_valvula(valvula_nombre)
				mostrar_mensaje_guia("❌ ¡El tanque está vacío! Espera a que llueva o cierra las válvulas innecesarias.", 3.0)
	
	# ========== SISTEMA DE LLUVIA ==========
	if not esta_lloviendo:
		tiempo_hasta_lluvia -= delta
		if tiempo_hasta_lluvia <= 0:
			iniciar_lluvia()
	else:
		# Llenar el tanque con la lluvia
		agua_en_tanque += 10.0 * delta
		agua_en_tanque = min(agua_en_tanque, capacidad_maxima)
		if agua_en_tanque >= capacidad_maxima * 0.9:
			detener_lluvia()
	
	# ========== VERIFICAR MISIÓN ==========
	verificar_progreso_mision()
	
	# ========== ACTUALIZAR INTERFAZ ==========
	actualizar_interfaz()

func _on_valvula_clicked(viewport, event, shape_idx, valvula_nombre):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_valvula(valvula_nombre)

func toggle_valvula(valvula_nombre):
	var valvula = valvulas[valvula_nombre]
	valvula["abierta"] = !valvula["abierta"]
	
	# Actualizar visual de la válvula
	actualizar_sprite_valvula(valvula_nombre)
	
	if valvula["abierta"]:
		print("🔓 " + valvula_nombre + " abierta")
		
		# Verificar si es la válvula correcta para la misión
		if mision_actual.has("valvula") and mision_actual["valvula"] == valvula_nombre:
			mostrar_mensaje_guia("✅ ¡Bien! Has abierto la válvula correcta. Ahora controla cuánta agua usas.", 2.5)
		else:
			mostrar_mensaje_guia("⚠️ Esa no es la válvula de la misión actual. ¡Revisa tu objetivo!", 2.5)
			errores_cometidos += 1
	else:
		print("🔒 " + valvula_nombre + " cerrada")

func actualizar_sprite_valvula(valvula_nombre):
	var valvula = valvulas[valvula_nombre]
	if valvula["sprite_node"]:
		var sprite = valvula["sprite_node"].get_node_or_null("Sprite2D")
		if sprite:
			if valvula["abierta"]:
				sprite.modulate = Color(0.3, 0.8, 1.0)  # Azul cuando está abierta (fluye agua)
				sprite.rotation_degrees = 90  # Rotar para indicar que está abierta
			else:
				sprite.modulate = Color(1, 1, 1)  # Normal cuando está cerrada
				sprite.rotation_degrees = 0

func iniciar_nueva_mision():
	if lista_misiones.size() == 0:
		game_won()
		return
	
	# Resetear contadores de válvulas
	for valvula in valvulas.values():
		valvula["necesita_agua"] = 0.0
		valvula["abierta"] = false
	
	# Seleccionar misión aleatoria
	var mision_index = randi() % lista_misiones.size()
	mision_actual = lista_misiones[mision_index].duplicate()
	mision_actual["agua_usada"] = 0.0
	mision_actual["completada"] = false
	
	mostrar_mensaje_guia("📋 Nueva Misión: " + mision_actual["descripcion"] + "\n\n💡 " + mision_actual["consejo_inicial"], 5.0)

func verificar_progreso_mision():
	if mision_actual.has("valvula") and not mision_actual["completada"]:
		var valvula_mision = valvulas[mision_actual["valvula"]]
		var agua_usada = valvula_mision["necesita_agua"]
		var objetivo = mision_actual["cantidad_exacta"]
		var margen = mision_actual["margen_error"]
		
		# Verificar si se completó correctamente
		if agua_usada >= objetivo - margen and agua_usada <= objetivo + margen:
			if not valvula_mision["abierta"]:  # Solo si cerraron la válvula a tiempo
				mision_completada(true)
		
		# Verificar si se pasó demasiado
		elif agua_usada > objetivo + margen:
			if not valvula_mision["abierta"]:
				mision_completada(false)
			elif agua_usada > objetivo + margen + 10:
				# Fallo crítico: desperdició mucha agua
				cerrar_valvula(mision_actual["valvula"])
				mision_completada(false)

func mision_completada(exitosa):
	mision_actual["completada"] = true
	misiones_completadas += 1
	
	if exitosa:
		puntos += mision_actual["puntos_recompensa"]
		mostrar_mensaje_guia("🎉 ¡EXCELENTE! Completaste la misión perfectamente. +" + str(mision_actual["puntos_recompensa"]) + " puntos. El agua es un recurso valioso y lo usaste sabiamente.", 4.0)
	else:
		puntos += int(mision_actual["puntos_recompensa"] / 4)
		agua_total_desperdiciada += valvulas[mision_actual["valvula"]]["necesita_agua"] - mision_actual["cantidad_exacta"]
		errores_cometidos += 1
		mostrar_mensaje_guia("😞 " + mision_actual["consejo_error"] + " La misión se completó pero desperdiciaste agua. +" + str(int(mision_actual["puntos_recompensa"] / 4)) + " puntos", 4.0)
	
	# Esperar antes de dar nueva misión
	await get_tree().create_timer(5.0).timeout
	iniciar_nueva_mision()

func cerrar_valvula(valvula_nombre):
	valvulas[valvula_nombre]["abierta"] = false
	actualizar_sprite_valvula(valvula_nombre)

func iniciar_lluvia():
	esta_lloviendo = true
	mostrar_mensaje_guia("🌧️ ¡Está lloviendo! El tanque se está llenando. Aprovecha el agua de lluvia.", 2.5)

func detener_lluvia():
	esta_lloviendo = false
	tiempo_hasta_lluvia = randf_range(15.0, 30.0)
	mostrar_mensaje_guia("☀️ La lluvia paró. Usa el agua con sabiduría hasta la próxima.", 2.0)

func actualizar_interfaz():
	if label_agua:
		var porcentaje = (agua_en_tanque / capacidad_maxima) * 100
		label_agua.text = "💧 Agua: " + str(int(agua_en_tanque)) + "L (" + str(int(porcentaje)) + "%)"
		
		# Cambiar color según nivel
		if porcentaje < 20:
			label_agua.add_theme_color_override("font_color", Color.RED)
		elif porcentaje < 50:
			label_agua.add_theme_color_override("font_color", Color.ORANGE)
		else:
			label_agua.add_theme_color_override("font_color", Color.GREEN)
	
	if label_puntos:
		label_puntos.text = "⭐ Puntos: " + str(puntos) + " | ❌ Errores: " + str(errores_cometidos)
	
	if label_mision and mision_actual.has("descripcion"):
		var valvula_mision = valvulas[mision_actual["valvula"]]
		var progreso = valvula_mision["necesita_agua"]
		var objetivo = mision_actual["cantidad_exacta"]
		label_mision.text = "🎯 " + mision_actual["descripcion"] + "\n📊 Progreso: " + str(int(progreso)) + "/" + str(int(objetivo)) + "L"
	
	# Actualizar visual del tanque
	if tanque_sprite:
		var escala = agua_en_tanque / capacidad_maxima
		# Aquí podrías animar el nivel del agua dentro del tanque

func mostrar_mensaje_guia(mensaje, duracion = 3.0):
	if guia:
		var label_guia = guia.get_node_or_null("Panel/Label")
		if label_guia:
			label_guia.text = mensaje
		guia.visible = true
		
		# Ocultar después de la duración
		if duracion > 0:
			await get_tree().create_timer(duracion).timeout
			guia.visible = false

func game_won():
	mostrar_mensaje_guia("🏆 ¡FELICIDADES! Completaste todas las misiones. Has demostrado ser un experto en conservación del agua.\n\n📊 Estadísticas:\n• Puntos: " + str(puntos) + "\n• Agua ahorrada: " + str(int(capacidad_maxima * 5 - agua_total_desperdiciada)) + "L\n• Errores: " + str(errores_cometidos), 0)
	get_tree().paused = true

func _input(event):
	# Presionar ESPACIO para ocultar mensajes del guía manualmente
	if event.is_action_pressed("ui_accept") and guia and guia.visible:
		guia.visible = false
