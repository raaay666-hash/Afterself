extends Control

const Data = preload("res://scripts/case_data.gd")
const Rig = preload("res://scripts/character_rig.gd")
const SAVE_PATH = "user://chapter1-v1.json"
const SCENE_NAMES = {"apartment":"07号公寓", "corridor":"维修走廊", "archive":"居民档案室"}
const REQUIRED = ["calendar","testimony","note","order","access","restore","receipt"]
var scene_id: String = "apartment"
var evidence: Array = []
var verdict: int = 0
var completed: bool = false
var identity_choice: String = ""
var session_started: bool = false
var testing: bool = false
var ui: Control
var actors: Node2D
var hero
var modal: Panel
var message: Label
var speaker: Label
var progress: Label
var scene_title: Label
var overlay: Control
var font
var portrait: Texture2D
var rig_lab: bool = false
var lab_actor
var lab_debug: bool = false
var modal_answer: int = -1
var modal_proof: String = ""
var footer: Label
var scene_buttons: Array = []
var evidence_buttons: Array = []
var interaction_targets: Dictionary = {}
var pending_interaction: String = ""
var test_failures: int = 0

func _ready() -> void:
	testing = "--self-test" in OS.get_cmdline_user_args() or "--ui-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	var theme_new := Theme.new()
	theme_new.default_font = font
	theme_new.default_font_size = 18
	theme = theme_new
	if ResourceLoader.exists("res://assets/characters-v2.png"):
		portrait = load("res://assets/characters-v2.png")
	ui = Control.new()
	ui.z_index = 10
	add_child(ui)
	actors = Node2D.new()
	actors.z_index = 1
	add_child(actors)
	move_child(actors,0)
	build_ui()
	load_game()
	show_title()
	if "--self-test" in OS.get_cmdline_user_args():
		call_deferred("run_tests")
	elif "--ui-test" in OS.get_cmdline_user_args():
		call_deferred("run_ui_tests")
	elif "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")

func box_style(bg: String, border: String = "35464b", width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg)
	s.border_color = Color(border)
	s.set_border_width_all(width)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func label_at(parent: Node, text: String, rect: Rect2, size: int = 18, color: String = "d8d5c8") -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.text = text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",Color(color))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = rect.position
	l.size = rect.size
	return l

func button_at(parent: Node, text: String, rect: Rect2, callback: Callable, quiet: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",Color("e7dfc6"))
	b.add_theme_stylebox_override("normal",box_style("172328" if quiet else "26383c"))
	b.add_theme_stylebox_override("hover",box_style("3b514e","c5b77c"))
	b.add_theme_stylebox_override("pressed",box_style("59605a","ded6ac"))
	b.add_theme_stylebox_override("focus",box_style("26383c","c5b77c",2))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func panel_at(parent: Node, rect: Rect2, color: String = "151e25") -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel",box_style(color))
	parent.add_child(p)
	return p

func build_ui() -> void:
	label_at(ui,"启动阶段",Rect2(26,15,220,44),30,"e4d8b0")
	label_at(ui,"CHAPTER 01  /  睡过头的人",Rect2(220,24,420,32),16,"839b9c")
	button_at(ui,"人物设定",Rect2(924,20,104,36),show_cast)
	button_at(ui,"动作实验室",Rect2(1038,20,120,36),show_rig_lab)
	button_at(ui,"菜单",Rect2(1170,20,82,36),show_title)
	scene_title = label_at(ui,"",Rect2(26,66,900,28),18,"cabd92")
	panel_at(ui,Rect2(1008,100,244,468))
	label_at(ui,"调查手记",Rect2(1024,114,210,30),22)
	progress = label_at(ui,"",Rect2(1024,148,210,28),14,"9cb3ae")
	for i in REQUIRED.size():
		var key: String = REQUIRED[i]
		var b := button_at(ui,"",Rect2(1024,190+i*42,212,36),func(): show_evidence(key),true)
		evidence_buttons.append(b)
	button_at(ui,"整理证据 · 提交推理",Rect2(1024,500,212,48),show_deduction)
	panel_at(ui,Rect2(26,538,958,124))
	speaker = label_at(ui,"林砚",Rect2(44,546,884,28),18,"cabe8e")
	message = label_at(ui,"",Rect2(44,578,922,80),18)
	var i: int = 0
	for key in SCENE_NAMES:
		button_at(ui,SCENE_NAMES[key],Rect2(26+i*194,490,184,38),func(): enter_scene(key))
		i += 1
	button_at(ui,"调查提示",Rect2(804,490,180,38),show_hint,true)
	footer = label_at(ui,"鼠标点选人物与物件  ·  进度自动保存  ·  Esc 关闭面板  ·  F3 骨架",Rect2(26,675,1220,24),14,"819797")
	refresh_evidence()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal): close_modal()
		elif session_started: show_title()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		lab_debug = not lab_debug
		for actor in actors.get_children(): actor.debug_bones = lab_debug
		if is_instance_valid(lab_actor): lab_actor.debug_bones = lab_debug

