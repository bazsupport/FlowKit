@tool
extends Control

var scene_name: String
var editor_interface: EditorInterface

var event_action = load("res://addons/flowkit/resources/event_action.gd")
var event_block = load("res://addons/flowkit/resources/event_block.gd")
var event_condition = load("res://addons/flowkit/resources/event_condition.gd")

# Preload scene files for instantiation
var event_scene = preload("res://addons/flowkit/ui/workspace/event.tscn")
var condition_scene = preload("res://addons/flowkit/ui/workspace/condition.tscn")
var action_scene = preload("res://addons/flowkit/ui/workspace/action.tscn")

@onready var menubar := $ScrollContainer/MarginContainer/VBoxContainer/MenuBar
@onready var content_container := $ScrollContainer/MarginContainer/VBoxContainer
@onready var no_action_available := $"ScrollContainer/MarginContainer/VBoxContainer/No Action Available"
@onready var add_event_button := $ScrollContainer/MarginContainer/VBoxContainer/AddEventButton
@onready var add_condition_button := $ScrollContainer/MarginContainer/VBoxContainer/AddConditionButton
@onready var add_action_button := $ScrollContainer/MarginContainer/VBoxContainer/AddActionButton
@onready var select_modal := $SelectModal
@onready var select_event_modal := $SelectEventModal
@onready var select_action_node_modal := $SelectActionNodeModal
@onready var select_action_modal := $SelectActionModal
@onready var select_condition_node_modal := $SelectConditionNodeModal
@onready var select_condition_modal := $SelectConditionModal
@onready var expression_editor_modal := $ExpressionEditorModal
@onready var condition_expression_editor_modal := $ConditionExpressionEditorModal

func _ready() -> void:
	# Connect when running inside the editor
	if menubar and menubar.has_signal("new_sheet"):
		menubar.new_sheet.connect(_generate_new_project)
	
	# Connect to visibility changes
	visibility_changed.connect(_on_visibility_changed)
	
	# Show empty state by default
	_show_empty_state()

func _on_visibility_changed() -> void:
	"""Called when the panel is shown or hidden."""
	if visible and editor_interface:
		# Refresh the event sheet when panel becomes visible
		var current_scene = editor_interface.get_edited_scene_root()
		if current_scene:
			var scene_path = current_scene.scene_file_path
			var new_name = scene_path.get_file().get_basename()
			if new_name != scene_name:
				scene_name = new_name
			_load_and_display_current_sheet()

func _load_and_display_current_sheet() -> void:
	"""Load and display the event sheet for the current scene."""
	if scene_name.is_empty():
		_show_empty_state()
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	if FileAccess.file_exists(file_path):
		var loaded_sheet = ResourceLoader.load(file_path)
		if loaded_sheet is FKEventSheet:
			_display_sheet(loaded_sheet)
		else:
			_show_empty_state()
	else:
		_show_empty_state()

func _process(_delta: float) -> void:
	if editor_interface:
		update_scene_name()

func _generate_new_project():
	# Check if the scene has been saved
	if scene_name.is_empty():
		push_warning("Cannot create event sheet: Scene has not been saved yet. Please save the scene first.")
		return
	
	print("Generating new FlowKit project...")
	var new_sheet = FKEventSheet.new()
	
	# Ensure the directory exists
	var dir_path = "res://addons/flowkit/saved/event_sheet"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save to a new resource file
	var file_path = "%s/%s.tres" % [dir_path, scene_name]
	print("Saving event sheet to: ", file_path)

	var error = ResourceSaver.save(new_sheet, file_path)
	if error == OK:
		print("New FlowKit event sheet created at: ", file_path)
	else:
		print("Failed to create new FlowKit event sheet. Error code: ", error)
	
	_display_sheet(new_sheet)

func set_scene_name(name: String):
	scene_name = name
	print("Scene name set: ", scene_name)

func update_scene_name():
	var current_scene = editor_interface.get_edited_scene_root()
	var new_name = ""
	
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != "":
			new_name = scene_path.get_file().get_basename()
	
	if new_name != scene_name:
		scene_name = new_name
		_load_and_display_current_sheet()

func set_editor_interface(interface: EditorInterface):
	editor_interface = interface
	update_scene_name()

func _on_add_event_button_pressed() -> void:
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	# Pass the editor interface to the modal so it can access node icons
	select_modal.set_editor_interface(editor_interface)
	
	# Populate the modal with nodes from the current scene
	select_modal.populate_from_scene(current_scene)
	
	# Show the popup centered
	select_modal.popup_centered()

