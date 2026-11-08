extends Node

const SAVE_PATH := "user://audio.cfg"
const RETRO_MUSIC := preload("res://assets/audio/retro/lost_rune.ogg")
const RETRO_EFFECTS := {
	&"Slash": preload("res://assets/audio/retro/slash.wav"),
	&"Dodge": preload("res://assets/audio/retro/dodge.wav"),
	&"Cast": preload("res://assets/audio/retro/cast.wav"),
	&"Hit": preload("res://assets/audio/retro/hit.wav"),
	&"Pickup": preload("res://assets/audio/retro/pickup.wav"),
	&"Heal": preload("res://assets/audio/retro/heal.wav"),
	&"Footstep": preload("res://assets/audio/retro/footstep.wav"),
	&"WolfAttack": preload("res://assets/audio/retro/wolf_attack.wav"),
	&"SpiderAttack": preload("res://assets/audio/retro/spider_attack.wav"),
	&"Switch": preload("res://assets/audio/retro/switch.wav"),
	&"Gate": preload("res://assets/audio/retro/gate.wav"),
	&"Victory": preload("res://assets/audio/retro/victory.wav"),
	&"Defeat": preload("res://assets/audio/retro/defeat.wav"),
}

@onready var music: AudioStreamPlayer = $Music
@onready var ambience: AudioStreamPlayer = $Ambience

var retro_music := true
var retro_effects := true
var standard_music: AudioStream
var standard_music_volume := 0.0
var standard_effects := {}


func _ready() -> void:
	standard_music = music.stream
	standard_music_volume = music.volume_db
	for cue in RETRO_EFFECTS:
		standard_effects[cue] = get_node(NodePath(cue)).stream
	var settings := ConfigFile.new()
	if settings.load(SAVE_PATH) == OK:
		retro_music = settings.get_value("audio", "retro_music", true) != false
		retro_effects = settings.get_value("audio", "retro_effects", true) != false
	_apply_music()
	_apply_effects()


func toggle_music() -> void:
	retro_music = not retro_music
	_apply_music()
	_save()


func toggle_effects() -> void:
	retro_effects = not retro_effects
	_apply_effects()
	_save()


func _apply_music() -> void:
	music.stop()
	music.stream = RETRO_MUSIC if retro_music else standard_music
	music.volume_db = -3.0 if retro_music else standard_music_volume
	music.play()
	music.stream_paused = get_tree().paused


func _apply_effects() -> void:
	for cue in RETRO_EFFECTS:
		var player: AudioStreamPlayer = get_node(NodePath(cue))
		player.stop()
		player.stream = RETRO_EFFECTS[cue] if retro_effects else standard_effects[cue]
	ambience.stop()
	if not retro_effects:
		ambience.play()
		ambience.stream_paused = get_tree().paused


func _save() -> void:
	var settings := ConfigFile.new()
	settings.set_value("audio", "retro_music", retro_music)
	settings.set_value("audio", "retro_effects", retro_effects)
	var error := settings.save(SAVE_PATH)
	if error != OK:
		push_warning("Unable to save audio settings: %s" % error_string(error))
