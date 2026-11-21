extends Node2D
## 25 articulated joints, including independent wrists and a stable prop socket.

var character_id: int = 0
var action: String = "idle"
var debug_bones: bool = false
var facing: float = 1.0
var target_x: float = 0.0
var move_enabled: bool = false
var elapsed: float = 0.0
var travelled: float = 0.0
var speed: float = 42.0
var velocity: float = 0.0
var walk_weight: float = 0.0
var hand_positions: Dictionary = {}
const STRIDE: float = 24.0
const ACCELERATION: float = 100.0
var hand_target: Vector2 = Vector2(18, -33)
var skeleton: Skeleton2D
var bones: Dictionary = {}
var limb_meshes: Array = []
var prop: Polygon2D
var reached: bool = false
var debug_layer: Node2D
var pixel_canvas: SubViewport
var model_root: Node2D
signal arrived
signal footstep

func _draw() -> void:
	draw_set_transform(Vector2(1,0),0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,10,Color(0.02,0.04,0.04,0.24))
	draw_set_transform(Vector2.ZERO)

const PALETTES = [
	["405b5e", "283438", "25282d", "d5ab83", "252930", "b59044"],
	["46484b", "303236", "303033", "c7a283", "bac0bc", "b59044"],
	["854737", "4e3839", "292b31", "cfa785", "542e3d", "d5c9ad"],
	["3e594d", "2b3f39", "29302e", "c7a283", "8b9090", "c9c7b2"],
	["9d7439", "675333", "353535", "c3a17a", "434346", "90938b"],
	["444850", "30353e", "272d34", "cfa785", "27272d", "a39769"],
	["665168", "493e53", "37323e", "c39b7e", "302a30", "a28a44"],
	["647a8b", "455565", "303c50", "cfa785", "2e2b2e", "aab7b8"],
	["a06837", "68472f", "354349", "c3a17a", "3b3d3d", "dbd4b7"],
	["635166", "453746", "4c4141", "c9ac8d", "ccc9bb", "97615c"],
	["677048", "484f38", "353b34", "cba580", "292b2b", "b2964b"],
	["c0bcb0", "8f918b", "514640", "cba580", "292b2b", "824740"]
]

func _ready() -> void:
	pixel_canvas=SubViewport.new();pixel_canvas.size=Vector2i(80,80);pixel_canvas.transparent_bg=true
	pixel_canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	pixel_canvas.disable_3d=true;add_child(pixel_canvas)
	model_root=Node2D.new();model_root.position=Vector2(40,65);pixel_canvas.add_child(model_root)
	skeleton = Skeleton2D.new()
	model_root.add_child(skeleton)
	build()
	preload("res://scripts/rig_skin.gd").apply(self)
	var display:=Sprite2D.new();display.texture=pixel_canvas.get_texture();display.centered=false
	display.position=Vector2(-40,-65);display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;add_child(display)
	debug_layer = Node2D.new()
	debug_layer.z_index = 20
	model_root.add_child(debug_layer)
	debug_layer.draw.connect(draw_debug)
	pose(0.0)

func bone(key: String, parent_key: String, offset: Vector2, length: float) -> Bone2D:
	var b := Bone2D.new()
	b.name = key
	b.position = offset
	b.set_autocalculate_length_and_angle(false)
	b.length = length
	b.bone_angle = 0.0
	b.rest = Transform2D(0, offset)
	if parent_key.is_empty():
		skeleton.add_child(b)
	else:
		bones[parent_key].add_child(b)
	bones[key] = b
	return b

func polygon(parent: Node2D, points: Array, color: Color, z: int = 0) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	p.z_index = z
	parent.add_child(p)
	return p

func segment(key: String, length: float, width: float, color: Color, z: int) -> void:
	polygon(bones[key], [Vector2(-1,-width/2), Vector2(length-1,-width/2), Vector2(length+1,-width/2+1), Vector2(length+1,width/2-1), Vector2(length-1,width/2), Vector2(-1,width/2)], color, z)