func _on_select_modal_node_selected(node_path: String, node_class: String) -> void:
	print("Node selected in editor UI: ", node_path, " (", node_class, ")")
	# Hide the node selection modal
	select_modal.hide()
	# Open the event selection modal
	select_event_modal.populate_events(node_path, node_class)
	select_event_modal.popup_centered()

func _on_select_modal_event_selected(node_path: String, event_id: String) -> void:
	print("Event selected - Node: ", node_path, " Event: ", event_id)
	# TODO: Create a new event block and add it to the event sheet
	# For now, just print the selection
	_create_event_block(node_path, event_id)

func _create_event_block(node_path: String, event_id: String) -> void:
	"""Create a new event block and add it to the current event sheet."""
	# Load or create the event sheet for the current scene
	var file_path: String = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet: FKEventSheet = null
	
	if FileAccess.file_exists(file_path):
		sheet = ResourceLoader.load(file_path)
	else:
		sheet = FKEventSheet.new()
	
	if not sheet:
		print("Failed to load or create event sheet")
		return
	
	# Create a new event block
	var new_event = FKEventBlock.new()
	new_event.event_id = event_id
	new_event.target_node = node_path
	
	# Create a new events array with existing events plus the new one
	var new_events: Array[FKEventBlock] = []
	for existing_event in sheet.events:
		new_events.append(existing_event)
	new_events.append(new_event)
	
	# Replace the events array
	sheet.events = new_events
	
	# Save the sheet
	var error = ResourceSaver.save(sheet, file_path)
	if error == OK:
		print("Event block added and saved successfully")
		# Refresh the UI
		_display_sheet(sheet)
	else:
		print("Failed to save event sheet. Error code: ", error)

func _clear_content() -> void:
	"""Clear all dynamically created event, condition, and action nodes."""
	if not content_container:
		return
	
	# Get the index of menubar and no_action_available to know the range
	var menubar_index = menubar.get_index()
	var no_action_index = no_action_available.get_index()
	
	# Remove all children between menubar and no_action_available (in reverse to avoid index issues)
	for i in range(no_action_index - 1, menubar_index, -1):
		var child = content_container.get_child(i)
		child.queue_free()

func _show_empty_state() -> void:
	"""Show the 'No Action Available' message and hide the buttons."""
	_clear_content()
	if no_action_available:
		no_action_available.visible = true
	if add_event_button:
		add_event_button.visible = false
	if add_condition_button:
		add_condition_button.visible = false
	if add_action_button:
		add_action_button.visible = false

func _show_content_state() -> void:
	"""Hide the 'No Action Available' message and show the buttons."""
	if no_action_available:
		no_action_available.visible = false
	if add_event_button:
		add_event_button.visible = true
	if add_condition_button:
		add_condition_button.visible = true
	if add_action_button:
		add_action_button.visible = true

