extends Node2D

# Offline frames sampled from Spine 3.6. Angela_Q motion drives the 130026 skin.
const FIGHTERS := [
	preload("res://assets/actors/angelica_motion.webp"),
	preload("res://assets/actors/angela_motion.webp"),
]
# SP27 spine_108_02, spine_109_02 and spine_152_03.
const MONSTERS := [
	preload("res://assets/actors/wolf_motion.webp"),
	preload("res://assets/actors/spider_motion.webp"),
	preload("res://assets/actors/elite_motion.webp"),
]
const FX := preload("res://scripts/combat/combat_fx.gd")
const MONSTER_CELL := Vector2(292, 260)
const MONSTER_ORIGIN := Vector2(110, 201)
const MONSTER_IDLE_FRAMES := 24
const MONSTER_ATTACK_FRAMES := 20
const MONSTER_STRIKE_PHASES := [0.36, 0.38, 0.48]
const MAP_ACTOR_SCALE := 2.15
const FIGHTER_SCALE := MAP_ACTOR_SCALE * 0.302
const CULTIVATION_FIGHTERS := [
	preload("res://assets/actors/cultivation_swordsman.png"),
	preload("res://assets/actors/cultivation_mage.png"),
]
const DIRECTIONAL_WALK := [
	preload("res://assets/actors/swordsman_walk.png"),
	preload("res://assets/actors/mage_walk.png"),
]
const DIRECTIONAL_ATTACK := [
	preload("res://assets/actors/swordsman_attack.png"),
	preload("res://assets/actors/mage_cast.png"),
]
# ImageGen, based on the supplied directional character sprites. Columns are
# windup, release and follow-through for stage two, then the same for stage three.
const DIRECTIONAL_COMBO := [
	preload("res://assets/actors/swordsman_combo.png"),
	preload("res://assets/actors/mage_combo.png"),
]
# ImageGen guard and deflect poses, aligned to the directional attack atlas.
const SWORD_GUARD := preload("res://assets/actors/swordsman_guard.png")
const DIRECTIONAL_FRAMES := 6
const FRAME_SIZE := Vector2(300, 234)
const FRAME_ORIGIN := Vector2(150, 195)
const ATLAS_COLUMNS := 8
const IDLE := Vector2i(0, 32)
const RUN := Vector2i(32, 16)
const ATTACK := Vector2i(48, 12)
const CAST := Vector2i(60, 14)
const HIT := Vector2i(74, 10)
const DASH := Vector2i(84, 8)
const HIT_DURATION := 0.23

var fighter_style := 0
var cultivation_skin := true
var walk_progress := 0.0
var walk_side := 1.0
var stride_time := 0.0
var dash_time := 0.0
var hit_time := 0.0
var effect_duration := 0.21
var windup_duration := 1.0
var windup_elapsed := 0.0

var kind := 0
var vitals: Node
var facing := Vector2.RIGHT
var moving := false
var dodging := false
var dormant := false
var charging := false
var warning_radius := 0.0
var poison_path := Vector2.ZERO
var phase := 0.0
var effect := 0
var effect_time := 0.0
var effect_origin := Vector2.ZERO
var effect_direction := Vector2.RIGHT
var effect_side := 1.0
var spell_color := Color.WHITE
var attack_charge := 0.0
var attack_charge_flash := 0.0
var combo_pose_time := 0.0
var combo_windup := 0.0
var combo_stage := -1
var combo_hold := 0.0
var guard_time := 0.0
var guard_direction := Vector2.RIGHT
var guard_success := false
var attack_layer := Node2D.new()


func _ready() -> void:
	attack_layer.z_index = 2
	attack_layer.draw.connect(_draw_attack_effect)
	add_child(attack_layer)
	var flash := Animation.new()
	flash.length = HIT_DURATION
	var track := flash.add_track(Animation.TYPE_VALUE)
	flash.track_set_path(track, NodePath(".:modulate"))
	flash.track_insert_key(track, 0.0, Color(1.7, 1.4, 1.22))
	flash.track_insert_key(track, 0.045, Color("#ff7958"))
	flash.track_insert_key(track, 0.11, Color("#ffe0a3"))
	flash.track_insert_key(track, HIT_DURATION, Color.WHITE)
	var library := AnimationLibrary.new()
	library.add_animation("hurt", flash)
	$AnimationPlayer.add_animation_library("", library)


func set_cultivation_skin(enabled: bool) -> void:
	cultivation_skin = enabled
	queue_redraw()


