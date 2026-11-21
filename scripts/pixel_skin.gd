extends RefCounted

static var texture: Texture2D
static var regions: Array
static var shader: Shader
const COLORS=["171f27","2b383e","405958","69817b","e9dbb2","d9a56c","efc58d","a67650","4e3749","775568","6b704b","324360","506581","70532c","ab843e","623638","985442","37333c","555057","959085"]

static func piece(parent: Node2D, points: Array, color: Color, z: int) -> Polygon2D:
	var p:=Polygon2D.new();p.polygon=PackedVector2Array(points);p.color=color;p.z_index=z;parent.add_child(p);return p

static func segment(parent: Node2D, length: float, width: float, color: Color, z: int) -> void:
	piece(parent,[Vector2(-1,-width/2),Vector2(length,-width/2),Vector2(length+1,0),Vector2(length,width/2),Vector2(-1,width/2)],color,z)
	piece(parent,[Vector2(0,width/2-1),Vector2(length,width/2-1),Vector2(length,width/2),Vector2(0,width/2)],color.darkened(.22),z+1)

static func body_mesh(rig: Node2D, region: Array, body_texture: Texture2D = null) -> void:
	var mesh:=Polygon2D.new();mesh.texture=texture if body_texture==null else body_texture;mesh.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	rig.skeleton.add_child(mesh);mesh.skeleton=NodePath("..")
	var vertices:=PackedVector2Array();var uv:=PackedVector2Array();var faces: Array[PackedInt32Array]=[]
	var head_weights:=PackedFloat32Array();var chest_weights:=PackedFloat32Array();var neck_weights:=PackedFloat32Array()
	# One continuous textured mesh: no cut between head, neck and collar.
	for row in 17:
		var y: float=-52.5+31.5*row/16
		for column in 5:
			vertices.append(Vector2(-7.5+15.0*column/4,y))
			uv.append(Vector2(region[0]+region[2]*float(column)/4,region[1]+region[3]*float(row)/16))
			var head_w: float=1-smoothstep(-43.5,-41,y)
			var chest_w: float=smoothstep(-41.5,-38.5,y)
			var total: float=maxf(1,head_w+chest_w)
			head_weights.append(head_w/total);chest_weights.append(chest_w/total);neck_weights.append(1-head_w/total-chest_w/total)
	for row in 16:
		for column in 4:
			var i: int=row*5+column
			faces.append(PackedInt32Array([i,i+1,i+6]));faces.append(PackedInt32Array([i,i+6,i+5]))
	mesh.polygon=vertices;mesh.uv=uv;mesh.polygons=faces
	for pair in [["head",head_weights],["neck",neck_weights],["chest",chest_weights]]:
		mesh.add_bone(rig.skeleton.get_path_to(rig.bones[pair[0]]),pair[1])
	if shader==null:
		shader=Shader.new()
		var palette: String=""
		for hex in COLORS:
			var c:=Color(hex);palette+="vec3(%s,%s,%s),"%[c.r,c.g,c.b]
		palette=palette.trim_suffix(",")
		shader.code="shader_type canvas_item; const vec3 palette[20]=vec3[20]("+palette+"); void fragment(){vec4 s=texture(TEXTURE,UV);if(s.a<.86){discard;}float best=100.;vec3 chosen=palette[0];for(int i=0;i<20;i++){vec3 d=s.rgb-palette[i];float error=dot(d,d);if(error<best){best=error;chosen=palette[i];}}COLOR=vec4(chosen,1.);}"
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material=material

static func apply(rig: Node2D) -> void:
	if texture==null:
		texture=load("res://assets/characters/upperbody-pixel-final-v3.png")
		regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/rig-atlas-v3.json")).upperbody
	for b in rig.bones.values():
		for child in b.get_children():
			if child is Polygon2D: child.color.a=0
	var id: int=rig.character_id
	var index: int=[0,6,7,8,2].find(id)
	var sleeve:=Color(["405958","775568","506581","37333c","e9dbb2"][index] if index>=0 else preload("res://scripts/cast_pixels.gd").CLOTH[id])
	var pants:=Color("2b303a")
	if index>=0: body_mesh(rig,regions[index])
	else: body_mesh(rig,[0,0,20,40],preload("res://scripts/cast_pixels.gd").get_body(id))
	rig.bones.front_clavicle.position=Vector2(-4.8,-1)
	rig.bones.back_clavicle.position=Vector2(3.2,-1)
	for side in ["back","front"]:
		var front: bool=side=="front"
		var z: int=3 if front else -3
		segment(rig.bones[side+"_upperarm"],11,3.5,sleeve if front else sleeve.darkened(.2),z)
		segment(rig.bones[side+"_forearm"],10,2.7,sleeve if front else sleeve.darkened(.2),z)
		piece(rig.bones[side+"_hand"],[Vector2(-1,-1),Vector2(2,-1),Vector2(3,0),Vector2(2,1),Vector2(-1,1)],Color("efc58d"),z)
		segment(rig.bones[side+"_thigh"],13,4.3,pants if front else pants.darkened(.2),1 if front else -3)
		segment(rig.bones[side+"_shin"],12,3.5,pants if front else pants.darkened(.2),1 if front else -3)
		piece(rig.bones[side+"_foot"],[Vector2(-2,-2),Vector2(1,-2),Vector2(2,0),Vector2(5,0),Vector2(6,1),Vector2(6,2),Vector2(-2,2)],Color("171f27"),2 if front else -3)
		piece(rig.bones[side+"_foot"],[Vector2(-1,0),Vector2(2,0),Vector2(2,1),Vector2(-1,1)],Color("555057"),3 if front else -2)
	if is_instance_valid(rig.prop):
		rig.prop.reparent(rig.bones.prop_socket,false);rig.prop.color=Color("ab843e") if id==0 else Color("959085")
		rig.prop.scale=Vector2.ONE*.65
		piece(rig.prop,[Vector2(-3,-5),Vector2(-2,-5),Vector2(-2,5),Vector2(-3,5)],Color("70532c"),1)