func _populate_event_sheet(sheet: FKEventSheet) -> void:
	"""Populate the UI with events, conditions, and actions from the event sheet."""
	if not sheet or not content_container:
		return
	
	# Clear existing content first
	_clear_content()
	
	# Show buttons and hide empty state
	_show_content_state()
	
	# Get the index where we should insert (right after menubar)
	var insert_index = menubar.get_index() + 1
	
	# Display standalone conditions first
	for cond_idx in range(sheet.standalone_conditions.size()):
		var condition = sheet.standalone_conditions[cond_idx]
		var condition_node = condition_scene.instantiate()
		content_container.add_child(condition_node)
		content_container.move_child(condition_node, insert_index)
		
		# Set data with -1 event_index to indicate standalone
		condition_node.set_condition_data(condition, -1, cond_idx)
		condition_node.insert_condition_requested.connect(_on_insert_standalone_condition_requested)
		condition_node.delete_condition_requested.connect(_on_delete_standalone_condition_requested)
		condition_node.negate_condition_requested.connect(_on_negate_standalone_condition_requested)
		condition_node.edit_condition_requested.connect(_on_edit_standalone_condition_requested)
		
		insert_index += 1
		
		# Display actions for this standalone condition
		for act_idx in range(condition.actions.size()):
			var action = condition.actions[act_idx]
			var action_node = action_scene.instantiate()
			content_container.add_child(action_node)
			content_container.move_child(action_node, insert_index)
			
			# Set data with -1 event_index and store condition index
			action_node.set_action_data(action, -1, act_idx)
			action_node.set_meta("standalone_condition_index", cond_idx)
			action_node.insert_action_requested.connect(_on_insert_standalone_action_requested)
			action_node.delete_action_requested.connect(_on_delete_standalone_action_requested)
			action_node.edit_action_requested.connect(_on_edit_standalone_action_requested)
			
			insert_index += 1
	
	# Loop through all events in the sheet
	for event_idx in range(sheet.events.size()):
		var event = sheet.events[event_idx]
		
		# Create and add event node
		var event_node = event_scene.instantiate()
		content_container.add_child(event_node)
		content_container.move_child(event_node, insert_index)
		
		# Set data and connect signals
		event_node.set_event_data(event, event_idx)
		event_node.insert_condition_requested.connect(_on_insert_condition_requested)
		event_node.delete_event_requested.connect(_on_delete_event_requested)
		event_node.edit_event_requested.connect(_on_edit_event_requested)
		
		insert_index += 1
		
		# Loop through all conditions in this event
		for cond_idx in range(event.conditions.size()):
			var condition = event.conditions[cond_idx]
			var condition_node = condition_scene.instantiate()
			content_container.add_child(condition_node)
			content_container.move_child(condition_node, insert_index)
			
			# Set data and connect signals
			condition_node.set_condition_data(condition, event_idx, cond_idx)
			condition_node.insert_condition_requested.connect(_on_insert_condition_requested)
			condition_node.delete_condition_requested.connect(_on_delete_condition_requested)
			condition_node.negate_condition_requested.connect(_on_negate_condition_requested)
			condition_node.edit_condition_requested.connect(_on_edit_condition_requested)
			
			insert_index += 1
		
		# Loop through all actions in this event
		for act_idx in range(event.actions.size()):
			var action = event.actions[act_idx]
			var action_node = action_scene.instantiate()
			content_container.add_child(action_node)
			content_container.move_child(action_node, insert_index)
			
			# Set data and connect signals
			action_node.set_action_data(action, event_idx, act_idx)
			action_node.insert_action_requested.connect(_on_insert_action_requested)
			action_node.delete_action_requested.connect(_on_delete_action_requested)
			action_node.edit_action_requested.connect(_on_edit_action_requested)
			
			insert_index += 1

func _display_sheet(data: Variant) -> void:
	if not data == FKEventSheet:
		var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
		if FileAccess.file_exists(file_path):
			var loaded_sheet = ResourceLoader.load(file_path)
			if loaded_sheet is FKEventSheet:
				data = loaded_sheet
				print("Loaded existing event sheet: ", file_path)
			else:
				print("File exists but is not a valid FKEventSheet")
				_show_empty_state()
				return
		else:
			print("No existing event sheet found for scene: ", scene_name)
			_show_empty_state()
			return
	
	# Populate the UI with the event sheet data
	_populate_event_sheet(data)

# Context menu handlers

var pending_condition_node_index: int = -1
var pending_condition_index: int = -1
var pending_condition_node_path: String = ""
var pending_condition_node_class: String = ""
var pending_condition_id: String = ""
var pending_condition_inputs: Array = []
var is_editing_condition: bool = false

func _on_insert_condition_requested(node) -> void:
	"""Insert a new condition. Called from both event and condition nodes - start workflow."""
	var event_idx = node.event_index
	if event_idx < 0:
		print("Invalid event index")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size():
		return
	
	# Store context for later
	pending_condition_node_index = event_idx
	
	# Determine where to insert
	if node.has_method("set_condition_data"): # It's a condition node
		pending_condition_index = node.condition_index + 1
	else: # It's an event node
		pending_condition_index = 0
	
	# Start the condition selection workflow
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	# Pass the editor interface to the modal so it can access node icons
	select_condition_node_modal.set_editor_interface(editor_interface)
	
	# Populate the modal with nodes from the current scene
	select_condition_node_modal.populate_from_scene(current_scene)
	
	# Show the popup centered
	select_condition_node_modal.popup_centered()

func _on_delete_event_requested(event_node) -> void:
	"""Delete an event."""
	var event_idx = event_node.event_index
	if event_idx < 0:
		print("Invalid event index")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size():
		return
	
	# Create new events array without the deleted event
	var new_events: Array[FKEventBlock] = []
	for i in range(sheet.events.size()):
		if i != event_idx:
			new_events.append(sheet.events[i])
	
	sheet.events = new_events
	_save_and_refresh(sheet, file_path)