func pose(direction: Vector2, walking: bool, rolling := false) -> void:
	facing = direction
	moving = walking
	if absf(direction.x) > 0.15:
		walk_side = signf(direction.x)
	if rolling and not dodging:
		dash_time = 0.0
		effect_time = 0.0
		attack_layer.queue_redraw()
	dodging = rolling


func begin_combo_pose(stage: int, direction: Vector2, windup: float) -> void:
	combo_stage = stage
	combo_pose_time = windup
	combo_windup = windup
	effect_direction = direction
	effect_time = 0.0
	attack_layer.queue_redraw()


func clear_combo_pose() -> void:
	if combo_stage >= 0:
		combo_stage = -1
		combo_pose_time = 0.0
		combo_hold = 0.0
		effect_time = 0.0
		attack_layer.queue_redraw()


func pulse(style: int, color := Color.WHITE, stage := -1) -> void:
	combo_stage = stage
	combo_pose_time = 0.0
	effect = style
	spell_color = color
	effect_origin = global_position
	effect_direction = facing
	effect_side = signf(facing.x) if absf(facing.x) > 0.15 else walk_side
	effect_duration = 0.36
	if kind == 0:
		effect_duration = 0.32 if style == 1 else 0.42
	if stage >= 0:
		effect_duration = 0.31 if stage == 2 else 0.21
	effect_time = effect_duration
	attack_layer.queue_redraw()


func show_guard(direction: Vector2, duration: float, success: bool) -> void:
	guard_direction = direction
	guard_time = duration
	guard_success = success
	effect_time = 0.0
	attack_layer.queue_redraw()


func clear_attack_charge() -> void:
	attack_charge = 0.0
	attack_charge_flash = 0.0
	queue_redraw()


func begin_windup(duration: float) -> void:
	windup_duration = duration
	windup_elapsed = 0.0


func flinch() -> void:
	hit_time = HIT_DURATION
	if kind == 0:
		effect_time = 0.0
		attack_layer.queue_redraw()


func _process(delta: float) -> void:
	phase += delta
	guard_time = maxf(0.0, guard_time - delta)
	attack_charge_flash = maxf(0.0, attack_charge_flash - delta)
	stride_time = stride_time + delta if moving else 0.0
	combo_pose_time = maxf(0.0, combo_pose_time - delta)
	if combo_hold > 0.0:
		combo_hold = maxf(0.0, combo_hold - delta)
	elif effect_time > 0.0:
		effect_time = maxf(0.0, effect_time - delta)
		attack_layer.queue_redraw()
	hit_time = maxf(0.0, hit_time - delta)
	dash_time += delta
	windup_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if charging:
		_draw_warning(clampf(windup_elapsed / windup_duration, 0.0, 1.0))
	draw_set_transform(Vector2(0, 5), 0, Vector2(1, 0.48) * MAP_ACTOR_SCALE)
	draw_circle(Vector2.ZERO, 23 if kind == 3 else 18, Color("#0b211dc0"))
	draw_set_transform(Vector2.ZERO)
	var side := -1.0 if facing.x < -0.15 else 1.0
	if kind == 0:
		if effect_time > 0.0:
			side = effect_side
		elif cultivation_skin:
			side = walk_side
		_draw_fighter(side)
	else:
		_draw_monster(side)
	draw_set_transform(Vector2.ZERO)
	if kind == 0 and attack_charge >= 0.15:
		_draw_attack_charge()
	if kind > 0 and is_instance_valid(vitals):
		var width := 62.0 if kind == 3 else 40.0
		var y := -118.0 if kind == 3 else -84.0
		draw_rect(Rect2(-width / 2, y, width, 5), Color("#172622"))
		draw_rect(Rect2(-width / 2, y, width * vitals.hp / vitals.max_hp, 5), Color("#e9915c"))
	if charging and kind == 2:
		var charge := clampf(windup_elapsed / windup_duration, 0.0, 1.0)
		var center := Vector2(0, -18) + facing * 25.0
		var size := lerpf(36.0, 66.0, charge)
		FX.draw_frame(self, FX.Clip.POISON, charge, Rect2(center - Vector2.ONE * size * 0.5,
			Vector2.ONE * size), Color(1, 1, 1, 0.65 + charge * 0.35))