func build() -> void:
	var pal: Array = PALETTES[character_id]
	var coat := Color(pal[0])
	var shadow := Color(pal[1])
	var pants := Color(pal[2])
	var skin := Color(pal[3])
	var hair := Color(pal[4])
	var accent := Color(pal[5])
	bone("root", "", Vector2.ZERO, 1)
	bone("pelvis", "root", Vector2(0,-25), 7)
	bone("waist", "pelvis", Vector2(0,-5), 7)
	bone("chest", "waist", Vector2(0,-7), 8)
	bone("neck", "chest", Vector2(0,-4.5), 3)
	bone("head", "neck", Vector2(0,-1.5), 10)
	for side in ["back", "front"]:
		var front: bool = side == "front"
		var z: int = 2 if front else -2
		bone(side+"_clavicle", "chest", Vector2(1 if front else -3,-3), 3)
		bone(side+"_upperarm", side+"_clavicle", Vector2(1,1), 11)
		bone(side+"_forearm", side+"_upperarm", Vector2(11,0), 10)
		bone(side+"_wrist", side+"_forearm", Vector2(10,0), 1)
		bone(side+"_hand", side+"_wrist", Vector2.ZERO, 3)
		bone(side+"_thigh", "pelvis", Vector2(-1.8 if front else 1.8,1), 13)
		bone(side+"_shin", side+"_thigh", Vector2(13,0), 12)
		bone(side+"_foot", side+"_shin", Vector2(12,0), 6)
		bone(side+"_toe", side+"_foot", Vector2(4,0), 2)
		segment(side+"_upperarm",11,6,coat if front else shadow,z)
		segment(side+"_forearm",10,4,skin if character_id in [7,8] else coat,z)
		segment(side+"_hand",3,4,accent if character_id == 8 and front else skin,z+1)
		segment(side+"_thigh",13,6,pants if front else pants.darkened(0.2),z)
		segment(side+"_shin",12,5,pants if front else pants.darkened(0.2),z)
		polygon(bones[side+"_foot"], [Vector2(-2,-2),Vector2(4,-2),Vector2(6,0),Vector2(6,2),Vector2(-2,2)], Color("20242a"),z)
		polygon(bones[side+"_toe"], [Vector2(0,-1),Vector2(2,0),Vector2(2,2),Vector2(0,2)],Color("20242a"),z)
	bone("prop_socket", "front_hand", Vector2(1,0), 3)
	polygon(bones.chest, [Vector2(-6,-5),Vector2(4,-5),Vector2(7,0),Vector2(6,14),Vector2(-7,14),Vector2(-8,2)],coat)
	polygon(bones.chest, [Vector2(-6,-4),Vector2(-2,-4),Vector2(-2,13),Vector2(-7,13)],shadow)
	polygon(bones.neck,[Vector2(-1.6,-2.5),Vector2(1.8,-2.5),Vector2(2,2.5),Vector2(-1.4,2.5)],skin,-1)
	polygon(bones.head,[Vector2(-5,-10),Vector2(4,-10),Vector2(5,-6),Vector2(7,-5),Vector2(7,-2),Vector2(4,-2),Vector2(3,2),Vector2(-4,2)],skin)
	polygon(bones.head,[Vector2(-6,-11),Vector2(2,-12),Vector2(5,-9),Vector2(4,-6),Vector2(0,-7),Vector2(-2,-4),Vector2(-5,-3),Vector2(-6,-5)],hair,1)
	polygon(bones.head,[Vector2(3,-6),Vector2(4,-6),Vector2(4,-4),Vector2(3,-4)],Color("24252a"),2)
	if character_id in [0,1]:
		polygon(bones.head,[Vector2(-1,-11),Vector2(1,-11),Vector2(1,-8),Vector2(-1,-8)],Color("b7b8b2"),2)
	if character_id in [2,6,9]:
		polygon(bones.head,[Vector2(-7,-9),Vector2(-4,-9),Vector2(-3,2),Vector2(-7,1)],hair,1)
	if character_id == 8:
		polygon(bones.head,[Vector2(-7,-12),Vector2(4,-12),Vector2(5,-9),Vector2(8,-9),Vector2(8,-7),Vector2(-7,-7)],Color("55564e"),3)
	if character_id in [1,3,9]:
		polygon(bones.chest,[Vector2(-7,9),Vector2(6,9),Vector2(8,22),Vector2(-8,22)],coat,1)
	if character_id in [6,9]:
		polygon(bones.chest,[Vector2(-6,-5),Vector2(4,-5),Vector2(11,11),Vector2(-11,12)],coat,1)
	if character_id in [0,2,5,10,11]:
		prop = polygon(bones.front_hand,[Vector2(-3,-5),Vector2(5,-5),Vector2(5,5),Vector2(-3,5)],accent,4)
	if character_id == 6:
		prop = polygon(bones.front_hand,[Vector2(-3,0),Vector2(4,0),Vector2(5,10),Vector2(-4,10)],accent,4)
	if character_id in [1,9]:
		prop = polygon(bones.front_hand,[Vector2(0,-1),Vector2(2,-1),Vector2(2,23),Vector2(0,23)],accent,4)

