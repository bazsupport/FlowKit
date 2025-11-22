@tool
extends MarginContainer

signal insert_condition_requested(condition_node)
signal delete_condition_requested(condition_node)
signal negate_condition_requested(condition_node)
signal edit_condition_requested(condition_node)

var condition_data: FKEventCondition
var event_index: int = -1
var condition_index: int = -1

var context_menu: PopupMenu
var label: Label

func _ready() -> void:
	label = get_node_or_null("Panel/MarginContainer/HBoxContainer/Label")
	
	# Connect gui_input for right-click detection
	gui_input.connect(_on_gui_input)
	
	# Try to get context menu and connect if available
	call_deferred("_setup_context_menu")

func _setup_context_menu() -> void:
	context_menu = get_node_or_null("ContextMenu")
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Try to get context menu if we don't have it yet
			if not context_menu:
				context_menu = get_node_or_null("ContextMenu")
				if context_menu and not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
					context_menu.id_pressed.connect(_on_context_menu_id_pressed)
			
			if context_menu:
				context_menu.position = get_global_mouse_position()
				context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Insert Condition Below
			insert_condition_requested.emit(self)
		1: # Edit Condition
			edit_condition_requested.emit(self)
		2: # Delete Condition
			delete_condition_requested.emit(self)
		3: # Negate
			negate_condition_requested.emit(self)
			print("Negate condition requested for: ", condition_data.condition_id if condition_data else "unknown")

func set_condition_data(data: FKEventCondition, evt_index: int, cond_index: int) -> void:
	condition_data = data
	event_index = evt_index
	condition_index = cond_index
	_update_label()

func _update_label() -> void:
	if label and condition_data:
		var params_text = ""
		if not condition_data.inputs.is_empty():
			var param_pairs = []
			for key in condition_data.inputs:
				param_pairs.append("%s: %s" % [key, condition_data.inputs[key]])
			params_text = " [" + ", ".join(param_pairs) + "]"
		
		# Check if this is a standalone condition (event_index == -1)
		var prefix = "Standalone Condition" if event_index == -1 else "Condition"
		label.text = "%s: %s%s" % [prefix, condition_data.condition_id, params_text]

func _get_drag_data(at_position: Vector2):
	var preview := duplicate()
	preview.modulate.a = 0.5
	set_drag_preview(preview)
	return self