func _draw_attack_charge() -> void:
	var full := attack_charge >= 1.0
	var tint := Color("#ffe399") if full else Color("#80ffda")
	if fighter_style == 1:
		tint = Color("#b6f4ff")
		var focus := Vector2(0, -32) + facing * lerpf(12.0, 33.0, attack_charge)
		var width := lerpf(6.0, 1.6, attack_charge)
		draw_line(focus, focus + facing * (18.0 + attack_charge * 53.0),
			Color(tint, 0.68), width, true)
		draw_circle(focus, 3.0 + 5.0 * attack_charge, tint, true, -1.0, true)
		return
	var center := Vector2(0, -32)
	var radius := lerpf(41.0, 32.0, attack_charge)
	draw_arc(center, radius, 0, TAU, 40, Color("#19392dbe"), 4.0, true)
	draw_arc(center, radius, -PI / 2.0, attack_charge * TAU - PI / 2.0, 40, tint, 3.0, true)
	for index in range(4):
		var offset := Vector2.from_angle(phase * 8.0 + index * PI / 2.0) * radius
		draw_circle(center + offset, 2.8 if full else 1.7, tint)
	if attack_charge_flash > 0.0:
		var fade := attack_charge_flash / 0.30
		draw_arc(center, radius + 30.0 * (1.0 - fade), 0, TAU, 48,
			Color(tint, fade), 6.0 * fade, true)
		draw_circle(center, 26.0, Color(tint, fade * 0.36))


func _draw_warning(charge: float) -> void:
	if kind == 2:
		draw_line(Vector2.ZERO, poison_path, Color("#142815dd"), 16.0)
		draw_line(Vector2.ZERO, poison_path, Color("#a6f353ac"), 10.0)
		draw_line(Vector2.ZERO, poison_path * charge, Color("#ebffb0"), 4.0)
		return
	if warning_radius > 0.0:
		draw_circle(Vector2.ZERO, warning_radius, Color("#e0342460"))
		draw_circle(Vector2.ZERO, warning_radius * charge, Color("#ff773862"))
		draw_arc(Vector2.ZERO, warning_radius, 0, TAU, 48, Color("#632619"), 7.0, true)
		draw_arc(Vector2.ZERO, warning_radius, 0, TAU, 48, Color("#ff9755"), 3.0, true)
		draw_arc(Vector2.ZERO, warning_radius, -PI / 2.0, TAU * charge - PI / 2.0, 48,
			Color("#fff0b0"), 3.0, true)


func _draw_monster(side: float) -> void:
	var progress := fposmod(phase * (1.6 if moving else 1.0), 2.67) / 2.67
	var frame := int(progress * MONSTER_IDLE_FRAMES)
	if charging or effect_time > 0.0:
		var strike_phase: float = MONSTER_STRIKE_PHASES[kind - 1]
		if charging:
			progress = strike_phase * clampf(windup_elapsed / windup_duration, 0.0, 1.0)
		else:
			progress = lerpf(strike_phase, 1.0, 1.0 - effect_time / effect_duration)
		frame = MONSTER_IDLE_FRAMES + mini(int(progress * MONSTER_ATTACK_FRAMES),
			MONSTER_ATTACK_FRAMES - 1)
	var row := floori(float(frame) / ATLAS_COLUMNS)
	var source := Rect2(Vector2(frame % ATLAS_COLUMNS, row) * MONSTER_CELL, MONSTER_CELL)
	var atlas: Texture2D = MONSTERS[kind - 1]
	var bob := -absf(sin(stride_time * 19.0)) * 4.0 if moving else 0.0
	var lean := sin(stride_time * 19.0) * 0.038 * side if moving else 0.0
	var tint := Color("#9caaa4") if dormant else Color.WHITE
	draw_set_transform(Vector2(0, bob), lean, Vector2(side, 1.0) * FIGHTER_SCALE)
	draw_texture_rect_region(atlas, Rect2(-MONSTER_ORIGIN, MONSTER_CELL), source, tint)


func _fighter_frame() -> int:
	var clip := IDLE
	var progress := fposmod(phase, 2.67) / 2.67
	if dodging:
		clip = DASH
		progress = dash_time / 0.16
	elif hit_time > 0.0:
		clip = HIT
		progress = 1.0 - hit_time / HIT_DURATION
	elif effect_time > 0.0:
		clip = ATTACK if effect in [1, 4] else CAST
		progress = 1.0 - effect_time / effect_duration
	elif moving:
		clip = RUN
		progress = fposmod(stride_time, 0.67) / 0.67
	return clip.x + clampi(int(progress * clip.y), 0, clip.y - 1)


func _directional_row(direction: Vector2) -> int:
	# Rows start at south and advance toward east, then north and west.
	return posmod(roundi(atan2(direction.x, direction.y) / (TAU / 8.0)), 8)


