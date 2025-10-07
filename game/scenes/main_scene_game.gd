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
		"sprite_node": null,
		"nombre_display": "Válvula de Cisterna",
		"descripcion": "Para almacenar agua"
	},
	"ValvulaLavado": {
		"abierta": false,
		"flujo": 10.0,
		"proposito": "limpieza",
		"necesita_agua": 0.0,
		"sprite_node": null,
		"nombre_display": "Válvula de Lavado",
		"descripcion": "Para tareas de limpieza"
	},
	"ValvulaDesague": {
		"abierta": false,
		"flujo": 15.0,
		"proposito": "desague",
		"necesita_agua": 0.0,
		"sprite_node": null,
		"nombre_display": "Válvula de Desagüe",
		"descripcion": "Para drenar agua (¡Cuidado!)"
	}
}

# ========== SISTEMA DE CLIMA/RECARGA ==========
var tiempo_hasta_lluvia = 10.0
var esta_lloviendo = false

# ========== REFERENCIAS A NODOS UI ==========
# Usando get_node_or_null para evitar errores si los nodos no existen aún
@onready var guia = get_node_or_null("CanvasLayer2/Guia")
@onready var label_agua = get_node_or_null("CanvasLayer2/Guia/CanvasLayer/HUD/LabelAgua")
@onready var label_puntos = get_node_or_null("CanvasLayer2/Guia/CanvasLayer/HUD/LabelPuntos")
@onready var label_mision = get_node_or_null("CanvasLayer2/Guia/CanvasLayer/HUD/LabelMision")
@onready var tanque_sprite = get_node_or_null("TanqueAgua")

# ========== LISTA DE MISIONES POSIBLES ==========
# ========== LISTA DE MISIONES POSIBLES ==========
var lista_misiones = [
	{
		"descripcion": "Llena la cisterna con 35 litros para emergencias",
		"valvula": "ValvulaCisterna",
		"cantidad_exacta": 35.0,
		"margen_error": 5.0,
		"puntos_recompensa": 60,
		"consejo_inicial": "💧 Almacenar agua es inteligente, pero llena solo lo necesario para no desperdiciar.",
		"consejo_error": "La cisterna se desbordó. Siempre calcula cuánta agua necesitas antes de abrir la válvula."
	},
	{
		"descripcion": "Usa 25 litros para lavar el patio eficientemente",
		"valvula": "ValvulaLavado",
		"cantidad_exacta": 25.0,
		"margen_error": 4.0,
		"puntos_recompensa": 55,
		"consejo_inicial": "🧹 Para limpiar eficientemente, usa solo el agua necesaria. ¡No desperdicies!",
		"consejo_error": "¡Demasiada agua! Podrías haber limpiado igual de bien usando menos agua."
	},
	{
		"descripcion": "Drena 20 litros de agua sucia por el desagüe",
		"valvula": "ValvulaDesague",
		"cantidad_exacta": 20.0,
		"margen_error": 3.0,
		"puntos_recompensa": 45,
		"consejo_inicial": "🚰 A veces necesitamos drenar agua, pero hazlo con precisión para no malgastar agua limpia.",
		"consejo_error": "Has drenado demasiada agua. El desagüe debe usarse con cuidado."
	},
	{
		"descripcion": "Llena la cisterna con 50 litros para el día",
		"valvula": "ValvulaCisterna",
		"cantidad_exacta": 50.0,
		"margen_error": 6.0,
		"puntos_recompensa": 70,
		"consejo_inicial": "💦 Una cisterna llena te da seguridad, pero no desperdicies llenándola de más.",
		"consejo_error": "Se ha desbordado agua de la cisterna. ¡Siempre vigila el nivel!"
	},
	{
		"descripcion": "Lava con solo 18 litros (modo eco)",
		"valvula": "ValvulaLavado",
		"cantidad_exacta": 18.0,
		"margen_error": 3.0,
		"puntos_recompensa": 80,
		"consejo_inicial": "♻️ El modo eco usa menos agua. ¡Demuestra que puedes limpiar sin desperdiciar!",
		"consejo_error": "Has gastado más agua de la necesaria. El modo eco requiere precisión."
	}
]