func _on_delete_condition_requested(condition_node) -> void:
	"""Delete a condition."""
	var event_idx = condition_node.event_index
	var cond_idx = condition_node.condition_index
	
	if event_idx < 0 or cond_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size():
		return
	
	# Create new conditions array without the deleted condition
	var new_conditions: Array[FKEventCondition] = []
	for i in range(sheet.events[event_idx].conditions.size()):
		if i != cond_idx:
			new_conditions.append(sheet.events[event_idx].conditions[i])
	
	sheet.events[event_idx].conditions = new_conditions
	_save_and_refresh(sheet, file_path)

func _on_negate_condition_requested(condition_node) -> void:
	"""Negate a condition (placeholder for now)."""
	print("Negate condition at event %d, condition %d" % [condition_node.event_index, condition_node.condition_index])

func _on_insert_action_requested(action_node) -> void:
	"""Insert a new action below the selected action."""
	var event_idx = action_node.event_index
	var action_idx = action_node.action_index
	
	if event_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size():
		return
	
	# Create a new action
	var new_action = FKEventAction.new()
	new_action.action_id = "new_action"
	new_action.target_node = sheet.events[event_idx].target_node
	
	# Create new actions array with the new action inserted
	var new_actions: Array[FKEventAction] = []
	for i in range(sheet.events[event_idx].actions.size()):
		new_actions.append(sheet.events[event_idx].actions[i])
		if i == action_idx:
			new_actions.append(new_action)
	
	sheet.events[event_idx].actions = new_actions
	_save_and_refresh(sheet, file_path)

func _on_delete_action_requested(action_node) -> void:
	"""Delete an action."""
	var event_idx = action_node.event_index
	var action_idx = action_node.action_index
	
	if event_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size():
		return
	
	# Create new actions array without the deleted action
	var new_actions: Array[FKEventAction] = []
	for i in range(sheet.events[event_idx].actions.size()):
		if i != action_idx:
			new_actions.append(sheet.events[event_idx].actions[i])
	
	sheet.events[event_idx].actions = new_actions
	_save_and_refresh(sheet, file_path)

func _on_edit_event_requested(event_node) -> void:
	"""Edit an event (currently just logs info)."""
	print("Edit event at index %d" % event_node.event_index)
	# Future: Open event editor dialog

func _on_edit_condition_requested(condition_node) -> void:
	"""Edit a condition's parameters."""
	var event_idx = condition_node.event_index
	var cond_idx = condition_node.condition_index
	
	if event_idx < 0 or cond_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size() or cond_idx >= sheet.events[event_idx].conditions.size():
		return
	
	var condition = sheet.events[event_idx].conditions[cond_idx]
	
	# Store context for saving later
	is_editing_condition = true
	pending_condition_node_index = event_idx
	pending_condition_index = cond_idx
	pending_condition_id = condition.condition_id
	pending_condition_node_path = String(condition.target_node)
	
	# Convert inputs Dictionary to Array format expected by expression editor
	var inputs_array = []
	for key in condition.inputs.keys():
		inputs_array.append({"name": key, "type": "string"})
	
	# Open expression editor with current values
	condition_expression_editor_modal.populate_inputs(pending_condition_node_path, pending_condition_id, inputs_array)
	# Pre-fill with existing values - need to modify expression editor to accept initial values
	# For now, it will be empty fields
	condition_expression_editor_modal.popup_centered()

func _on_edit_action_requested(action_node) -> void:
	"""Edit an action's parameters."""
	var event_idx = action_node.event_index
	var action_idx = action_node.action_index
	
	if event_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or event_idx >= sheet.events.size() or action_idx >= sheet.events[event_idx].actions.size():
		return
	
	var action = sheet.events[event_idx].actions[action_idx]
	
	# Store context for saving later
	is_editing_action = true
	pending_action_event_index = event_idx
	pending_action_index = action_idx
	pending_action_id = action.action_id
	pending_action_node_path = String(action.target_node)
	
	# Convert inputs Dictionary to Array format expected by expression editor
	var inputs_array = []
	for key in action.inputs.keys():
		inputs_array.append({"name": key, "type": "string"})
	
	# Open expression editor with current values
	expression_editor_modal.populate_inputs(pending_action_node_path, pending_action_id, inputs_array)
	# Pre-fill with existing values - need to modify expression editor to accept initial values
	# For now, it will be empty fields
	expression_editor_modal.popup_centered()

# Helper functions

func _load_event_sheet(file_path: String) -> FKEventSheet:
	"""Load an event sheet from disk."""
	if FileAccess.file_exists(file_path):
		return ResourceLoader.load(file_path)
	return null