func _draw_directional_fighter() -> void:
	var atlas: Texture2D = DIRECTIONAL_ATTACK[fighter_style]
	var direction := facing
	var column := 0
	var lean := Vector2.ZERO
	if guard_time > 0.0:
		direction = guard_direction
		atlas = SWORD_GUARD
		column = 1 if guard_success else 0
	elif combo_pose_time > 0.0:
		direction = effect_direction
		var anticipation := 1.0 - combo_pose_time / combo_windup
		column = 1 if anticipation >= 0.18 else 0
		if combo_stage > 0 and anticipation >= 0.18:
			atlas = DIRECTIONAL_COMBO[fighter_style]
			column = (combo_stage - 1) * 3
		var pullback := [2.0, 5.0, 9.0]
		lean = -direction * sin(anticipation * PI / 2.0) * pullback[combo_stage]
	elif effect_time > 0.0:
		direction = effect_direction
		var duration := 0.32 if fighter_style == 1 and combo_stage < 0 else effect_duration
		var progress := (effect_duration - effect_time) / duration
		# The third frame is the impact or release pose.
		column = 2 + clampi(int(progress * 4), 0, 3)
		if combo_stage >= 0:
			var follow_through := [3.0, 6.0, 11.0]
			lean = direction * follow_through[combo_stage] * (1.0 - smoothstep(0.0, 0.8, progress))
			if combo_stage > 0:
				if progress < 0.82:
					atlas = DIRECTIONAL_COMBO[fighter_style]
					column = (combo_stage - 1) * 3 + (1 if progress < 0.36 else 2)
				else:
					column = 0
	elif moving:
		atlas = DIRECTIONAL_WALK[fighter_style]
		column = clampi(int(walk_progress * DIRECTIONAL_FRAMES), 0, DIRECTIONAL_FRAMES - 1)
	elif attack_charge >= 0.15:
		column = 1
	var source := Rect2(Vector2(column, _directional_row(direction)) * FRAME_SIZE, FRAME_SIZE)
	draw_set_transform(lean, 0.0, Vector2.ONE * FIGHTER_SCALE)
	draw_texture_rect_region(atlas, Rect2(-FRAME_ORIGIN, FRAME_SIZE), source)


func _draw_fighter(side: float) -> void:
	if cultivation_skin and not dodging and hit_time <= 0.0:
		_draw_directional_fighter()
		return
	var frame := _fighter_frame()
	var row := floori(float(frame) / ATLAS_COLUMNS)
	var source := Rect2(Vector2(frame % ATLAS_COLUMNS, row) * FRAME_SIZE, FRAME_SIZE)
	var bounds := Rect2(-FRAME_ORIGIN, FRAME_SIZE)
	var atlases := CULTIVATION_FIGHTERS if cultivation_skin else FIGHTERS
	var atlas: Texture2D = atlases[fighter_style]
	var sprite_scale := Vector2(side, 1.0) * FIGHTER_SCALE
	var tilt := 0.21 * side if dodging and fighter_style == 1 else 0.0
	if dodging:
		var trail := Color(0.8, 0.58, 1.0, 0.27)
		draw_set_transform(-facing * 24.0, tilt, sprite_scale)
		draw_texture_rect_region(atlas, bounds, source, trail)
	draw_set_transform(Vector2.ZERO, tilt, sprite_scale)
	draw_texture_rect_region(atlas, bounds, source)