func _ready():
	print("🌊 Juego de Conservación del Agua - Versión Mejorada")
	conectar_valvulas()
	actualizar_interfaz()
	# Usar call_deferred para iniciar la misión después de que todo esté listo
	call_deferred("iniciar_nueva_mision")
	call_deferred("mostrar_mensaje_guia", "¡Bienvenido! Soy tu guía del agua. Te enseñaré a usar este recurso de manera responsable. ¡Presta atención a las misiones!", 5.0)

func conectar_valvulas():
	# Conectar señales de cada válvula disponible en la escena
	print("🔍 Buscando válvulas...")
	for valvula_nombre in valvulas.keys():
		var valvula_node = get_node_or_null(valvula_nombre)  # Busca por el nombre exacto
		if valvula_node:
			print("✅ Válvula encontrada: " + valvula_nombre)
			valvulas[valvula_nombre]["sprite_node"] = valvula_node
			if valvula_node.has_signal("input_event"):
				valvula_node.input_event.connect(_on_valvula_clicked.bind(valvula_nombre))
				print("   🔗 Señal conectada correctamente")
			else:
				print("   ❌ ERROR: No tiene señal input_event")
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

func _on_valvula_clicked(_viewport, event, _shape_idx, valvula_nombre):
	print("🖱️ Evento detectado en: " + valvula_nombre)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("👆 Click confirmado en: " + valvula_nombre)
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
		if valvula["abierta"]:
			valvula["abierta"] = false
	
	# Seleccionar misión aleatoria
	var mision_index = randi() % lista_misiones.size()
	mision_actual = lista_misiones[mision_index].duplicate()
	mision_actual["agua_usada"] = 0.0
	mision_actual["completada"] = false
	
	print("📋 Nueva misión asignada: " + mision_actual["descripcion"])
	print("🎯 Válvula objetivo: " + mision_actual["valvula"])
	
	# Actualizar la interfaz inmediatamente
	actualizar_interfaz()
	
	# Mostrar mensaje del guía
	if guia:
		mostrar_mensaje_guia("📋 Nueva Misión: " + mision_actual["descripcion"] + "\n\n💡 " + mision_actual["consejo_inicial"], 6.0)

func verificar_progreso_mision():
	if mision_actual.has("valvula") and not mision_actual["completada"]:
		# Verificar que la válvula existe en el diccionario
		if not valvulas.has(mision_actual["valvula"]):
			print("❌ ERROR: La válvula de la misión no existe: " + mision_actual["valvula"])
			return
		
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
	
	# Actualizar visual del tanque (escala removida por ahora)
	# if tanque_sprite:
	#     var escala = agua_en_tanque / capacidad_maxima

func mostrar_mensaje_guia(mensaje, duracion = 3.0):
	if guia:
		var label_guia = guia.get_node_or_null("Panel/Label")
		if label_guia:
			label_guia.text = mensaje
			print("💬 Guía dice: " + mensaje)
		else:
			print("⚠️ No se encontró Panel/Label en Guia")
		
		guia.visible = true
		
		# Ocultar después de la duración (solo si duracion > 0)
		if duracion > 0:
			await get_tree().create_timer(duracion).timeout
			if guia:  # Verificar que sigue existiendo
				guia.visible = false
	else:
		print("⚠️ Nodo 'Guia' no encontrado. Mensaje: " + mensaje)

func game_won():
	mostrar_mensaje_guia("🏆 ¡FELICIDADES! Completaste todas las misiones. Has demostrado ser un experto en conservación del agua.\n\n📊 Estadísticas:\n• Puntos: " + str(puntos) + "\n• Agua ahorrada: " + str(int(capacidad_maxima * 5 - agua_total_desperdiciada)) + "L\n• Errores: " + str(errores_cometidos), 0)
	get_tree().paused = true

func _input(event):
	# Presionar ESPACIO para ocultar mensajes del guía manualmente
	if event.is_action_pressed("ui_accept") and guia and guia.visible:
		guia.visible = false
