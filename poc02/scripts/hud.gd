# HUD — Control nodes en código: prompt, inventario, diálogo, inspección
# SubViewport, overlay de inicio y debug (SPEC_02 §15-16, INS-001..003, UI-001)
class_name Poc02Hud
extends CanvasLayer

var player: Poc02Player
var prompt: Label
var debug: Label
var toast: Label
var inv_panel: PanelContainer
var inv_list: VBoxContainer
var dlg_panel: PanelContainer
var dlg_text: Label
var dlg_options: VBoxContainer
var insp_panel: PanelContainer
var insp_viewport: SubViewport
var insp_pivot: Node3D
var start_overlay: ColorRect
var _toast_left := 0.0
var _dragging := false
var _active_npc: ResidentNpc = null


func _ready() -> void:
	add_to_group("hud")
	layer = 10

	start_overlay = ColorRect.new()
	start_overlay.color = Color(0.06, 0.08, 0.12, 0.96)
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(start_overlay)
	var sl := Label.new()
	sl.text = "MANIAC GALIANO — POC02 (Godot Web)\n\nHaz clic para empezar\n\nWASD mover · Ratón cámara · Rueda zoom · R recentrar\nE interactuar · I inventario · F5 guardar · F9 cargar · F10 reset · Esc soltar ratón"
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.set_anchors_preset(Control.PRESET_CENTER)
	sl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	start_overlay.add_child(sl)

	prompt = Label.new()
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position.y -= 70
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt)

	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.position.y -= 110
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate = Color(1, 0.9, 0.5)
	add_child(toast)

	debug = Label.new()
	debug.position = Vector2(10, 8)
	debug.modulate = Color(0.8, 0.9, 1.0)
	add_child(debug)

	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	inv_panel.position.x -= 40
	inv_panel.visible = false
	add_child(inv_panel)
	inv_list = VBoxContainer.new()
	inv_panel.add_child(inv_list)

	dlg_panel = PanelContainer.new()
	dlg_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dlg_panel.position += Vector2(-220, -200)
	dlg_panel.custom_minimum_size = Vector2(440, 0)
	dlg_panel.visible = false
	add_child(dlg_panel)
	var dv := VBoxContainer.new()
	dlg_panel.add_child(dv)
	dlg_text = Label.new()
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(dlg_text)
	dlg_options = VBoxContainer.new()
	dv.add_child(dlg_options)

	_build_inspection()
	GameState.inventory_changed.connect(_refresh_inventory)

	if not SaveService.is_persistent():
		var warn := Label.new()
		warn.text = "⚠ Almacenamiento del navegador no persistente: el guardado puede perderse."
		warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
		warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.modulate = Color(1, 0.7, 0.4)
		add_child(warn)


func _build_inspection() -> void:
	insp_panel = PanelContainer.new()
	insp_panel.set_anchors_preset(Control.PRESET_CENTER)
	insp_panel.visible = false
	add_child(insp_panel)
	var v := VBoxContainer.new()
	insp_panel.add_child(v)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.custom_minimum_size = Vector2(420, 320)
	v.add_child(cont)
	insp_viewport = SubViewport.new()
	insp_viewport.own_world_3d = true            # INS-001: render aislado
	insp_viewport.transparent_bg = false
	cont.add_child(insp_viewport)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 1.4)
	insp_viewport.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	insp_viewport.add_child(light)
	insp_pivot = Node3D.new()
	insp_viewport.add_child(insp_pivot)
	var hint := Label.new()
	hint.text = "Arrastra para rotar · E o clic derecho para cerrar"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if start_overlay.visible:
		if event is InputEventMouseButton and event.pressed:
			start_overlay.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().call_group("audio_root", "unlock_audio")   # AUD-001
		return
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and not dlg_panel.visible and not insp_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("inventory"):
		inv_panel.visible = not inv_panel.visible
		_refresh_inventory()
	elif event.is_action_pressed("save_game"):
		show_toast("Guardado." if SaveService.save_game(player) else "No se pudo guardar.")
	elif event.is_action_pressed("load_game"):
		show_toast("Cargado." if SaveService.load_game(player) else "No hay partida guardada.")
	elif event.is_action_pressed("reset_game"):
		SaveService.clear_save()
		GameState.reset()
		get_tree().reload_current_scene()
	if insp_panel.visible:
		_inspection_input(event)


func _inspection_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			close_inspection()
	elif event is InputEventMouseMotion and _dragging:
		insp_pivot.rotation.y += event.relative.x * 0.01     # INS-002
		insp_pivot.rotation.x += event.relative.y * 0.01
	elif event.is_action_pressed("interact"):
		close_inspection()


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			toast.text = ""
	if player:
		debug.text = "FPS %d · sala: %s · dist %.1f/%.1f · modo cam %d" % [
			Engine.get_frames_per_second(), GameState.room_id,
			player.spring.get_hit_length(), player.preferred_distance, player.cam_mode]


func set_prompt(text: String) -> void:
	prompt.text = text


func show_toast(text: String) -> void:
	toast.text = text
	_toast_left = 2.5


func _refresh_inventory() -> void:
	for c in inv_list.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "INVENTARIO"
	inv_list.add_child(title)
	if GameState.inventory.is_empty():
		var l := Label.new()
		l.text = "(vacío)"
		inv_list.add_child(l)
	for item in GameState.inventory:
		var b := Button.new()
		b.text = ("▸ " if GameState.selected_item == item else "  ") + str(item)
		b.pressed.connect(func() -> void:
			GameState.selected_item = str(item)
			_refresh_inventory())
		inv_list.add_child(b)


# --- Inspección (INS-001..003): reutiliza el mesh del objeto del mundo ---
func show_inspection(source: Node) -> void:
	for c in insp_pivot.get_children():
		c.queue_free()
	var src_mesh: MeshInstance3D = source.get_node_or_null("Mesh")
	if src_mesh:
		var copy := MeshInstance3D.new()
		copy.mesh = src_mesh.mesh
		copy.material_override = src_mesh.material_override
		insp_pivot.add_child(copy)
	insp_pivot.rotation = Vector3.ZERO
	insp_panel.visible = true
	player.cam_mode = Poc02Player.CamMode.INSPECTION
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inspection() -> void:
	insp_panel.visible = false
	player.cam_mode = Poc02Player.CamMode.FREE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Diálogo (DIA-001..003) ---
func start_dialogue(npc: ResidentNpc) -> void:
	_active_npc = npc
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_dialogue_node("start")


func _show_dialogue_node(key: String) -> void:
	if key == "" or not _active_npc.dialogue.has(key):
		dlg_panel.visible = false
		_active_npc.end_dialogue(player)
		_active_npc = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var node: Dictionary = _active_npc.dialogue[key]
	if node.has("set_flag"):
		GameState.set_flag(str(node.set_flag), true)
	dlg_text.text = "%s: %s" % [node.get("speaker", "?"), node.text]
	for c in dlg_options.get_children():
		c.queue_free()
	for opt in node.options:
		var o: Dictionary = opt
		if o.has("requires_item") and not GameState.has_item(str(o.requires_item)):
			continue                        # DIA-002: opción condicionada por inventario
		if o.has("requires_flag") and not GameState.get_flag(str(o.requires_flag)):
			continue
		var b := Button.new()
		b.text = str(o.text)
		b.pressed.connect(func() -> void: _show_dialogue_node(str(o.next)))
		dlg_options.add_child(b)
	dlg_panel.visible = true