func _save_and_refresh(sheet: FKEventSheet, file_path: String) -> void:
	"""Save the event sheet and refresh the UI."""
	var error: Error = ResourceSaver.save(sheet, file_path)
	if error == OK:
		print("Event sheet saved successfully")
		_display_sheet(sheet)
	else:
		print("Failed to save event sheet. Error code: ", error)

# Action workflow handlers

var pending_action_node_path: String = ""
var pending_action_node_class: String = ""
var pending_action_id: String = ""
var pending_action_inputs: Array = []
var is_editing_action: bool = false
var pending_action_event_index: int = -1
var pending_action_index: int = -1

func _on_add_action_button_pressed() -> void:
	"""Start the action adding workflow."""
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	# Pass the editor interface to the modal so it can access node icons
	select_action_node_modal.set_editor_interface(editor_interface)
	
	# Populate the modal with nodes from the current scene
	select_action_node_modal.populate_from_scene(current_scene)
	
	# Show the popup centered
	select_action_node_modal.popup_centered()

func _on_select_action_node_selected(node_path: String, node_class: String) -> void:
	"""Handle node selection for action - open action selection modal."""
	print("Node selected for action: ", node_path, " (", node_class, ")")
	pending_action_node_path = node_path
	pending_action_node_class = node_class
	
	# Hide the node selection modal
	select_action_node_modal.hide()
	
	# Open the action selection modal
	select_action_modal.populate_actions(node_path, node_class)
	select_action_modal.popup_centered()

func _on_select_action_modal_action_selected(node_path: String, action_id: String, action_inputs: Array) -> void:
	"""Handle action selection - open expression editor if inputs needed."""
	print("Action selected: ", action_id, " with inputs: ", action_inputs)
	pending_action_id = action_id
	pending_action_inputs = action_inputs
	
	# Hide the action selection modal
	select_action_modal.hide()
	
	# If the action has inputs, show the expression editor
	if action_inputs.size() > 0:
		expression_editor_modal.populate_inputs(node_path, action_id, action_inputs)
		expression_editor_modal.popup_centered()
	else:
		# No inputs needed, create the action directly
		if pending_standalone_action_condition_index >= 0:
			_create_standalone_action_with_expressions(node_path, action_id, {})
		else:
			_create_action_with_expressions(node_path, action_id, {})

func _on_expression_editor_confirmed(node_path: String, action_id: String, expressions: Dictionary) -> void:
	"""Handle expression editor confirmation - create or update the action."""
	print("Action confirmed with expressions: ", expressions)
	
	if is_editing_action:
		if pending_standalone_action_condition_index >= 0:
			# Update existing standalone condition action
			_update_standalone_action_with_expressions(pending_standalone_action_condition_index, pending_standalone_action_index, expressions)
			is_editing_action = false
			pending_standalone_action_condition_index = -1
			pending_standalone_action_index = -1
		else:
			# Update existing event action
			_update_action_with_expressions(pending_action_event_index, pending_action_index, expressions)
			is_editing_action = false
	elif pending_standalone_action_condition_index >= 0:
		# Create new standalone condition action
		_create_standalone_action_with_expressions(node_path, action_id, expressions)
		pending_standalone_action_condition_index = -1
		pending_standalone_action_index = -1
	else:
		# Create new event action
		_create_action_with_expressions(node_path, action_id, expressions)

func _create_action_with_expressions(node_path: String, action_id: String, expressions: Dictionary) -> void:
	"""Create a new action and add it to the most recent event or standalone condition in the event sheet."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	# Create a new action
	var new_action = FKEventAction.new()
	new_action.action_id = action_id
	new_action.target_node = node_path
	new_action.inputs = expressions
	
	# Prioritize adding to standalone conditions if they exist and no events
	if not sheet.standalone_conditions.is_empty() and sheet.events.is_empty():
		# Add to the last standalone condition
		var last_cond_idx = sheet.standalone_conditions.size() - 1
		
		# Create new actions array with the new action
		var new_actions: Array[FKEventAction] = []
		for existing_action in sheet.standalone_conditions[last_cond_idx].actions:
			new_actions.append(existing_action)
		new_actions.append(new_action)
		
		sheet.standalone_conditions[last_cond_idx].actions = new_actions
		_save_and_refresh(sheet, file_path)
	elif not sheet.events.is_empty():
		# Add to the last event
		var last_event_idx = sheet.events.size() - 1
		
		# Create new actions array with the new action
		var new_actions: Array[FKEventAction] = []
		for existing_action in sheet.events[last_event_idx].actions:
			new_actions.append(existing_action)
		new_actions.append(new_action)
		
		sheet.events[last_event_idx].actions = new_actions
		_save_and_refresh(sheet, file_path)
	else:
		print("No events or standalone conditions available. Please create one first.")
		return

func _update_action_with_expressions(event_idx: int, action_idx: int, expressions: Dictionary) -> void:
	"""Update an existing action's parameters."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or event_idx >= sheet.events.size() or action_idx >= sheet.events[event_idx].actions.size():
		print("Invalid indices for action update")
		return
	
	# Update the inputs
	sheet.events[event_idx].actions[action_idx].inputs = expressions
	_save_and_refresh(sheet, file_path)

