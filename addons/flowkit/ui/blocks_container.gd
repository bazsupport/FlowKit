@tool
extends VBoxContainer

signal block_moved

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("node"):
		return false
	
	var node = data["node"]
	return is_instance_valid(node) and node.get_parent() == self

func _drop_data(at_position: Vector2, data) -> void:
	if not data is Dictionary or not data.has("node"):
		return
	
	var node = data["node"]
	if not is_instance_valid(node) or node.get_parent() != self:
		return
	
	# Get block and its children (for group move)
	var blocks_to_move = _get_block_with_children(node)
	var first_idx = blocks_to_move[0].get_index()
	var last_idx = first_idx + blocks_to_move.size() - 1
	var target_idx = _calculate_drop_index(at_position)
	
	# If target is within our group (would split parent from children), no-op
	if target_idx >= first_idx and target_idx <= last_idx + 1:
		return
	
	# Adjust target if moving down (indices shift after removal)
	if target_idx > last_idx:
		target_idx -= blocks_to_move.size()
	
	# Remove all blocks, then re-add at target position
	for block in blocks_to_move:
		remove_child(block)
	
	for i in range(blocks_to_move.size()):
		add_child(blocks_to_move[i])
		move_child(blocks_to_move[i], target_idx + i)
	
	block_moved.emit()

func _get_block_with_children(block) -> Array:
	"""Get block and all its children in order."""
	var result = [block]
	var block_idx = block.get_index()
	
	# Events: collect everything until next event
	if block.has_method("get_event_data"):
		for i in range(block_idx + 1, get_child_count()):
			var child = get_child(i)
			if not child.visible or child.name == "EmptyLabel":
				continue
			if child.has_method("get_event_data"):
				break
			result.append(child)
		return result
	
	# Conditions: collect actions until next condition/event
	if block.has_method("get_condition_data"):
		for i in range(block_idx + 1, get_child_count()):
			var child = get_child(i)
			if not child.visible or child.name == "EmptyLabel":
				continue
			if child.has_method("get_event_data") or child.has_method("get_condition_data"):
				break
			result.append(child)
		return result
	
	# Actions have no children
	return result

func _calculate_drop_index(at_position: Vector2) -> int:
	for i in range(get_child_count()):
		var child = get_child(i)
		if not child.visible or child.name == "EmptyLabel":
			continue
		
		var rect = child.get_rect()
		if at_position.y < rect.position.y + rect.size.y * 0.5:
			return i
	
	return get_child_count()