func walk_to(x: float) -> void:
	target_x = x
	move_enabled = true
	reached = false
	action = "walk"
	if absf(velocity)<.1 and absf(x-position.x)>.1: facing=signf(x-position.x)

func _process(delta: float) -> void:
	elapsed += delta
	if move_enabled:
		var before: float = position.x
		var old_contact: int=int(floor(travelled/(STRIDE*.5)))
		var unit_scale: float=maxf(absf(scale.x),.01)
		var distance: float=absf(target_x-position.x)/unit_scale
		var direction: float=signf(target_x-position.x)
		var desired_speed: float=minf(speed,sqrt(2.0*ACCELERATION*distance))
		if direction!=facing and absf(velocity)>1: desired_speed=0
		elif direction!=0: facing=direction
		velocity=move_toward(velocity,desired_speed,ACCELERATION*delta)
		if direction==facing: position.x=move_toward(position.x,target_x,velocity*unit_scale*delta)
		travelled += absf(position.x-before)/unit_scale
		if int(floor(travelled/(STRIDE*.5)))>old_contact: footstep.emit()
		if is_equal_approx(position.x,target_x):
			move_enabled = false
			velocity=0
			action = "idle"
			reached = true
			arrived.emit()
	elif action == "walk":
		travelled += speed * delta
		velocity=speed
	else: velocity=move_toward(velocity,0,ACCELERATION*delta)
	pose(delta)
	debug_layer.queue_redraw()

func solve_ik(upper: String, lower: String, target: Vector2, a: float, b: float, bend: float) -> void:
	var first: Bone2D = bones[upper]
	var local_target: Vector2 = first.get_parent().to_local(skeleton.to_global(target)) - first.position
	var d: float = clampf(local_target.length(),absf(a-b)+0.01,a+b-0.01)
	var base: float = local_target.angle()
	var c: float = clampf((a*a+d*d-b*b)/(2*a*d),-1,1)
	first.rotation = base + bend * acos(c)
	var e: float = clampf((a*a+b*b-d*d)/(2*a*b),-1,1)
	bones[lower].rotation = -bend * (PI-acos(e))

func foot_cycle(phase: float) -> Vector2:
	# Contact phase is exactly the inverse of body displacement.
	if phase < 0.6:
		return Vector2(7.2-STRIDE*phase,-2)
	var u: float = (phase-0.6)/0.4
	# Hermite endpoints match contact velocity; lift has zero endpoint velocity.
	return Vector2(-7.2-9.6*u+72*u*u-48*u*u*u,-2-3.2*pow(sin(u*PI),2))

