## A LineEdit that only allows numeric input.
## It validates text on change and reverts to the last valid input if invalid.
class_name NumericLineEdit
extends LineEdit

## If true, allows a single decimal point.
@export var allow_float: bool = true
## If true, allows a single leading minus sign.
@export var allow_negative: bool = true

# Store the last known valid text.
var _last_valid_text: String = ""
var _is_reverting: bool = false


func _ready() -> void:
	text_changed.connect(_on_text_changed)
	_last_valid_text = text
	focus_entered.connect(func(): _last_valid_text = text)


func _on_text_changed(new_text: String) -> void:
	if _is_reverting:
		return
	
	# An empty string or a single minus sign are valid intermediate states.
	if new_text.is_empty() or (allow_negative and new_text == "-"):
		_last_valid_text = new_text
		return

	# Use a regular expression to validate the input.
	var regex := RegEx.new()
	var pattern := "^"
	if allow_negative:
		pattern += "-?"

	pattern += "\\d*" # Zero or more digits.

	if allow_float:
		pattern += "(\\.\\d*)?" # Optional group: a literal dot followed by zero or more digits.

	pattern += "$"

	regex.compile(pattern)

	if regex.search(new_text):
		# The new text is valid, so we store it.
		_last_valid_text = new_text
	else:
		# The new text is invalid. Revert to the last valid text.
		# This prevents the user from typing illegal characters.
		var cursor_pos: int = get_caret_column()
		text = _last_valid_text
		set_caret_column(cursor_pos - 1)