func clear_hotspots() -> void:
	for b in scene_buttons:
		if is_instance_valid(b):
			b.hide()
			b.queue_free()
	scene_buttons.clear()
	interaction_targets.clear()
	for a in actors.get_children():
		actors.remove_child(a)
		a.queue_free()

func actor_at(id: int, x: float, scale_value: float = 2.0):
	var a = Rig.new()
	a.character_id = id
	a.position = Vector2(x,448)
	a.scale = Vector2.ONE*scale_value
	actors.add_child(a)
	a.debug_bones = lab_debug
	return a

func enter_scene(key: String, persist: bool = true) -> void:
	close_modal()
	if not SCENE_NAMES.has(key): return
	scene_id = key
	session_started = true
	rig_lab = false
	clear_hotspots()
	pending_interaction=""
	scene_title.text = SCENE_NAMES[key]+"  /  城市维护前夜"
	hero = actor_at(0,140)
	hero.arrived.connect(func():
		if not pending_interaction.is_empty():
			var interaction_key: String = pending_interaction
			pending_interaction=""
			perform_interaction(interaction_key))
	if key == "apartment":
		actor_at(6,410)
		actor_at(7,742)
		hotspot("苏筠",Rect2(350,292,120,164),"su")
		hotspot("宋屿",Rect2(686,288,110,168),"song")
		hotspot("桌上日历",Rect2(482,326,136,44),"calendar")
		hotspot("旧抽屉",Rect2(833,359,118,44),"note")
		say("林砚","两杯茶都还是热的。屋里的人，却像隔着不同的日子。")
	elif key == "corridor":
		actor_at(8,682)
		hotspot("邵为",Rect2(626,290,114,166),"shao")
		hotspot("维修公告",Rect2(334,226,138,44),"order")
		hotspot("门禁签收台",Rect2(784,355,176,44),"access")
		say("林砚","公告上写着：维护期间，一切生活照常。下面的胶带盖住了一个字。")
	else:
		actor_at(2,560)
		hotspot("闻遥",Rect2(506,286,112,170),"wen")
		hotspot("恢复登记台",Rect2(258,337,178,44),"restore")
		hotspot("独立审计柜",Rect2(744,243,178,44),"receipt")
		say("闻遥","你要查的是恢复记录，还是被恢复的人？这两件事，最好分开问。")
	queue_redraw()
	if persist: save_game()

func hotspot(text: String, rect: Rect2, key: String) -> void:
	# Transparent broad actor hit areas with captions; object hotspots are visible plaques.
	var b := button_at(ui,text,rect,func(): interact(key))
	if key in ["su","song","shao","wen"]:
		b.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover",box_style("20383922","b9b38a"))
		b.add_theme_stylebox_override("pressed",box_style("30484944","d4c891"))
		b.text = ""
		var caption := label_at(b,text,Rect2(0,rect.size.y-12,rect.size.x,24),16,"ded5b5")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_constant_override("outline_size",3)
		caption.add_theme_color_override("font_outline_color",Color("10171e"))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("outline_size",3)
		b.add_theme_color_override("font_outline_color",Color("121921"))
		scene_buttons.append(b)
	interaction_targets[key]=rect.get_center()

