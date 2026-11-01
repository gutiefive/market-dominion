extends Node
class_name TableFeedback

## Place and market feedback. Tweens are skipped when reduced motion is on.
## The streams are synthesized so the project does not ship a binary sample.

@onready var _place: AudioStreamPlayer = $Place
@onready var _market: AudioStreamPlayer = $Market
@onready var _ui: AudioStreamPlayer = $Ui


func _ready() -> void:
	_place.stream = _tone(520.0, 0.09)
	_market.stream = _tone(340.0, 0.12)
	_ui.stream = _tone(680.0, 0.05)
	_place.volume_db = -14.0
	_market.volume_db = -16.0
	_ui.volume_db = -18.0


func placed(coordinate: String, board: BoardGrid) -> void:
	_place.play()
	if board != null:
		board.flash(coordinate)


func market_opened(dock: Control) -> void:
	_market.play()
	_pulse(dock)


func ui_tick() -> void:
	_ui.play()


func _pulse(target: Control) -> void:
	if target == null or Palette.reduced_motion:
		return
	var tween := target.create_tween()
	tween.tween_property(target, "modulate", Color(1.0, 1.08, 1.02), 0.08)
	tween.tween_property(target, "modulate", Color.WHITE, 0.18)


func _tone(freq: float, seconds: float) -> AudioStreamWAV:
	var rate := 22050
	var count := maxi(1, int(float(rate) * seconds))
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in count:
		var env := exp(-3.2 * float(index) / float(count))
		var sample := sin(TAU * freq * float(index) / float(rate)) * env
		var value := int(clamp(sample * 7000.0, -32767.0, 32767.0))
		data[index * 2] = value & 255
		data[index * 2 + 1] = (value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