func pose(delta: float) -> void:
	if bones.is_empty(): return
	skeleton.scale.x = facing
	var moving: bool = action == "walk"
	var desired_weight: float=1.0 if moving else 0.0
	walk_weight=desired_weight if delta<=0 else move_toward(walk_weight,desired_weight,delta*5.0)
	var phase: float = fposmod(travelled/STRIDE,1.0)
	var breathing: float = sin(elapsed*1.8)*.10
	# Raise the pelvis as far as both leg chains allow. This avoids the old
	# permanent crouch while keeping every stance target within reach.
	var pelvis_y: float=-27.85
	for side in ["front","back"]:
		var front: bool=side=="front"
		var target: Vector2=Vector2(-2.8 if front else 3.2,-2).lerp(foot_cycle(fposmod(phase+(0.0 if front else .5),1)),walk_weight)
		var dx: float=target.x-bones[side+"_thigh"].position.x
		pelvis_y=maxf(pelvis_y,target.y-sqrt(maxf(0,24.9*24.9-dx*dx))-1)
	bones.pelvis.position=Vector2(0,pelvis_y)
	bones.waist.rotation=lerpf(breathing*.015,.012*sin(phase*TAU),walk_weight)
	bones.chest.rotation=-bones.waist.rotation*.65
	bones.neck.rotation=-bones.waist.rotation-bones.chest.rotation
	# At this resolution sub-pixel head rotation makes one-pixel eyes flicker.
	bones.head.rotation=0
	for side in ["back","front"]:
		var front: bool = side == "front"
		var side_phase: float=fposmod(phase+(0.0 if front else .5),1)
		var idle_foot:=Vector2(-2.8 if front else 3.2,-2)
		var cycle: Vector2=foot_cycle(side_phase)
		var foot: Vector2=idle_foot.lerp(cycle,walk_weight)
		solve_ik(side+"_thigh",side+"_shin",foot,13,12,-1)
		var ankle: Bone2D=bones[side+"_foot"]
		ankle.rotation=-bones[side+"_shin"].rotation-bones[side+"_thigh"].rotation
		if side_phase>.6: ankle.rotation-=.10*sin((side_phase-.6)/.4*PI)*walk_weight
		bones[side+"_toe"].rotation=0
		var shoulder: Vector2=skeleton.to_local(bones[side+"_upperarm"].global_position)
		var resting_hand: Vector2=shoulder+Vector2(1,20.2)
		var walking_hand: Vector2=shoulder+Vector2(-cycle.x*.45,19.8)
		if front and character_id in [0,2,5,11]:
			resting_hand=Vector2(5,-25)
			walking_hand=Vector2(5-cycle.x*.12,-25+.25*sin(phase*TAU))
		elif front and character_id in [1,9]:
			resting_hand=Vector2(8,-23)
			walking_hand=Vector2(8-cycle.x*.15,-23)
		var hand: Vector2=resting_hand.lerp(walking_hand,walk_weight)
		if action=="talk" and front:
			hand=Vector2(10+sin(elapsed*1.8)*1.2,-29+sin(elapsed*2)*.7)
		elif action in ["inspect","reach"] and front:
			hand=hand_target
			bones.head.rotation=.025 if hand.y>-40 else -.025
		elif action=="think" and front: hand=Vector2(3,-42)
		if delta>0 and hand_positions.has(side): hand=hand_positions[side].lerp(hand,1-exp(-delta*14))
		hand_positions[side]=hand
		solve_ik(side+"_upperarm",side+"_forearm",hand,11,10,1)
		# Wrist follows the forearm, with a small relaxed articulation, never a world-horizontal palm.
		bones[side+"_wrist"].rotation=-.10 if front else .08
		bones[side+"_hand"].rotation=0
	# Only the carried object is stabilized; wrist and fingers retain their natural angle.
	bones.prop_socket.rotation=-(bones.waist.rotation+bones.chest.rotation+bones.front_clavicle.rotation+bones.front_upperarm.rotation+bones.front_forearm.rotation+bones.front_wrist.rotation+bones.front_hand.rotation)
	bones.prop_socket.position=Vector2(1,0)
	if prop: prop.visible=action not in ["reach","inspect","talk","think"]

func draw_debug() -> void:
	if not debug_bones or not is_instance_valid(skeleton): return
	for key in bones:
		var b: Bone2D = bones[key]
		var p: Vector2 = model_root.to_local(b.global_position)
		debug_layer.draw_circle(p,0.9,Color("eacc7a"))
		if b.get_parent() is Bone2D:
			debug_layer.draw_line(model_root.to_local(b.get_parent().global_position),p,Color("d97269"),0.6)

func bone_world_position(key: String) -> Vector2:
	return to_global(model_root.to_local(bones[key].global_position))

func world_to_model(point: Vector2) -> Vector2:
	var local: Vector2=to_local(point)
	return Vector2(local.x*facing,local.y)