func interact(key: String) -> void:
	if testing:
		perform_interaction(key)
		return
	if is_instance_valid(hero) and interaction_targets.has(key):
		pending_interaction=key
		var target: Vector2=interaction_targets[key]
		hero.walk_to(clampf(target.x-56,92,904))
		say("林砚","走近查看……")
	else:
		perform_interaction(key)

func perform_interaction(key: String) -> void:
	if is_instance_valid(hero):
		hero.action = "inspect" if Data.EVIDENCE.has(key) else "talk"
		hero.facing=1
	if Data.EVIDENCE.has(key):
		collect(key)
		return
	match key:
		"su":
			say("苏筠","上周我们还在吵。三天前和好了，昨天去看了铺面……他现在只记得吵架。\n我知道他看起来一样。你别也只看这一点。")
		"song":
			collect("testimony",false)
			say("宋屿","我也记得爱她。可我不记得她说的那个我。\n如果真的有人死了，请把他的事查清。但别让我替他承诺以后。")
		"shao":
			if "receipt" in evidence and "access" in evidence:
				say("邵为","是我签的，凭据没有借过人。他要举报 Q-17，我会被撤掉资格。\n可早上他又站在那里了！为什么你们只说我做了前一半？")
			else:
				say("邵为","凭据我自己领、自己还，没交给别人。维护成功了，住户也醒了。\n你要看工单就看。别把每次维护都说成一场葬礼。")
		"wen":
			say("闻遥","恢复登记回答‘什么时候启动’，审计回执回答‘谁发出了指令’。\n审计端只追加记录，管理处不能覆盖它。但你还得查凭据当时在谁手里。")

func say(name_text: String, text: String) -> void:
	speaker.text = name_text
	message.text = text

func collect(key: String, show: bool = true) -> void:
	if not Data.EVIDENCE.has(key): return
	if key not in evidence:
		evidence.append(key)
		refresh_evidence()
		save_game()
	if show:
		say("已记入案卷 · "+Data.EVIDENCE[key][0],Data.EVIDENCE[key][2])

func refresh_evidence() -> void:
	progress.text = "%d / %d 份记录  ·  推理 %d / 3" % [evidence.size(),REQUIRED.size(),verdict]
	for i in REQUIRED.size():
		var key: String = REQUIRED[i]
		evidence_buttons[i].text = ("✓  "+Data.EVIDENCE[key][0]) if key in evidence else ("—  尚未取得的记录")
		evidence_buttons[i].disabled = key not in evidence

func show_evidence(key: String) -> void:
	if key not in evidence: return
	new_modal(Data.EVIDENCE[key][0])
	label_at(modal,Data.EVIDENCE[key][1],Rect2(28,68,816,32),16,"aabead")
	label_at(modal,Data.EVIDENCE[key][2],Rect2(28,124,816,240),23)
	button_at(modal,"返回调查",Rect2(630,462,210,42),close_modal)

func new_modal(title: String, wide: bool = false) -> void:
	close_modal()
	overlay = Control.new()
	overlay.z_index = 50
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.025,0.035,0.045,0.94)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	modal = panel_at(overlay,Rect2(58,68,1164,592) if wide else Rect2(202,92,876,536))
	label_at(modal,title,Rect2(28,18,modal.size.x-130,42),27,"e3d8ad")
	button_at(modal,"关闭",Rect2(modal.size.x-96,20,70,34),close_modal,true)

func close_modal() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	modal = null
	overlay = null
	lab_actor = null
	rig_lab = false

func show_title() -> void:
	new_modal("启动阶段  /  第一章机制样机")
	label_at(modal,"一个人醒了。\n另一个人没有。",Rect2(32,90,770,138),42,"ece0b9")
	label_at(modal,"你是数字城市的调查员林砚。调查一场被‘恢复成功’掩盖的死亡。\n当前版本包含三处场景、完整短案件、人物设定与 23 骨骼动作实验室。",Rect2(32,250,780,92),20)
	button_at(modal,"继续调查" if session_started or not evidence.is_empty() else "开始调查",Rect2(32,382,252,48),func(): enter_scene(scene_id))
	button_at(modal,"重新开始",Rect2(304,382,224,48),confirm_new_game)
	button_at(modal,"角色与动作",Rect2(548,382,276,48),show_rig_lab)
	label_at(modal,"这是开发中的短流程样机；完整六章、配音、最终精灵动画尚未完成。",Rect2(32,452,784,48),16,"9cb0ad")

