extends SceneTree

const Rig=preload("res://scripts/character_rig.gd")
var stage: Node2D
var font: SystemFont
var output: String

func _initialize() -> void:
	call_deferred("run")

func caption(text: String, pos: Vector2, size: int = 18) -> void:
	var label:=Label.new();label.text=text;label.position=pos;label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",size);label.modulate=Color("d5d8cc");stage.add_child(label)

func actor(id: int, pos: Vector2, s: float, action_name: String, phase: float, face: float = 1) -> Node2D:
	var a=Rig.new();a.character_id=id;a.position=pos;a.scale=Vector2.ONE*s
	stage.add_child(a);a.set_process(false);a.action=action_name;a.travelled=phase*a.STRIDE;a.facing=face;a.pose(0)
	return a

func reset_stage() -> void:
	if is_instance_valid(stage): stage.free()
	stage=Node2D.new();root.add_child(stage)
	var bg:=ColorRect.new();bg.size=Vector2(1280,720);bg.color=Color("273338");bg.z_index=-20;stage.add_child(bg)

func snap(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))

func run() -> void:
	output=ProjectSettings.globalize_path("res://build/v3") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("rig-review")
	DirAccess.make_dir_recursive_absolute(output.path_join("motion"))
	font=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"])
	reset_stage();caption("人物结构复核  /  站立 · 对话 · 取证",Vector2(35,20),25)
	for col in 5:
		var id: int=[0,6,7,8,2][col]
		caption(["林砚","苏筠","宋屿","邵为","闻遥"][col],Vector2(75+col*245,72))
		actor(id,Vector2(95+col*245,360),4.1,"idle",0)
		actor(id,Vector2(70+col*245,680),3.3,"talk",0)
		actor(id,Vector2(170+col*245,680),3.3,"reach",0,-1)
	await snap("cast-review.png")
	reset_stage();caption("林砚步态复核 / 8 个连续相位 · 下排反向与骨架",Vector2(28,20),23)
	for i in 8:
		caption(str(i)+" / "+str(i*12.5)+"%",Vector2(30+i*157,68),16)
		actor(0,Vector2(66+i*157,362),4.2,"walk",float(i)/8)
		var a=actor(0,Vector2(66+i*157,696),4.2,"walk",float(i)/8,-1)
		a.debug_bones=true;a.debug_layer.queue_redraw()
	await snap("walk-phases.png")
	reset_stage();caption("动作连续预览 / 原速步行 · 前后朝向 · 同一套实际游戏骨架",Vector2(30,20),22)
	var actors: Array=[]
	for i in 5:
		caption(["林砚","苏筠","宋屿","邵为","闻遥"][i],Vector2(75+i*245,70))
		actors.append(actor([0,6,7,8,2][i],Vector2(100+i*245,375),4.3,"walk",0))
		actors.append(actor([0,6,7,8,2][i],Vector2(100+i*245,698),4.3,"walk",0,-1))
	for frame in 48:
		for a in actors:
			a.travelled=float(frame);a.elapsed=float(frame)/28;a.pose(0)
		await snap("motion/frame-%03d.png"%frame)
	var isolated:=SubViewport.new();isolated.size=Vector2i(280,340);isolated.transparent_bg=true;isolated.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(isolated)
	DirAccess.make_dir_recursive_absolute(output.path_join("isolated"))
	for id in [0,6,7,8,2]:
		var a=Rig.new();a.character_id=id;a.position=Vector2(120,315);a.scale=Vector2.ONE*4.5;isolated.add_child(a);a.set_process(false)
		for index in 8:
			a.action=["idle","walk","walk","walk","walk","talk","reach","think"][index]
			a.travelled=([0,.0,.25,.5,.75,0,0,0][index])*a.STRIDE;a.facing=1 if index%2==0 else -1;a.pose(0)
			await process_frame;await RenderingServer.frame_post_draw
			isolated.get_texture().get_image().save_png(output.path_join("isolated/character-%02d-pose-%d.png"%[id,index]))
		a.free()
	isolated.free()
	reset_stage()
	var scene:=Sprite2D.new();scene.texture=load("res://assets/scenes/apartment.png");scene.centered=false;scene.scale=Vector2(1280,720)/scene.texture.get_size();scene.z_index=-10;stage.add_child(scene)
	caption("实际移动验证 / 起步 → 匀速 → 减速 → 站定",Vector2(35,25),26)
	var walking=actor(0,Vector2(135,592),5,"idle",0);walking.speed=28;walking.walk_to(1090)
	DirAccess.make_dir_recursive_absolute(output.path_join("locomotion"))
	for frame in 192:
		walking._process(1.0/24)
		await snap("locomotion/frame-%03d.png"%frame)
	print("RIG VISUAL CAPTURE COMPLETE")
	quit()
