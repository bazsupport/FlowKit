@tool
extends MenuBar

signal new_sheet
signal save_sheet
signal generate_providers
signal generate_manifest

func _on_file_id_pressed(id: int) -> void:
	match id:
		0: # New Event Sheet
			emit_signal("new_sheet")
		1: # Save Event Sheet
			emit_signal("save_sheet")

func _on_edit_id_pressed(id: int) -> void:
	match id:
		0: # Generate Providers
			emit_signal("generate_providers")
		1: # Generate Manifest (for export)
			emit_signal("generate_manifest")