func confirm_new_game() -> void:
	new_modal("重新开始调查")
	label_at(modal,"这会覆盖本样机的当前调查进度。",Rect2(32,128,790,90),25)
	button_at(modal,"保留进度",Rect2(32,382,320,48),show_title)
	button_at(modal,"确认重新开始",Rect2(384,382,430,48),func(): reset_game(); enter_scene("apartment"))

func reset_game() -> void:
	evidence = []
	verdict = 0
	completed = false
	identity_choice = ""
	scene_id = "apartment"
	refresh_evidence()
	save_game()

func show_hint() -> void:
	for key in REQUIRED:
		if key not in evidence:
			say("调查提示", "还缺少一份记录。可以去"+Data.EVIDENCE[key][1]+"查问。注意：有权限，不等于实际执行过。")
			return
	say("调查提示","七份记录已经齐全。打开‘整理证据’，依次回答发生了什么、谁执行、为什么，并选出对应证据。")

func show_deduction() -> void:
	if completed:
		show_ending()
		return
	if evidence.size() < REQUIRED.size():
		new_modal("证据还没有形成闭环")
		label_at(modal,"目前有 %d / 7 份记录。\n\n维修资格只能说明机会。请补全凭据的保管记录、独立执行回执与举报动机，再提交结论。\n\n关闭面板后可点‘调查提示’查找遗漏。" % evidence.size(),Rect2(30,108,802,260),23)
		return
	if verdict >= 3:
		show_identity()
		return
	new_modal("结案推理 · 每项结论必须举证")
	var q: Dictionary = Data.QUESTIONS[verdict]
	label_at(modal,q.q,Rect2(28,74,820,40),23)
	modal_answer = -1
	modal_proof = ""
	var choices: Array = []
	for i in 3:
		var b := button_at(modal,q.answers[i],Rect2(28,132+i*51,820,44),func(): modal_answer=i; mark_choice(choices,i))
		choices.append(b)
	label_at(modal,"选择主要证据（其他已收集记录同时随卷提交）",Rect2(28,290,814,28),16,"aabead")
	var proofs := OptionButton.new()
	proofs.position = Vector2(28,330)
	proofs.size = Vector2(820,42)
	proofs.add_item("请选择支持这一结论的证据")
	for key in REQUIRED: proofs.add_item(Data.EVIDENCE[key][0])
	proofs.item_selected.connect(func(idx: int): modal_proof=REQUIRED[idx-1] if idx > 0 else "")
	modal.add_child(proofs)
	var feedback := label_at(modal,"",Rect2(28,384,820,60),16,"d9a08a")
	button_at(modal,"确认这项推理",Rect2(558,466,290,44),func():
		if submit_deduction(modal_answer,modal_proof): show_deduction()
		else: feedback.text="结论或证据尚不匹配。"+q.hint)

func mark_choice(buttons: Array, selected: int) -> void:
	for i in buttons.size():
		buttons[i].add_theme_stylebox_override("normal",box_style("52665b" if i == selected else "26383c","d7c48d" if i == selected else "35464b"))

func submit_deduction(answer: int, proof: String) -> bool:
	if verdict >= 3 or evidence.size() < REQUIRED.size(): return false
	var q: Dictionary = Data.QUESTIONS[verdict]
	if answer != q.correct or proof != q.proof or proof not in evidence: return false
	verdict += 1
	refresh_evidence()
	save_game()
	return true