func _draw_attack_effect() -> void:
	if effect_time <= 0.0:
		return
	var progress := 1.0 - effect_time / effect_duration
	var tint := Color(1, 1, 1, 1.0 - smoothstep(0.48, 1.0, progress))
	var angle := effect_direction.angle()
	match kind:
		0:
			if effect == 1:
				_draw_sword_arc(progress, angle)
			elif effect == 4:
				var radius := lerpf(27.0, 74.0, smoothstep(0.0, 0.62, progress))
				var origin := Vector2(0, -12)
				attack_layer.draw_arc(origin, radius, 0, TAU, 48,
					Color("#e8ad54").lerp(spell_color, 0.55 if spell_color != Color.WHITE else 0.0) * tint, 9.0, true)
				attack_layer.draw_arc(origin, radius, 0, TAU, 48,
					Color("#fff4c2") * tint, 3.0, true)
				for index in range(4):
					attack_layer.draw_set_transform(origin, angle + index * TAU / 4.0)
					FX.draw_frame(attack_layer, FX.Clip.SWORD, progress,
						Rect2(-7, -64, 134, 128), tint)
			elif fighter_style == 1 and combo_stage >= 0 and cultivation_skin:
				_draw_combo_spell(progress, angle)
			elif fighter_style == 1:
				var size := 184.0 if effect == 3 else 124.0
				var center := Vector2(0, -37) + effect_direction * (16.0 if effect != 3 else 0.0)
				FX.draw_frame(attack_layer, FX.Clip.MAGIC, progress,
					Rect2(center - Vector2.ONE * size / 2.0, Vector2.ONE * size), tint)
				if cultivation_skin:
					var radius := lerpf(12.0, size * 0.32, progress)
					attack_layer.draw_arc(center, radius, angle, angle + TAU, 36,
						spell_color * tint, 2.0, true)
			elif effect == 3:
				for index in range(4):
					attack_layer.draw_set_transform(Vector2(0, -22), angle + index * TAU / 4.0)
					FX.draw_frame(attack_layer, FX.Clip.SWORD, progress, Rect2(4, -68, 136, 136), tint)
			else:
				attack_layer.draw_set_transform(Vector2(0, -22), angle)
				FX.draw_frame(attack_layer, FX.Clip.SWORD, progress, Rect2(-17, -82, 164, 164), tint)
		1:
			attack_layer.draw_set_transform(Vector2(0, -21), angle)
			FX.draw_frame(attack_layer, FX.Clip.CLAW, progress, Rect2(-8, -63, 126, 126), tint)
		3:
			attack_layer.draw_set_transform(Vector2(0, -28), angle)
			FX.draw_frame(attack_layer, FX.Clip.FLAME_CLAW, progress, Rect2(3, -92, 184, 184), tint)


func _draw_sword_arc(progress: float, angle: float) -> void:
	# The hit resolves on release. Show the forward edge immediately, then sweep
	# through the follow-through and leave the trail at the strike position.
	var alpha := 1.0 - smoothstep(0.18, 0.68, progress)
	if alpha <= 0.0:
		return
	var sweep := smoothstep(0.0, 0.32, progress)
	var head := lerpf(0.35, 1.66, sweep)
	var tail := lerpf(-1.45, -0.73, smoothstep(0.16, 0.68, progress))
	var origin := attack_layer.to_local(effect_origin) + Vector2(0.0, -27.0)
	var reach_scale := 1.0
	var thickness := 23.0
	var glow := Color("#49cf9b")
	match combo_stage:
		0:
			head *= 0.56
			tail *= 0.56
			thickness = 15.0
		1:
			var old_head := head
			head = -tail * 1.15
			tail = -old_head * 1.15
			glow = Color("#9cbfff")
		2:
			head *= 0.51
			tail *= 0.51
			reach_scale = 1.28
			thickness = 32.0
			glow = Color("#ffca78") if spell_color == Color.WHITE else spell_color
	attack_layer.draw_set_transform(origin, angle)

	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var colors := PackedColorArray()
	const SEGMENTS := 18
	for index in range(SEGMENTS + 1):
		var t := float(index) / SEGMENTS
		var direction := Vector2.from_angle(lerpf(tail, head, t))
		var profile := sin(t * PI)
		var radius := (67.0 + 11.0 * profile) * reach_scale
		outer.append(direction * radius)
		inner.append(direction * (radius - 1.0 - thickness * profile))
		colors.append(Color(0.76, 1.0, 0.89, alpha))
	inner.reverse()
	for index in range(SEGMENTS + 1):
		colors.append(Color(glow, alpha * 0.53))
	attack_layer.draw_polygon(outer + inner, colors)
	attack_layer.draw_polyline(outer, Color(0.96, 1.0, 0.93, alpha), 2.5, true)



func _draw_combo_spell(progress: float, angle: float) -> void:
	var fade := 1.0 - smoothstep(0.2, 0.9, progress)
	var origin := attack_layer.to_local(effect_origin) + Vector2(0, -32)
	attack_layer.draw_set_transform(origin, angle)
	match combo_stage:
		0:
			attack_layer.draw_circle(Vector2(20, 0), lerpf(9.0, 3.0, progress),
				Color(spell_color, fade), true, -1.0, true)
		1:
			for side in [-1, 1]:
				var center := Vector2(22, side * lerpf(10.0, 29.0, progress))
				attack_layer.draw_arc(center, lerpf(8.0, 19.0, progress), -1.2, 1.2, 16,
					Color(spell_color, fade), 2.5, true)
		2:
			var center := Vector2(20, 0)
			var radius := lerpf(12.0, 43.0, progress)
			attack_layer.draw_arc(center, radius, 0.0, TAU, 40, Color(spell_color, fade), 3.0, true)
			attack_layer.draw_arc(center, radius * 0.75, PI / 4.0, TAU + PI / 4.0, 4,
				Color("#fff3cb", fade), 2.0, true)