func _create_standalone_action_with_expressions(node_path: String, action_id: String, expressions: Dictionary) -> void:
	"""Create a new action and add it to a standalone condition."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or pending_standalone_action_condition_index < 0 or pending_standalone_action_condition_index >= sheet.standalone_conditions.size():
		print("Invalid standalone condition index for action insertion")
		return
	
	# Create a new action
	var new_action = FKEventAction.new()
	new_action.action_id = action_id
	new_action.target_node = node_path
	new_action.inputs = expressions
	
	# Create new actions array with insertion at the correct position
	var new_actions: Array[FKEventAction] = []
	var insert_at = pending_standalone_action_index if pending_standalone_action_index >= 0 else sheet.standalone_conditions[pending_standalone_action_condition_index].actions.size()
	
	for i in range(sheet.standalone_conditions[pending_standalone_action_condition_index].actions.size()):
		new_actions.append(sheet.standalone_conditions[pending_standalone_action_condition_index].actions[i])
		if i == insert_at - 1:
			new_actions.append(new_action)
	
	# If inserting at the end or in an empty list
	if insert_at >= sheet.standalone_conditions[pending_standalone_action_condition_index].actions.size():
		new_actions.append(new_action)
	
	sheet.standalone_conditions[pending_standalone_action_condition_index].actions = new_actions
	_save_and_refresh(sheet, file_path)

func _update_standalone_action_with_expressions(condition_idx: int, action_idx: int, expressions: Dictionary) -> void:
	"""Update an existing standalone condition action's parameters."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or condition_idx >= sheet.standalone_conditions.size() or action_idx >= sheet.standalone_conditions[condition_idx].actions.size():
		print("Invalid indices for standalone action update")
		return
	
	# Update the inputs
	sheet.standalone_conditions[condition_idx].actions[action_idx].inputs = expressions
	_save_and_refresh(sheet, file_path)

# Standalone condition handlers

var pending_standalone_condition_index: int = -1
var pending_standalone_action_condition_index: int = -1
var pending_standalone_action_index: int = -1
var is_adding_standalone_condition: bool = false

func _on_add_condition_button_pressed() -> void:
	"""Start the standalone condition adding workflow."""
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	is_adding_standalone_condition = true
	
	# Pass the editor interface to the modal so it can access node icons
	select_condition_node_modal.set_editor_interface(editor_interface)
	
	# Populate the modal with nodes from the current scene
	select_condition_node_modal.populate_from_scene(current_scene)
	
	# Show the popup centered
	select_condition_node_modal.popup_centered()

func _on_insert_standalone_condition_requested(condition_node) -> void:
	"""Insert a new standalone condition."""
	var cond_idx = condition_node.condition_index
	if cond_idx < 0:
		print("Invalid condition index")
		return
	
	# Store context for later
	pending_standalone_condition_index = cond_idx + 1
	is_adding_standalone_condition = true
	
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	select_condition_node_modal.set_editor_interface(editor_interface)
	select_condition_node_modal.populate_from_scene(current_scene)
	select_condition_node_modal.popup_centered()

func _on_delete_standalone_condition_requested(condition_node) -> void:
	"""Delete a standalone condition."""
	var cond_idx = condition_node.condition_index
	if cond_idx < 0:
		print("Invalid condition index")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet:
		return
	
	# Create new standalone_conditions array without the deleted condition
	var new_conditions: Array[FKEventCondition] = []
	for i in range(sheet.standalone_conditions.size()):
		if i != cond_idx:
			new_conditions.append(sheet.standalone_conditions[i])
	
	sheet.standalone_conditions = new_conditions
	_save_and_refresh(sheet, file_path)

func _on_negate_standalone_condition_requested(condition_node) -> void:
	"""Negate a standalone condition (placeholder for now)."""
	print("Negate standalone condition at index %d" % condition_node.condition_index)