func show_identity() -> void:
	new_modal("案件已经查清。报告还没有写完。")
	label_at(modal,"邵为承认终止了旧宋屿，又启动旧备份，以阻止 Q-17 违规清理被举报。恢复没有撤销那次死亡。\n\n宋屿：‘请给我一份自己的记录。我想记得今天是我自己选的。’\n\n如何填写现行宋屿的身份？",Rect2(28,96,816,248),23)
	button_at(modal,"单列现行实例，保留与死者的历史联系",Rect2(28,372,816,50),func(): finish_case("independent"))
	button_at(modal,"沿用原档案，注明旧实例终止与恢复",Rect2(28,436,816,50),func(): finish_case("continued"))

func finish_case(choice: String) -> void:
	if verdict != 3 or choice not in ["independent","continued"]: return
	identity_choice = choice
	completed = true
	save_game()
	show_ending()

func show_ending() -> void:
	new_modal("第一章样机 · 结案")
	var response: String = "宋屿第一次不再问自己是不是正常。他说：‘店铺的事，我想重新和她谈。’\n苏筠把第二杯茶递过去：‘好，这次先听你说。’" if identity_choice == "independent" else "宋屿看着沿用的编号：‘你记录了中断，却还是没有按我的意愿分开。’\n苏筠没有替他回答。报告可以结案，关系却还需要重新商量。"
	label_at(modal,response+"\n\n清理名单的最后一页，出现了林砚自己的编号。\n\n本次短案件结束。后续五章仍在制作规划中。",Rect2(28,98,816,292),23)
	button_at(modal,"返回现场 · 重读证据",Rect2(28,444,380,48),close_modal)
	button_at(modal,"查看人物动作",Rect2(438,444,410,48),show_rig_lab)

func show_cast() -> void:
	new_modal("人物重设计 v2 · 十二人的生活与矛盾",true)
	for i in 12:
		var x: float = 22+(i%4)*282
		var y: float = 76+int(i/4)*160
		if portrait:
			var atlas := AtlasTexture.new()
			atlas.atlas = portrait
			atlas.region = Rect2(Vector2(i%4,int(i/4))*portrait.get_size()/Vector2(4,3),portrait.get_size()/Vector2(4,3))
			var t := TextureRect.new()
			t.texture = atlas
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.position = Vector2(x,y)
			t.size = Vector2(88,146)
			modal.add_child(t)
		label_at(modal,Data.CAST[i][0],Rect2(x+92,y+3,180,28),19,"d6c797")
		label_at(modal,Data.CAST[i][1],Rect2(x+92,y+40,164,94),16)
	label_at(modal,"造型参考图与骨骼样机分开验收：当前游戏内为可运行的分部件骨骼模型。",Rect2(24,558,1100,25),14,"8fa7a3")

func show_rig_lab(id: int = 0) -> void:
	new_modal("动作实验室 · 25 骨骼 / 像素绑定",true)
	rig_lab = true
	label_at(modal,"先校准动作，再制作最终精灵。\n金色点是关节，红线是骨骼。\n\n步行支撑期脚底锁定地面；\n抬脚期走弧线，膝盖向前弯。\n手臂按目标位置解算肘关节。",Rect2(28,102,310,260),20)
	var ground := ColorRect.new()
	ground.color = Color("556361")
	ground.position = Vector2(360,490)
	ground.size = Vector2(470,2)
	modal.add_child(ground)
	lab_actor = Rig.new()
	lab_actor.character_id = id
	lab_actor.position = Vector2(590,486)
	lab_actor.scale = Vector2.ONE*5
	lab_actor.debug_bones = lab_debug
	modal.add_child(lab_actor)
	var picker := OptionButton.new()
	picker.position = Vector2(872,90)
	picker.size = Vector2(264,40)
	for c in Data.CAST: picker.add_item(c[0])
	picker.selected = id
	picker.item_selected.connect(show_rig_lab)
	modal.add_child(picker)
	var modes := {"站立 / 呼吸":"idle","行走 / 落脚":"walk","说话 / 手势":"talk","思考 / 手触下颌":"think","取证 / 手部目标":"reach"}
	var idx: int = 0
	for title in modes:
		var mode: String = modes[title]
		button_at(modal,title,Rect2(872,152+idx*51,264,42),func(): lab_actor.action=mode)
		idx += 1
	button_at(modal,"转身",Rect2(872,422,124,42),func(): lab_actor.facing *= -1)
	button_at(modal,"骨架开关",Rect2(1008,422,128,42),func(): lab_debug=not lab_debug; lab_actor.debug_bones=lab_debug)
	label_at(modal,"取证状态：点击人物附近，移动手部目标。目标过远时限制在手臂可达范围。",Rect2(28,544,1100,28),16,"a7b6ac")
	var target_button := Control.new()
	target_button.position = Vector2(356,100)
	target_button.size = Vector2(478,392)
	target_button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(lab_actor):
			lab_actor.action="reach"
			lab_actor.hand_target=lab_actor.world_to_model(target_button.get_global_transform()*e.position))
	modal.add_child(target_button)

