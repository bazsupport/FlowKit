extends FKEvent

func get_id() -> String:
	return "on_test_event"

func get_name() -> String:
	return "On Test Event (from subdirectory)"

func get_supported_types() -> Array[String]:
	return ["Node"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	# This is a test event to verify subdirectory scanning works
	return false
