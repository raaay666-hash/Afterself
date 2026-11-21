extends RefCounted

static var parts: Texture2D
static var people: Texture2D
static var npc: Texture2D
static var geometry: Dictionary = {}
static var cloth_shader: Shader

static func put(parent: Node2D, texture: Texture2D, region: Array, target: Rect2, color: Color = Color.WHITE, z: int = 0) -> Sprite2D:
	var sprite:=Sprite2D.new()
	sprite.texture=texture;sprite.region_enabled=true;sprite.region_filter_clip_enabled=true
	sprite.region_rect=Rect2(region[0],region[1],region[2],region[3]);sprite.centered=false
	sprite.position=target.position;sprite.scale=target.size/Vector2(region[2],region[3]);sprite.z_index=z
	if cloth_shader==null:
		cloth_shader=Shader.new()
		cloth_shader.code="shader_type canvas_item; uniform vec4 cloth_tint : source_color; uniform bool recolor=false; void fragment(){ vec4 s=texture(TEXTURE,UV); if(s.a<0.86){discard;} if(recolor){float l=dot(s.rgb,vec3(0.299,0.587,0.114)); s.rgb=cloth_tint.rgb*mix(0.24,1.18,smoothstep(0.04,0.68,l));} COLOR=vec4(s.rgb,1.0); }"
	var material:=ShaderMaterial.new();material.shader=cloth_shader
	material.set_shader_parameter("cloth_tint",color);material.set_shader_parameter("recolor",color!=Color.WHITE)
	sprite.material=material;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite

static func apply(rig: Node2D) -> void:
	if rig.character_id>=0 and rig.character_id<12:
		preload("res://scripts/pixel_skin.gd").apply(rig)
		return
	if parts==null:
		parts=load("res://assets/rig-parts-v2.png");people=load("res://assets/characters-v2.png");npc=load("res://assets/npc-parts-v2.png")
		geometry=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rig-atlas-v3.json"))
	for key in rig.bones:
		for child in rig.bones[key].get_children():
			# The neck is a structural skin bridge; it must remain visible.
			if child is Polygon2D and key!="neck": child.color.a=0
	var p: Array=geometry.parts
	var id: int=rig.character_id
	var palette: Array=rig.PALETTES[id]
	var cloth: Color=Color(palette[0]).lightened(.24)
	var trousers: Color=Color(palette[2]).lightened(.18)
	var npc_column: int={6:0,7:1,8:2,2:3}.get(id,-1)
	# Near/far shoulder and hip are consistent with the three-quarter art.
	rig.bones.front_clavicle.position=Vector2(-4.8,-3.0)
	rig.bones.back_clavicle.position=Vector2(3.0,-3.2)
	if npc_column>=0:
		var torso: Array=geometry.npc[npc_column+4]
		put(rig.bones.chest,npc,torso,Rect2(-6.8,-5.0,13.6,23.3 if id==6 else 20.1),Color.WHITE,0)
	else:
		put(rig.bones.chest,parts,p[1],Rect2(-6.2,-5.0,12.4,20.1),cloth,0)
	put(rig.bones.pelvis,parts,p[2],Rect2(-5.0,-1.5,10,5.2),trousers,-1)
	# Place the actual lower-neck point at the head joint; bounding-box corners are not pivots.
	var region: Array=p[0] if id==0 else (geometry.npc[npc_column] if npc_column>=0 else geometry.heads[id])
	var texture: Texture2D=parts if id==0 else (npc if npc_column>=0 else people)
	var width: float=10.2 if id==0 else 10.7
	var height: float=width*float(region[3])/float(region[2])
	var anchor: Vector2=Vector2(.46,.96) if id==0 else Vector2(.51,.96)
	if npc_column==1: anchor.x=.40
	elif npc_column==2: anchor.x=.51
	elif npc_column==3: anchor.x=.52
	if npc_column<0 and id!=0: anchor=Vector2(.48,.91)
	put(rig.bones.head,texture,region,Rect2(-anchor*Vector2(width,height),Vector2(width,height)),Color.WHITE,4)
	for side in ["back","front"]:
		var front: bool=side=="front"
		var z: int=3 if front else -3
		var sleeve_color: Color=cloth if front else cloth.darkened(.20)
		if front:
			var cap:=Polygon2D.new();var cap_points:=PackedVector2Array()
			for i in 12: cap_points.append(Vector2(cos(i*TAU/12),sin(i*TAU/12))*2.7)
			cap.polygon=cap_points;cap.color=sleeve_color.darkened(.2);cap.z_index=2;rig.bones[side+"_upperarm"].add_child(cap)
		# Rounded overlaps hide joint seams, without drawing a horizontal cuff at the wrist.
		put(rig.bones[side+"_upperarm"],parts,p[3 if front else 9],Rect2(-2.0,-2.5,14,5),sleeve_color,z)
		put(rig.bones[side+"_forearm"],parts,p[4 if front else 10],Rect2(-1.0,-1.9,12,3.8),sleeve_color,z)
		put(rig.bones[side+"_hand"],parts,p[5 if front else 11],Rect2(-.8,-1.0,3.8,1.9),Color.WHITE,z)
		put(rig.bones[side+"_thigh"],parts,p[6 if front else 12],Rect2(-2.0,-2.7,16,5.4),trousers if front else trousers.darkened(.18),1 if front else -3)
		put(rig.bones[side+"_shin"],parts,p[7 if front else 13],Rect2(-1.4,-2.1,14.1,4.2),trousers if front else trousers.darkened(.18),1 if front else -3)
		put(rig.bones[side+"_foot"],parts,p[8 if front else 14],Rect2(-2.2,-3.3,8.0,5.3),Color.WHITE,2 if front else -3)
	if is_instance_valid(rig.prop):
		rig.prop.reparent(rig.bones.prop_socket,false)
		if id in [0,2]: put(rig.prop,parts,p[15],Rect2(-2.2,-3.9,5.0,7.8),Color.WHITE if id==0 else Color(palette[5]),1)
		elif id==6:
			rig.prop.color=Color("685847")
			var flap:=Polygon2D.new();flap.polygon=PackedVector2Array([Vector2(-3,0),Vector2(4,0),Vector2(4,3),Vector2(.5,4),Vector2(-3,3)])
			flap.color=Color("95816a");flap.z_index=1;rig.prop.add_child(flap)
			var handle:=Line2D.new();handle.points=PackedVector2Array([Vector2(-2,1),Vector2(-1,-2),Vector2(2,-2),Vector2(3,1)])
			handle.width=.65;handle.default_color=Color("685847");handle.z_index=1;rig.prop.add_child(handle)
		else: rig.prop.color=Color(palette[5])