func save_game(path: String = SAVE_PATH, force_test: bool = false) -> void:
	if testing and not force_test: return
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		footer.text="本次进度未能保存："+error_string(FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify({"version":1,"scene":scene_id,"evidence":evidence,"verdict":verdict,"completed":completed,"identity":identity_choice}))
	file.close()
	var err: int = DirAccess.rename_absolute(path+".tmp",path)
	if err != OK: footer.text="自动保存失败："+error_string(err)

func apply_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1: return false
	if not data.get("evidence") is Array: return false
	var clean: Array = []
	for key in data.evidence:
		if key is String and Data.EVIDENCE.has(key) and key not in clean: clean.append(key)
	evidence = clean
	scene_id = str(data.get("scene","apartment"))
	if not SCENE_NAMES.has(scene_id): scene_id="apartment"
	var raw_verdict: Variant = data.get("verdict",0)
	verdict = clampi(int(raw_verdict),0,3) if raw_verdict is int or raw_verdict is float else 0
	if evidence.size() != REQUIRED.size(): verdict=0
	identity_choice = str(data.get("identity",""))
	completed = data.get("completed") == true and verdict == 3 and identity_choice in ["independent","continued"]
	session_started = true
	refresh_evidence()
	return true

func load_game() -> void:
	if testing or not FileAccess.file_exists(SAVE_PATH): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not apply_save(data): footer.text="存档无法识别。已保留原文件；可以重新开始调查。"

func pixel_rect(x: float,y: float,w: float,h: float,c: String) -> void:
	draw_rect(Rect2(x,y,w,h),Color(c))

func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10171e"))
	draw_set_transform(Vector2(26,100),0,Vector2(3,3))
	pixel_rect(0,0,320,128,"232b33")
	pixel_rect(0,108,320,20,"343b3f")
	for x in range(0,320,32): pixel_rect(x,110,1,18,"262e35")
	if scene_id == "apartment":
		pixel_rect(10,6,93,83,"16272f")
		for x in range(16,98,16):
			pixel_rect(x,40-(x%24),12,45+(x%24),"314750")
			pixel_rect(x+3,55,3,4,"a39360")
		pixel_rect(54,6,3,83,"495353")
		pixel_rect(10,46,93,3,"495353")
		pixel_rect(114,22,73,34,"3f4546")
		pixel_rect(119,27,63,24,"6c6860")
		pixel_rect(114,80,55,7,"616259")
		pixel_rect(119,87,5,25,"3e4643")
		pixel_rect(157,87,5,25,"3e4643")
		pixel_rect(127,73,6,7,"c2b38b")
		pixel_rect(147,73,6,7,"c2b38b")
		pixel_rect(265,82,46,33,"675e4d")
		pixel_rect(268,86,40,11,"7a6a52")
		pixel_rect(284,89,7,2,"b5a273")
		pixel_rect(212,19,45,6,"8a8365")
		pixel_rect(218,25,33,3,"4d5250")
	elif scene_id == "corridor":
		for x in [18,75,177]:
			pixel_rect(x,24,45,85,"18272b")
			pixel_rect(x+4,29,37,80,"38474a")
			pixel_rect(x+32,72,3,4,"b5aa73")
		pixel_rect(108,18,47,45,"81795e")
		for y in [24,35,46]: pixel_rect(114,y,31,6,"c4b892")
		pixel_rect(254,71,57,40,"525b56")
		pixel_rect(261,64,31,8,"b6af8b")
		pixel_rect(0,12,320,3,"525d59")
		pixel_rect(224,0,4,110,"525d59")
	else:
		for x in [10,64,211,265]:
			pixel_rect(x,13,45,89,"3c4b49")
			for y in range(18,100,14):
				pixel_rect(x+3,y,39,11,"6b705e")
				pixel_rect(x+17,y+3,11,3,"b9af8d")
		pixel_rect(76,87,143,10,"737566")
		pixel_rect(83,97,9,16,"4c5c53")
		pixel_rect(203,97,9,16,"4c5c53")
		pixel_rect(139,70,27,17,"cec2a1")
		pixel_rect(146,77,11,1,"6f7869")
	pixel_rect(0,116,320,2,"161f28")
	draw_set_transform(Vector2.ZERO)