func _on_edit_standalone_condition_requested(condition_node) -> void:
	"""Edit a standalone condition's parameters."""
	var cond_idx = condition_node.condition_index
	if cond_idx < 0:
		print("Invalid condition index")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or cond_idx >= sheet.standalone_conditions.size():
		return
	
	var condition = sheet.standalone_conditions[cond_idx]
	
	# Store context for saving later
	is_editing_condition = true
	is_adding_standalone_condition = false
	pending_standalone_condition_index = cond_idx
	pending_condition_id = condition.condition_id
	pending_condition_node_path = String(condition.target_node)
	
	# Convert inputs Dictionary to Array format expected by expression editor
	var inputs_array = []
	for key in condition.inputs.keys():
		inputs_array.append({"name": key, "type": "string"})
	
	# Open expression editor with current values
	condition_expression_editor_modal.populate_inputs(pending_condition_node_path, pending_condition_id, inputs_array)
	condition_expression_editor_modal.popup_centered()

func _on_insert_standalone_action_requested(action_node) -> void:
	"""Insert a new action for a standalone condition."""
	var cond_idx = action_node.get_meta("standalone_condition_index", -1)
	var action_idx = action_node.action_index
	
	if cond_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	# Store context
	pending_standalone_action_condition_index = cond_idx
	pending_standalone_action_index = action_idx + 1
	
	if not editor_interface:
		print("Editor interface not available")
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		print("No scene currently open")
		return
	
	# Start action selection workflow
	select_action_node_modal.set_editor_interface(editor_interface)
	select_action_node_modal.populate_from_scene(current_scene)
	select_action_node_modal.popup_centered()

func _on_delete_standalone_action_requested(action_node) -> void:
	"""Delete a standalone condition action."""
	var cond_idx = action_node.get_meta("standalone_condition_index", -1)
	var action_idx = action_node.action_index
	
	if cond_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or cond_idx >= sheet.standalone_conditions.size():
		return
	
	# Create new actions array without the deleted action
	var new_actions: Array[FKEventAction] = []
	for i in range(sheet.standalone_conditions[cond_idx].actions.size()):
		if i != action_idx:
			new_actions.append(sheet.standalone_conditions[cond_idx].actions[i])
	
	sheet.standalone_conditions[cond_idx].actions = new_actions
	_save_and_refresh(sheet, file_path)

func _on_edit_standalone_action_requested(action_node) -> void:
	"""Edit a standalone condition action's parameters."""
	var cond_idx = action_node.get_meta("standalone_condition_index", -1)
	var action_idx = action_node.action_index
	
	if cond_idx < 0 or action_idx < 0:
		print("Invalid indices")
		return
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	if not sheet or cond_idx >= sheet.standalone_conditions.size() or action_idx >= sheet.standalone_conditions[cond_idx].actions.size():
		return
	
	var action = sheet.standalone_conditions[cond_idx].actions[action_idx]
	
	# Store context for saving later
	is_editing_action = true
	pending_standalone_action_condition_index = cond_idx
	pending_standalone_action_index = action_idx
	pending_action_id = action.action_id
	pending_action_node_path = String(action.target_node)
	
	# Convert inputs Dictionary to Array format expected by expression editor
	var inputs_array = []
	for key in action.inputs.keys():
		inputs_array.append({"name": key, "type": "string"})
	
	# Open expression editor with current values
	expression_editor_modal.populate_inputs(pending_action_node_path, pending_action_id, inputs_array)
	expression_editor_modal.popup_centered()

# Condition workflow handlers

func _on_select_condition_node_selected(node_path: String, node_class: String) -> void:
	"""Handle node selection for condition - open condition selection modal."""
	print("Node selected for condition: ", node_path, " (", node_class, ")")
	pending_condition_node_path = node_path
	pending_condition_node_class = node_class
	
	# Hide the node selection modal
	select_condition_node_modal.hide()
	
	# Open the condition selection modal
	select_condition_modal.populate_conditions(node_path, node_class)
	select_condition_modal.popup_centered()

func _on_select_condition_modal_condition_selected(node_path: String, condition_id: String, condition_inputs: Array) -> void:
	"""Handle condition selection - open expression editor if inputs needed."""
	print("Condition selected: ", condition_id, " with inputs: ", condition_inputs)
	pending_condition_id = condition_id
	pending_condition_inputs = condition_inputs
	
	# Hide the condition selection modal
	select_condition_modal.hide()
	
	# If the condition has inputs, show the expression editor
	if condition_inputs.size() > 0:
		condition_expression_editor_modal.populate_inputs(node_path, condition_id, condition_inputs)
		condition_expression_editor_modal.popup_centered()
	else:
		# No inputs needed, create the condition directly
		_create_condition_with_expressions(node_path, condition_id, {})