func capture_preview() -> void:
	enter_scene("apartment",false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("game-preview.png"))
	show_rig_lab(0)
	lab_actor.debug_bones=true
	lab_actor.action="walk"
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("rig-preview.png"))
	show_cast()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("cast-preview.png"))
	get_tree().quit()

func artifact_path(filename: String) -> String:
	if OS.has_feature("editor"):
		return "res://build/"+filename
	return OS.get_executable_path().get_base_dir().path_join(filename)

func check(condition: bool, description: String) -> void:
	if not condition:
		test_failures += 1
		push_error("FAIL: "+description)
	else:
		print("PASS: "+description)

func run_tests() -> void:
	reset_game()
	enter_scene("apartment",false)
	check(not submit_deduction(1,"restore"),"missing evidence blocks deduction")
	interact("calendar"); interact("note"); interact("song")
	enter_scene("corridor",false)
	interact("order"); interact("access")
	enter_scene("archive",false)
	interact("restore"); interact("receipt")
	check(evidence.size()==7,"all evidence reachable through scene interactions")
	collect("receipt")
	check(evidence.size()==7,"repeated evidence is idempotent")
	check(not submit_deduction(0,"restore"),"wrong theory rejected")
	check(not submit_deduction(1,"order"),"correct theory with wrong evidence rejected")
	check(submit_deduction(1,"restore"),"restoration timeline established")
	check(submit_deduction(2,"receipt"),"operator established")
	check(submit_deduction(0,"note"),"motive established")
	finish_case("independent")
	check(completed and identity_choice=="independent","independent identity ending")
	finish_case("continued")
	check(completed and identity_choice=="continued","continued identity ending")
	var test_save: String=artifact_path("test-save.json")
	save_game(test_save,true)
	finish_case("independent")
	save_game(test_save,true)
	evidence=[]
	completed=false
	verdict=0
	check(apply_save(JSON.parse_string(FileAccess.get_file_as_string(test_save))),"save roundtrip from disk")
	check(completed and evidence.size()==7 and identity_choice=="independent","atomic save replaces previous state")
	check(not apply_save("broken"),"malformed save rejected")
	check(apply_save({"version":1,"evidence":["note","note","invalid"],"scene":"bad","verdict":99,"completed":true}),"save sanitization")
	check(evidence.size()==1 and verdict==0 and not completed and scene_id=="apartment","invalid save cannot unlock ending")
	show_rig_lab()
	check(lab_actor.bones.size()==23,"23 Bone2D joints constructed")
	for a in ["idle","walk","talk","think","reach"]:
		lab_actor.action=a
		for i in 80:
			lab_actor.travelled=i*0.5
			lab_actor.elapsed=i*0.02
			lab_actor.pose(0.02)
			for key in lab_actor.bones:
				check_finite(lab_actor.bones[key].rotation)
			if a == "walk":
				for side in ["front","back"]:
					var phase: float=fposmod(lab_actor.travelled/36.0+(0 if side=="front" else 0.5),1)
					var target: Vector2=lab_actor.foot_cycle(phase)
					var actual: Vector2=lab_actor.skeleton.to_local(lab_actor.bones[side+"_foot"].global_position)
					if actual.distance_to(target)>0.05:
						check(false,"IK foot accuracy %s %s vs %s" %[side,actual,target])
		print("PASS: animation pose "+a)
	lab_actor.facing=-1
	lab_actor.pose(0)
	check(lab_actor.skeleton.scale.x==-1,"turn preserves skeleton hierarchy")
	lab_actor.facing=1
	lab_actor.action="reach"
	for target in [Vector2(12,-32),Vector2(18,-33),Vector2(7,-43)]:
		lab_actor.hand_target=target
		lab_actor.pose(0)
		var actual: Vector2=lab_actor.skeleton.to_local(lab_actor.bones.front_hand.global_position)
		check(actual.distance_to(target)<0.05,"hand target accuracy "+str(target))
	lab_actor.hand_target=Vector2(10000,-10000)
	lab_actor.pose(0)
	check_finite(lab_actor.bones.front_upperarm.rotation)
	check_finite(lab_actor.bones.front_forearm.rotation)
	print("PASS: unreachable hand target clamped")
	for id in 12:
		show_rig_lab(id)
		check(lab_actor.bones.size()==23,"shared rig character "+str(id))
	show_rig_lab(0)
	lab_actor.scale=Vector2.ONE
	lab_actor.position=Vector2.ZERO
	lab_actor.walk_to(72)
	var previous_foot: float=0
	var previous_phase: float=-1
	var max_slip: float=0
	for i in 120:
		lab_actor._process(1.0/60.0)
		var phase: float=fposmod(lab_actor.travelled/36.0,1)
		var foot_x: float=lab_actor.bones.front_foot.global_position.x
		if lab_actor.move_enabled and previous_phase>=0 and previous_phase<phase and phase<0.6:
			max_slip=maxf(max_slip,absf(foot_x-previous_foot))
		previous_foot=foot_x
		previous_phase=phase
	check(max_slip<0.05,"world-space planted-foot slip under tolerance")
	check(lab_actor.reached and is_equal_approx(lab_actor.position.x,72),"walk arrival and idle transition")
	print("ALL TESTS PASSED" if test_failures==0 else "TESTS FAILED: "+str(test_failures))
	get_tree().quit(0 if test_failures==0 else 1)

func check_finite(value: float) -> void:
	if not is_finite(value): check(false,"animation rotation must be finite")

func mouse_click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		event.position=point
		Input.parse_input_event(event)
		await get_tree().process_frame

func run_ui_tests() -> void:
	await get_tree().process_frame
	await mouse_click(Vector2(350,494))
	check(session_started and not is_instance_valid(modal),"UI title starts investigation")
	await mouse_click(Vector2(538,348))
	check("calendar" in evidence,"UI calendar hotspot")
	await mouse_click(Vector2(272,508))
	check(scene_id=="corridor","UI scene navigation")
	await mouse_click(Vector2(394,248))
	check("order" in evidence,"UI corridor object")
	await mouse_click(Vector2(1068,207))
	check(is_instance_valid(modal),"UI evidence review opens")
	await mouse_click(Vector2(1015,128))
	check(not is_instance_valid(modal),"UI close button")
	await mouse_click(Vector2(1090,40))
	check(is_instance_valid(lab_actor),"UI animation lab opens")
	await mouse_click(Vector2(1060,291))
	check(lab_actor.action=="walk","UI walk animation selection")
	await mouse_click(Vector2(1136,510))
	check(lab_actor.debug_bones,"UI skeleton overlay toggle")
	await mouse_click(Vector2(990,510))
	check(lab_actor.facing==-1,"UI turn control")
	await mouse_click(Vector2(697,411))
	check(lab_actor.action=="reach","UI click sets hand target")
	lab_actor.pose(0)
	check(lab_actor.bones.front_hand.global_position.distance_to(Vector2(697,411))<0.25,"UI hand reaches clicked screen position")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("ui-tested.png"))
	print("ALL UI TESTS PASSED" if test_failures==0 else "UI TESTS FAILED: "+str(test_failures))
	get_tree().quit(0 if test_failures==0 else 1)