func _on_condition_expression_editor_confirmed(node_path: String, condition_id: String, expressions: Dictionary) -> void:
	"""Handle condition expression editor confirmation - create or update the condition."""
	print("Condition confirmed with expressions: ", expressions)
	
	if is_editing_condition:
		if is_adding_standalone_condition or pending_standalone_condition_index >= 0:
			# Update existing standalone condition
			_update_standalone_condition_with_expressions(pending_standalone_condition_index, expressions)
			is_editing_condition = false
			is_adding_standalone_condition = false
		else:
			# Update existing event condition
			_update_condition_with_expressions(pending_condition_node_index, pending_condition_index, expressions)
			is_editing_condition = false
	elif is_adding_standalone_condition:
		# Create new standalone condition
		_create_standalone_condition_with_expressions(node_path, condition_id, expressions)
		is_adding_standalone_condition = false
	else:
		# Create new event condition
		_create_condition_with_expressions(node_path, condition_id, expressions)

func _create_condition_with_expressions(node_path: String, condition_id: String, expressions: Dictionary) -> void:
	"""Create a new condition and insert it at the stored position."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or pending_condition_node_index >= sheet.events.size():
		print("Invalid event index for condition insertion")
		return
	
	# Create a new condition
	var new_condition = FKEventCondition.new()
	new_condition.condition_id = condition_id
	new_condition.target_node = node_path
	new_condition.inputs = expressions
	
	# Create new conditions array with insertion at the correct position
	var new_conditions: Array[FKEventCondition] = []
	var insert_at = pending_condition_index
	
	for i in range(sheet.events[pending_condition_node_index].conditions.size()):
		new_conditions.append(sheet.events[pending_condition_node_index].conditions[i])
		if i == insert_at - 1:
			new_conditions.append(new_condition)
	
	# If inserting at the end or in an empty list
	if insert_at >= sheet.events[pending_condition_node_index].conditions.size():
		new_conditions.append(new_condition)
	
	sheet.events[pending_condition_node_index].conditions = new_conditions
	_save_and_refresh(sheet, file_path)

func _update_condition_with_expressions(event_idx: int, condition_idx: int, expressions: Dictionary) -> void:
	"""Update an existing condition's parameters."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or event_idx >= sheet.events.size() or condition_idx >= sheet.events[event_idx].conditions.size():
		print("Invalid indices for condition update")
		return
	
	# Update the inputs
	sheet.events[event_idx].conditions[condition_idx].inputs = expressions
	_save_and_refresh(sheet, file_path)

func _create_standalone_condition_with_expressions(node_path: String, condition_id: String, expressions: Dictionary) -> void:
	"""Create a new standalone condition."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet:
		print("Failed to load event sheet")
		return
	
	# Create a new standalone condition
	var new_condition = FKEventCondition.new()
	new_condition.condition_id = condition_id
	new_condition.target_node = node_path
	new_condition.inputs = expressions
	var empty_actions: Array[FKEventAction] = []
	new_condition.actions = empty_actions
	
	# Create new standalone_conditions array with insertion
	var new_conditions: Array[FKEventCondition] = []
	var insert_at = pending_standalone_condition_index if pending_standalone_condition_index >= 0 else sheet.standalone_conditions.size()
	
	for i in range(sheet.standalone_conditions.size()):
		new_conditions.append(sheet.standalone_conditions[i])
		if i == insert_at - 1:
			new_conditions.append(new_condition)
	
	# If inserting at the end or in an empty list
	if insert_at >= sheet.standalone_conditions.size():
		new_conditions.append(new_condition)
	
	sheet.standalone_conditions = new_conditions
	_save_and_refresh(sheet, file_path)
	
	# Reset pending index
	pending_standalone_condition_index = -1

func _update_standalone_condition_with_expressions(condition_idx: int, expressions: Dictionary) -> void:
	"""Update an existing standalone condition's parameters."""
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	var sheet = _load_event_sheet(file_path)
	
	if not sheet or condition_idx >= sheet.standalone_conditions.size():
		print("Invalid index for standalone condition update")
		return
	
	# Update the inputs
	sheet.standalone_conditions[condition_idx].inputs = expressions
	_save_and_refresh(sheet, file_path)
	
		
