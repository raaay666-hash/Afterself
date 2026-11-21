extends "res://scripts/main.gd"

const Story = preload("res://scripts/story_v2.gd")
const Chapter = preload("res://scripts/story_v4.gd")
const Sound = preload("res://scripts/soundscape.gd")
const Opening = preload("res://scripts/opening_cutscene.gd")
const CHAPTER_SAVE_PATH = "user://chapter1-v4.json"
const PERSON_IDS = {"su":6,"song":7,"shao":8,"wen":2,"林砚":0,"苏筠":6,"宋屿":7,"邵为":8,"闻遥":2,"现实林砚":1,"银发董事":1,"二十七岁的技术员":0,"孟岚":3,"顾舟":4,"周临":5,"祝青":9,"许禾":10,"罗荻":11}
const TOPIC_NAMES = {"su":"苏筠","song":"宋屿","shao":"邵为","wen":"闻遥"}
const TOPIC_BLURBS = {"su":"07 号公寓报案人。她担心宋屿失去的三天。","song":"07 号公寓住户。他说自己记不起最近三天。","shao":"维修走廊的夜班维护员，负责 M-204 工单。","wen":"居民档案员，协助核对恢复记录。"}
var background: TextureRect
var backgrounds: Dictionary = {}
var sound
var flags: Dictionary = {}
var seen_topics: Array = []
var claims: Array = []
var intro_done: bool = false
var court_step: int = 0
var v2_started: bool = false
var title_mode: bool = true
var hotspots_visible: bool = false
var hover_name: String = ""
var hover_position: Vector2 = Vector2.ZERO
var hint_level: int = 0
var selected_clues: Array = []
var phase_time: float = 0.0
var step_time: float = 0.0
var current_lines: Array = []
var line_index: int = 0
var after_dialog: Callable
var dialog_mode: bool = false
var typewriter: bool = true
var typing_elapsed: float = 0.0
var dialog_text: Label
var talk_actor
var active_people: Dictionary = {}
var target_caption: Label
var toast_label: Label
var toast_life: float = 0.0
var toast_panel: Panel
var objectives: Label
var tooltip: Label
var status_tag: Label
var test_ui_nodes: Dictionary = {}
var simulate_walk: bool = false
var quitting: bool = false
var observations: Array = []
var decisions: Dictionary = {}
var pending_event: String = ""
var choice_locked: bool = false
var horizon_layer: Control
var opening_layer: Control

func _ready() -> void:
	get_tree().auto_accept_quit=false
	testing = "--self-test" in OS.get_cmdline_user_args() or "--ui-test" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--playthrough-test" in OS.get_cmdline_user_args() or "--campaign-test" in OS.get_cmdline_user_args() or "--campaign-window-test" in OS.get_cmdline_user_args() or "--full-story-test" in OS.get_cmdline_user_args() or "--desk-test" in OS.get_cmdline_user_args() or "--desk-window-test" in OS.get_cmdline_user_args() or "--dossier-preview" in OS.get_cmdline_user_args()
	testing=testing or "--audio-smoke" in OS.get_cmdline_user_args()
	testing=testing or "--collection-test" in OS.get_cmdline_user_args() or "--collection-window-test" in OS.get_cmdline_user_args()
	testing=testing or "--field-test" in OS.get_cmdline_user_args() or "--field-window-test" in OS.get_cmdline_user_args() or "--field-story-test" in OS.get_cmdline_user_args()
	font=load("res://assets/fonts/pixel-text.otf")
	var t:=Theme.new()
	t.default_font=font;t.default_font_size=20;theme=t
	portrait=load("res://assets/characters-v2.png")
	for key in ["apartment","corridor","archive","street"]:
		var path: String="res://assets/scenes/"+key+".png"
		if ResourceLoader.exists(path): backgrounds[key]=load(path)
	background=TextureRect.new()
	background.position=Vector2.ZERO;background.size=Vector2(1280,720)
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_SCALE
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var world_shader:=Shader.new()
	world_shader.code="shader_type canvas_item; void fragment(){vec2 grid=vec2(320.0,180.0);COLOR=texture(TEXTURE,(floor(UV*grid)+vec2(.5))/grid);}"
	var world_material:=ShaderMaterial.new();world_material.shader=world_shader;background.material=world_material
	background.z_index=-5
	add_child(background)
	actors=Node2D.new();actors.z_index=2;add_child(actors)
	ui=Control.new();ui.z_index=10;add_child(ui)
	sound=Sound.new();sound.enabled=not testing or "--audio-smoke" in OS.get_cmdline_user_args();add_child(sound)
	build_ui()
	load_game()
	if testing and "--audio-smoke" not in OS.get_cmdline_user_args(): sound.enabled=false;sound.refresh()
	show_title()
	if "--self-test" in OS.get_cmdline_user_args(): call_deferred("run_tests")
	elif "--ui-test" in OS.get_cmdline_user_args(): call_deferred("run_ui_tests")
	elif "--capture" in OS.get_cmdline_user_args(): call_deferred("capture_preview")
	elif "--playthrough-test" in OS.get_cmdline_user_args() or "--full-story-test" in OS.get_cmdline_user_args(): call_deferred("full_playthrough")
	elif "--audio-smoke" in OS.get_cmdline_user_args(): call_deferred("audio_smoke")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: request_quit()

func request_quit() -> void:
	if quitting: return
	quitting=true
	if v2_started: save_game()
	sound.enabled=false;sound.stop_all()
	# Let the audio mixing thread release active playback before tree teardown.
	await get_tree().create_timer(.15).timeout
	get_tree().quit()

func audio_smoke() -> void:
	await get_tree().create_timer(.4).timeout
	print("AUDIO SMOKE: streams loaded=",sound.clips.size()," rain playing=",sound.rain.playing," drone playing=",sound.drone.playing)
	request_quit()

func full_playthrough() -> void:
	await preload("res://scripts/playthrough_test.gd").run(self)

func button_at(parent: Node, text: String, rect: Rect2, callback: Callable, quiet: bool = false) -> Button:
	var b:=Button.new()
	b.text=text
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",Color("e5ddc9"))
	b.add_theme_color_override("font_hover_color",Color("fff1be"))
	b.add_theme_stylebox_override("normal",box_style("101a1de8" if not quiet else "101a1d00","5d675d" if not quiet else "53675966"))
	b.add_theme_stylebox_override("hover",box_style("384c44ee","d5bc80"))
	b.add_theme_stylebox_override("pressed",box_style("576653ee","e9d7a0"))
	b.add_theme_stylebox_override("focus",box_style("00000000","c9b87e",2))
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): sound.play("click");callback.call())
	parent.add_child(b)
	b.position=rect.position;b.size=rect.size
	return b

func shade(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var c:=ColorRect.new();c.color=color;c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(c);c.position=rect.position;c.size=rect.size
	return c

func build_ui() -> void:
	shade(ui,Rect2(0,0,1280,94),Color("0b1214b8"))
	shade(ui,Rect2(0,652,1280,68),Color("0b1214e8"))
	label_at(ui,"启 动 阶 段",Rect2(34,19,200,28),19,"e4d6ae")
	scene_title=label_at(ui,"",Rect2(34,45,550,45),25,"f2e6c8")
	objectives=label_at(ui,"",Rect2(485,22,474,52),16,"c8d4c7")
	button_at(ui,"案 卷  [ J ]",Rect2(983,24,143,44),show_journal,true)
	button_at(ui,"暂 停",Rect2(1142,24,104,44),show_pause,true)
	button_at(ui,"07号公寓",Rect2(34,667,148,36),func(): enter_scene("apartment"),true)
	button_at(ui,"维修走廊",Rect2(195,667,148,36),func(): enter_scene("corridor"),true)
	button_at(ui,"居民档案室",Rect2(356,667,164,36),func(): enter_scene("archive"),true)
	button_at(ui,"调查提示",Rect2(1023,667,103,36),show_hint,true)
	button_at(ui,"热点 [H]",Rect2(1140,667,106,36),func(): hotspots_visible=not hotspots_visible;queue_redraw(),true)
	status_tag=label_at(ui,"",Rect2(570,672,420,26),14,"aebfb4")
	toast_panel=panel_at(self,Rect2(740,8,516,72),"162c28")
	toast_panel.z_index=100;toast_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;toast_panel.modulate.a=0
	shade(toast_panel,Rect2(0,0,6,72),Color("d5b775"))
	label_at(toast_panel,"案卷更新 / FIELD NOTES",Rect2(20,7,479,24),20,"a3b5a3")
	toast_label=label_at(toast_panel,"",Rect2(20,36,479,29),20,"ecd49b")
	tooltip=label_at(ui,"",Rect2(32,605,1216,36),19,"eee2bc")
	tooltip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tooltip.add_theme_constant_override("outline_size",6)
	tooltip.add_theme_color_override("font_outline_color",Color("0a1217"))
	footer=status_tag

func _process(delta: float) -> void:
	phase_time+=delta
	if toast_life>0:
		toast_life-=delta
		toast_panel.modulate.a=clampf(toast_life,0,1)
	if dialog_mode and is_instance_valid(dialog_text):
		typing_elapsed+=delta
		dialog_text.visible_characters=int(typing_elapsed*38) if typewriter else -1
	tooltip.text=hover_name if not hover_name.is_empty() else ("点击人物交谈 · 点击场景调查 · 按 H 显示热点" if not is_instance_valid(modal) else "")
	queue_redraw()

func _draw() -> void:
	if not title_mode and ui.visible:
		if scene_id=="apartment":
			draw_rect(Rect2(852,208,36,48),Color("4e4939"));draw_rect(Rect2(852,208,32,44),Color("b1a581"))
			draw_rect(Rect2(876,208,8,8),Color("787058"));draw_rect(Rect2(856,224,20,4),Color("6d6652"));draw_rect(Rect2(856,236,12,4),Color("6d6652"))
			draw_rect(Rect2(580,376,40,4),Color("8d917d"));draw_rect(Rect2(584,368,28,8),Color("987047"))
			draw_rect(Rect2(588,364,20,4),Color("423b2d"));draw_rect(Rect2(592,368,12,4),Color("b28c5b"))
		elif scene_id=="corridor":
			draw_rect(Rect2(462,349,52,64),Color("b9b695"));draw_rect(Rect2(470,361,36,4),Color("775345"));draw_rect(Rect2(470,377,28,4),Color("775345"))
		elif scene_id=="archive":
			draw_rect(Rect2(828,382,84,28),Color("908c66"));draw_rect(Rect2(836,390,36,8),Color("c9c2a0"))
	if title_mode:
		# Sparse animated rain over the title environment; the source artwork stays intact.
		for i in 68:
			var x: float=fposmod(i*137.2-phase_time*29,1280)
			var y: float=fposmod(i*71.3+phase_time*325,720)
			draw_line(Vector2(x,y),Vector2(x-3,y+12),Color(0.6,0.78,0.82,0.12),1)
	elif hotspots_visible and not is_instance_valid(modal):
		for key in interaction_targets:
			var p: Vector2=interaction_targets[key]
			draw_circle(p,4,Color("edd5a2"))
			draw_arc(p,9,0,TAU,20,Color("b99b6266"),1)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(opening_layer):
		if opening_layer.handle_key(event): get_viewport().set_input_as_handled()
		return
	if choice_locked: return
	if event.keycode==KEY_ESCAPE:
		if dialog_mode: advance_dialog()
		elif choice_locked: return
		elif is_instance_valid(modal) and not title_mode: close_modal()
		elif not title_mode: show_pause()
	elif event.keycode in [KEY_SPACE,KEY_ENTER] and dialog_mode: advance_dialog()
	elif event.keycode==KEY_J and not title_mode and not dialog_mode: show_journal()
	elif event.keycode in [KEY_H,KEY_TAB] and not title_mode:
		hotspots_visible=not hotspots_visible
	elif event.keycode==KEY_M:
		sound.enabled=not sound.enabled;sound.refresh();toast("声音已开启" if sound.enabled else "声音已静音");save_game()
	elif event.keycode==KEY_F11:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toast(text: String) -> void:
	toast_label.text=text;toast_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	toast_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	toast_panel.modulate.a=1;toast_life=5.2

func set_background(key: String) -> void:
	if backgrounds.has(key): background.texture=backgrounds[key]
	sound.scene_mix(key)

func show_title() -> void:
	clear_opening()
	clear_horizon()
	close_modal();clear_hotspots();active_people.clear();title_mode=true;ui.hide()
	set_background("street")
	overlay=Control.new();overlay.z_index=50;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	shade(overlay,Rect2(0,0,665,720),Color("081217a8"))
	label_at(overlay,"A CASE OF TWO LIVES",Rect2(83,94,620,32),16,"adc0ba")
	label_at(overlay,"启动阶段",Rect2(77,151,690,105),74,"eee1bf")
	label_at(overlay,"第一章    /    睡过头的人",Rect2(86,282,590,44),26,"d5b982")
	label_at(overlay,"一个人醒了。\n另一个人没有。",Rect2(87,353,495,97),24,"cad4c9")
	var start:=button_at(overlay,"继续调查   →" if v2_started else "开始调查   →",Rect2(84,484,326,54),func():
		if v2_started: resume_chapter()
		else: start_new())
	test_ui_nodes["start"]=start
	button_at(overlay,"重新开始",Rect2(84,555,146,40),confirm_new_game,true)
	button_at(overlay,"设置",Rect2(244,555,80,40),show_settings,true)
	button_at(overlay,"退出",Rect2(338,555,72,40),request_quit,true)
	label_at(overlay,"鼠标调查  ·  J 案卷  ·  H 热点  ·  M 静音  ·  F11 全屏",Rect2(84,657,810,27),14,"91aaa5")
	label_at(overlay,"CHAPTER EDITION  0.4",Rect2(998,670,254,25),13,"acc1b7")

func start_new() -> void:
	reset_game();v2_started=true;intro_done=false;title_mode=false;ui.show()
	enter_scene("apartment",false)
	set_background("street");actors.hide();ui.hide()
	pending_event="opening";save_game()
	show_opening()

func clear_opening() -> void:
	if is_instance_valid(opening_layer):
		remove_child(opening_layer)
		opening_layer.queue_free()
	opening_layer=null

func show_opening() -> void:
	clear_opening()
	close_modal();clear_hotspots();actors.hide();ui.hide()
	title_mode=false;pending_event="opening"
	opening_layer=Opening.new()
	add_child(opening_layer)
	opening_layer.completed.connect(func():
		clear_opening()
		arrival_scene())
	opening_layer.begin(self)

func confirm_new_game() -> void:
	new_modal("重新开始这一章")
	label_at(modal,"将覆盖新版的当前调查进度。\n旧版样机存档仍然保留。",Rect2(32,128,796,140),26)
	button_at(modal,"返回",Rect2(32,428,350,52),show_title)
	button_at(modal,"确认重新开始",Rect2(414,428,430,52),start_new)

func reset_game() -> void:
	evidence=[];flags={};seen_topics=[];claims=[];court_step=0;verdict=0;completed=false;identity_choice="";scene_id="apartment";intro_done=false;hint_level=0
	observations=[];decisions={};pending_event="";choice_locked=false

func enter_scene(key: String, persist: bool = true) -> void:
	if not SCENE_NAMES.has(key): return
	clear_horizon()
	close_modal();clear_hotspots();active_people.clear();pending_interaction=""
	scene_id=key;title_mode=false;ui.show();v2_started=true;session_started=true
	actors.show()
	set_background(key)
	scene_title.text=SCENE_NAMES[key]
	hero=actor_at(0,172,2.65)
	hero.footstep.connect(func(): sound.play("step"))
	hero.arrived.connect(func():
		if not pending_interaction.is_empty():
			var pending_key: String=pending_interaction;pending_interaction="";perform_interaction(pending_key))
	if key=="apartment":
		active_people.su=actor_at(6,434,2.48)
		active_people.song=actor_at(7,906,2.68)
		hotspot("与苏筠交谈",Rect2(375,292,124,306),"su")
		hotspot("与宋屿交谈",Rect2(846,286,125,312),"song")
		hotspot("桌面日历",Rect2(594,295,64,66),"calendar")
		hotspot("两杯茶",Rect2(455,316,90,60),"tea")
		hotspot("旧抽屉",Rect2(1030,352,117,125),"drawer")
		hotspot("窗边的照片",Rect2(731,93,154,139),"photo")
		hotspot("照片后的租约",Rect2(848,202,48,61),"lease")
		hotspot("茶盘里的面包角",Rect2(563,350,88,47),"bread")
	elif key=="corridor":
		active_people.shao=actor_at(8,764,2.7)
		hotspot("与邵为交谈",Rect2(702,280,125,318),"shao")
		hotspot("维修公告板",Rect2(393,171,232,150),"order")
		hotspot("维修门 / 签收簿",Rect2(781,184,96,86),"access")
		hotspot("敲门询问值班邻居",Rect2(199,210,88,181),"neighbor")
		hotspot("居民须知",Rect2(880,255,38,62),"notice")
		hotspot("公告板下的续期单",Rect2(425,344,155,89),"pressure")
	else:
		active_people.wen=actor_at(2,713,2.55)
		hotspot("与闻遥交谈",Rect2(652,294,125,306),"wen")
		hotspot("恢复记录终端",Rect2(172,330,99,90),"terminal")
		hotspot("独立审计柜",Rect2(1002,316,115,183),"receipt")
		hotspot("姓名档案盒",Rect2(432,230,286,101),"names")
		hotspot("Q-17 授权文件夹",Rect2(812,351,131,88),"consent")
	refresh_evidence()
	if persist: save_game()
	if not testing:
		background.modulate=Color(0.6,0.65,0.65,1)
		create_tween().tween_property(background,"modulate",Color.WHITE,0.45)

func actor_at(id: int, x: float, scale_value: float = 2.0):
	var a=Rig.new();a.character_id=id;a.position=Vector2(x,592);a.scale=Vector2.ONE*scale_value*1.85;a.speed=28
	actors.add_child(a)
	return a

func hotspot(text: String, rect: Rect2, key: String) -> void:
	var b:=Button.new()
	b.flat=true;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	b.pressed.connect(func(): interact(key))
	b.mouse_entered.connect(func(): hover_name=text;hover_position=rect.get_center())
	b.mouse_exited.connect(func(): hover_name="")
	ui.add_child(b);b.position=rect.position;b.size=rect.size
	scene_buttons.append(b);interaction_targets[key]=rect.get_center()
	test_ui_nodes[key]=b

func interact(key: String) -> void:
	if is_instance_valid(modal): return
	if testing and not simulate_walk: perform_interaction(key);return
	if is_instance_valid(hero) and interaction_targets.has(key):
		pending_interaction=key
		hero.walk_to(clampf(interaction_targets[key].x-68,90,1170))
	else: perform_interaction(key)

func perform_interaction(key: String) -> void:
	if Chapter.OBSERVATIONS.has(key): investigate_side(key);return
	if key in ["su","song"] and truth_ready() and not flags.get("truth",false): truth_scene();return
	if is_instance_valid(hero): hero.action="inspect" if not Story.TOPICS.has(key) else "talk"
	if Story.TOPICS.has(key):
		if key=="shao" and claims.size()==3 and court_step<3: show_confrontation()
		elif key=="song" and court_step==3 and not completed: show_identity()
		else: show_topics(key)
		return
	match key:
		"calendar": collect("calendar",false);show_object(key)
		"drawer":
			if flags.get("drawer",false): show_object("note")
			else: show_lock()
		"terminal": show_terminal()
		"order": collect("order",false);show_object(key)
		"access": flags.ledger=true;maybe_access();save_game();show_object(key)
		"neighbor":
			start_dialog([["值班邻居 · 门后","两点十四，是邵为自己来拿的。四十一分也是他。工牌我看过，没有别人替。"],["林砚","有人中途再领过一份吗？"],["值班邻居 · 门后","没有。我一直在门边织围巾。他还嫌我的灯太亮。"]],func(): flags.neighbor=true;maybe_access();save_game();investigate_side("stretcher"))
		"receipt":
			if "restore" not in evidence: start_dialog([["闻遥","先查恢复终端，确认时间线。我才能调出相应的独立回执。"]])
			else: collect("receipt",false);show_object(key)
		_: show_object(key)

func show_topics(person: String) -> void:
	new_modal(TOPIC_NAMES[person]+"  /  询问")
	add_portrait(modal,PERSON_IDS[person],Rect2(30,84,192,388))
	label_at(modal,TOPIC_BLURBS[person],Rect2(250,82,580,76),21,"cbbd9b")
	var y: float=167
	for topic in Story.TOPICS[person]:
		var seen: bool=(person+"/"+topic[0]) in seen_topics
		button_at(modal,("✓  " if seen else "·  ")+topic[1],Rect2(248,y,590,54),func(): choose_topic(person,topic[0]),true)
		y+=59
	if person in ["su","song"] and flags.get("truth",false):
		button_at(modal,"谈谈明天的安排" if not decisions.has("future") else "再听一次明天的安排",Rect2(248,405,590,43),future_scene,true)
	elif person=="shao" and flags.get("custody",false):
		button_at(modal,"封存之后，你还有什么要说？",Rect2(248,405,590,43),func(): start_dialog([["邵为","我没被允许把封条揭下来。第一次，记录比我的解释留得久。"],["林砚","你仍然可以补充陈述。封存权限不是抹掉你的声音。"]]),true)
	elif person=="wen" and flags.get("truth",false):
		button_at(modal,"当事人已经知道了",Rect2(248,405,590,43),func(): start_dialog([["闻遥","记录可以证明先后，不能替他们哀悼。谢谢你回去讲清楚。"],["林砚","也谢谢你把两个人分开编号。"]]),true)
	button_at(modal,"暂时问到这里",Rect2(552,458,286,44),close_modal)

func choose_topic(person: String, key: String) -> void:
	for topic in Story.TOPICS[person]:
		if topic[0]==key:
			var lines: Array=topic[2]
			var context_key: String=person+"/"+key
			if flags.get("truth",false) and Chapter.AFTER_TRUTH.has(context_key): lines=Chapter.AFTER_TRUTH[context_key]
			if flags.get("custody",false) and Chapter.AFTER_CUSTODY.has(context_key): lines=Chapter.AFTER_CUSTODY[context_key]
			if context_key=="wen/records" and "order" in evidence:
				lines=[["闻遥","M-204 已经建立查询索引。终端留存恢复登记，审计柜核对签署者。时点与保管区间在现场台统一核验。"],["林砚","两边各留一份，不能让摘要替代原始记录。"]]
			start_dialog(lines,func():
				var seen_key: String=person+"/"+key
				if seen_key not in seen_topics: seen_topics.append(seen_key)
				if person=="song" and key=="memory": collect("testimony",false)
				if person=="shao" and key=="credential": flags.credential=true;maybe_access()
				save_game();show_topics(person))
			return

func maybe_access() -> void:
	if flags.get("ledger",false) and flags.get("neighbor",false) and flags.get("credential",false): collect("access",false)

func start_dialog(lines: Array, callback: Callable = Callable()) -> void:
	close_modal()
	if is_instance_valid(hero): hero.set_process(false)
	current_lines=lines.duplicate(true);line_index=0;after_dialog=callback;dialog_mode=true
	overlay=Control.new();overlay.z_index=60;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	shade(overlay,Rect2(0,0,1280,720),Color("07131844"))
	modal=panel_at(overlay,Rect2(46,425,1188,254),"101b1af5")
	render_dialog_line()

func render_dialog_line() -> void:
	if pending_event=="truth" and decisions.get("truth")=="first" and active_people.has("su"):
		active_people.su.visible=line_index>=4
	for child in modal.get_children(): modal.remove_child(child);child.queue_free()
	var line: Array=current_lines[line_index]
	var who: String=line[0]
	if PERSON_IDS.has(who): add_portrait(modal,PERSON_IDS[who],Rect2(15,-77,148,285))
	else:
		label_at(modal,"···" if "旁白" in who else "—",Rect2(46,53,100,84),40,"82998e")
	label_at(modal,who,Rect2(187,20,835,36),24,"e0c78e")
	shade(modal,Rect2(185,58,952,2),Color("52695c"))
	shade(modal,Rect2(168,22,4,149),Color("c3a768"))
	dialog_text=label_at(modal,line[1],Rect2(187,74,952,120),24,"ebe3cf")
	dialog_text.add_theme_constant_override("line_spacing",5)
	typing_elapsed=0
	dialog_text.visible_characters=0 if typewriter else -1
	button_at(modal,"继续  →",Rect2(1012,207,145,34),advance_dialog,true)
	label_at(modal,"空格 / 点击继续    ·    "+str(line_index+1)+" / "+str(current_lines.size()),Rect2(190,209,560,30),14,"8fa69e")
	if is_instance_valid(talk_actor): talk_actor.action="idle"
	talk_actor=null
	for p in active_people:
		if TOPIC_NAMES.get(p,"")==who: talk_actor=active_people[p]
	if who=="林砚": talk_actor=hero
	if is_instance_valid(talk_actor): talk_actor.action="talk"

func advance_dialog() -> void:
	if not dialog_mode: return
	if typewriter and dialog_text.visible_characters>=0 and dialog_text.visible_characters<dialog_text.get_total_character_count():
		typing_elapsed=100;dialog_text.visible_characters=-1;return
	line_index+=1
	if line_index>=current_lines.size():
		var callback: Callable=after_dialog
		close_modal()
		if callback.is_valid(): callback.call()
	else: render_dialog_line()

func add_portrait(parent: Node, id: int, rect: Rect2) -> void:
	if id>=0 and id<12:
		var actor=Rig.new();actor.character_id=id;actor.z_index=4
		actor.position=rect.position+Vector2(rect.size.x*.5,rect.size.y-3)
		actor.scale=Vector2.ONE*(rect.size.y/62)
		parent.add_child(actor)
		return
	if not portrait: return
	var atlas:=AtlasTexture.new();atlas.atlas=portrait
	atlas.region=Rect2(Vector2(id%4,int(id/4))*portrait.get_size()/Vector2(4,3),portrait.get_size()/Vector2(4,3))
	var pic:=TextureRect.new();pic.texture=atlas;pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;pic.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic);pic.position=rect.position;pic.size=rect.size

func close_modal() -> void:
	choice_locked=false
	dialog_mode=false;current_lines=[];after_dialog=Callable()
	if is_instance_valid(talk_actor): talk_actor.action="idle"
	talk_actor=null
	super.close_modal()
	if is_instance_valid(hero):
		hero.set_process(true)
		if not hero.move_enabled: hero.action="idle"

func new_modal(title: String, wide: bool = false) -> void:
	close_modal()
	if is_instance_valid(hero): hero.set_process(false)
	overlay=Control.new();overlay.z_index=50;overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(overlay)
	shade(overlay,Rect2(0,0,1280,720),Color("071011c9"))
	modal=panel_at(overlay,Rect2(58,68,1164,592) if wide else Rect2(202,92,876,536),"15201ff5")
	label_at(modal,title,Rect2(30,20,modal.size.x-158,42),26,"e4d4ad")
	button_at(modal,"×",Rect2(modal.size.x-79,22,48,36),func():
		if title_mode: show_title()
		else: close_modal(),true)
	sound.play("paper")

func show_object(key: String) -> void:
	if not Story.OBJECTS.has(key): return
	var obj: Array=Story.OBJECTS[key]
	new_modal(obj[0])
	var paper:=panel_at(modal,Rect2(30,84,816,310),"d6ccb0")
	paper.add_theme_stylebox_override("panel",box_style("d6ccb0","a89b7f"))
	label_at(paper,obj[1],Rect2(28,24,760,270),23,"313a36")
	label_at(modal,"林砚 / "+obj[2],Rect2(30,414,802,64),18,"b4c2b1")
	button_at(modal,"收起",Rect2(652,478,194,38),close_modal,true)

func show_lock() -> void:
	new_modal("旧抽屉 · 三位日期锁")
	label_at(modal,"锁上贴着一行字：\n‘从和好的那天开始。月在前，日在后。’",Rect2(34,89,806,93),24)
	label_at(modal,"桌面日历和苏筠的回忆，能帮你找到那个日期。",Rect2(34,194,790,40),18,"aebfaf")
	var code:=LineEdit.new();code.placeholder_text="三位数字";code.max_length=3;code.alignment=HORIZONTAL_ALIGNMENT_CENTER
	code.add_theme_font_size_override("font_size",38);modal.add_child(code);code.position=Vector2(296,259);code.size=Vector2(285,70)
	var feedback:=label_at(modal,"",Rect2(34,346,806,50),20,"d4b783")
	button_at(modal,"转动锁盘",Rect2(438,424,396,54),func():
		if solve_lock(code.text): sound.play("lock");show_object("note")
		else: feedback.text="锁没有打开。日期格式是 MDD，例如三月二日写作 302。")
	button_at(modal,"协助解锁",Rect2(34,424,366,54),func():
		if "calendar" in evidence: code.text="714";feedback.text="日历是七月十四日。按 MDD 写作 714，再转动锁盘。"
		else: feedback.text="先看看桌面日历，找到被圈起的日期。")
	code.grab_focus()

func solve_lock(code: String) -> bool:
	if code.strip_edges()!="714" or "calendar" not in evidence: return false
	flags.drawer=true;collect("note",false);save_game();return true

func show_terminal() -> void:
	new_modal("恢复记录终端  /  只读检索")
	if "order" not in evidence:
		label_at(modal,"请输入住户对应的工单号。\n\n林砚：先去维修走廊，找到昨夜的工单。",Rect2(34,140,800,195),25);return
	label_at(modal,"已检索 M-204。按顺序排出：备份 → 终止 → 启动。\n点击每行循环切换记录，再核对时间线。",Rect2(34,89,800,85),22)
	var options: Array=[]
	var records: Array=["点击选择一条记录  ↻","07/17  06:12  启动现行实例  ↻","07/14  00:00  保存备份快照  ↻","07/17  02:26  终止旧实例  ↻"]
	for i in 3:
		label_at(modal,["最早","随后","最后"][i],Rect2(34,207+i*63,85,42),19,"c9b585")
		var select:=button_at(modal,records[0],Rect2(134,205+i*63,694,46),func():
			var selected: Button=options[i]
			var next: int=(int(selected.get_meta("record"))+1)%4
			selected.set_meta("record",next);selected.text=records[next])
		select.set_meta("record",0);options.append(select)
		test_ui_nodes["timeline_"+str(i)]=select
	var feedback:=label_at(modal,"",Rect2(34,397,795,45),18,"d9b68a")
	button_at(modal,"核对时间线",Rect2(462,458,365,46),func():
		if solve_terminal([options[0].get_meta("record"),options[1].get_meta("record"),options[2].get_meta("record")]): show_restore()
		else: feedback.text="先比较日期，再比较同一天的时刻。三个位置不能重复。")
	button_at(modal,"协助排序",Rect2(34,458,393,46),func():
		for i in 3: options[i].set_meta("record",[2,3,1][i]);options[i].text=records[[2,3,1][i]]
		feedback.text="14 日快照最早。17 日先终止，后启动。点击核对确认。")

func solve_terminal(order: Array) -> bool:
	if "order" not in evidence or order!=[2,3,1]: return false
	flags.timeline=true;collect("restore",false);return true

func show_restore() -> void:
	new_modal("恢复记录 · 时间线已核对")
	label_at(modal,"07/14 00:00    备份快照\n\n07/17 02:26    旧宋屿实例终止\n\n07/17 06:12    从旧快照启动现行宋屿",Rect2(34,100,790,253),25)
	label_at(modal,"闻遥：恢复发生在今天。被恢复的记忆，却停在三天前。",Rect2(34,394,800,65),20,"d1c39c")
	button_at(modal,"记录并继续",Rect2(558,471,271,40),close_modal)

func collect(key: String, show: bool = true) -> void:
	if not Data.EVIDENCE.has(key): return
	if key not in evidence:
		evidence.append(key);hint_level=0;sound.play("found");toast("已记入案卷  /  "+Data.EVIDENCE[key][0]);refresh_evidence();save_game()
	if show: show_evidence(key)

func refresh_evidence() -> void:
	if not is_instance_valid(objectives): return
	objectives.text="当前目标  /  "+current_objective()
	status_tag.text="记录 %d / 7     推论 %d / 3     自动保存" % [evidence.size(),claims.size()]

func current_objective() -> String:
	if completed: return "案件已结。可以回访现场，或从菜单重看尾声。"
	if court_step==3 and not flags.get("custody",false): return "封存执行凭据，确认案件材料的去向。"
	if court_step==3: return "回到公寓，听宋屿表达意愿并完成身份报告。"
	if truth_ready() and not flags.get("truth",false): return "回到公寓，将核实的真相告诉宋屿和苏筠。"
	if claims.size()==3: return "回到维修走廊，与邵为当面对质。"
	if evidence.size()==7: return "打开案卷，把互相支持的记录组合成推论。"
	if "testimony" not in evidence: return "分别询问当事人，确认宋屿的记忆缺口。"
	if "note" not in evidence: return "核对日历，寻找抽屉里留下的记录。"
	if "access" not in evidence: return "查清工单和凭据保管情况，询问值班邻居。"
	return "去档案室核对恢复时间线和独立执行回执。"

func show_evidence(key: String) -> void:
	if key not in evidence: return
	if key=="restore": show_restore();return
	if Story.OBJECTS.has(key): show_object(key);return
	new_modal(Data.EVIDENCE[key][0])
	label_at(modal,Data.EVIDENCE[key][2],Rect2(36,115,795,253),24)
	button_at(modal,"返回案卷",Rect2(567,457,260,47),show_journal)

func show_journal() -> void:
	if title_mode: return
	new_modal("林砚的案卷  /  事实要能支撑解释",true)
	selected_clues=[]
	label_at(modal,"选择两份互相支持的记录，形成一条可举证的推论。",Rect2(28,75,1068,42),20,"bcc8b9")
	var buttons: Dictionary={}
	for i in REQUIRED.size():
		var key: String=REQUIRED[i]
		var b:=button_at(modal,Data.EVIDENCE[key][0] if key in evidence else "",Rect2(30+(i%2)*294,136+int(i/2)*78,276,62),func():
			if key in selected_clues: selected_clues.erase(key)
			elif selected_clues.size()<2: selected_clues.append(key)
			for item in buttons:
				buttons[item].add_theme_stylebox_override("normal",box_style("65715a" if item in selected_clues else "101a1de8","d5c086" if item in selected_clues else "5d675d")))
		b.disabled=key not in evidence;buttons[key]=b
	label_at(modal,"已形成的推论",Rect2(674,135,440,34),23,"dfc993")
	button_at(modal,"现场侧记 / 人物与待办",Rect2(674,426,438,42),show_fieldnotes,true)
	var idx: int=0
	for key in Story.CLAIMS:
		label_at(modal,("✓  "+Story.CLAIMS[key].title) if key in claims else "—  尚待证据支持",Rect2(674,193+idx*78,440,52),20,"d2decc" if key in claims else "789088")
		idx+=1
	var feedback:=label_at(modal,"",Rect2(30,454,1094,50),18,"d8ba8a")
	button_at(modal,"组合这两份记录",Rect2(30,524,360,44),func():
		var result: String=combine_evidence(selected_clues)
		if result.is_empty(): feedback.text="这两份记录还不能独立支撑同一个结论。试着分别解释记忆缺口、执行人或动机。"
		else: new_modal(Story.CLAIMS[result].title);label_at(modal,Story.CLAIMS[result].body,Rect2(34,115,800,250),25);button_at(modal,"写入案卷",Rect2(526,458,300,46),show_journal))
	button_at(modal,"逐份重读证据",Rect2(412,524,334,44),show_evidence_index,true)
	button_at(modal,"返回现场",Rect2(768,524,365,44),close_modal,true)

func combine_evidence(pair: Array) -> String:
	if pair.size()!=2 or pair[0]==pair[1]: return ""
	for p in pair:
		if p not in evidence: return ""
	for key in Story.CLAIMS:
		if pair[0] in Story.CLAIMS[key].pair and pair[1] in Story.CLAIMS[key].pair:
			if key not in claims: claims.append(key);sound.play("found");hint_level=0;refresh_evidence();save_game()
			return key
	return ""

func show_evidence_index() -> void:
	new_modal("证据原文")
	for i in REQUIRED.size():
		var key: String=REQUIRED[i]
		var b:=button_at(modal,Data.EVIDENCE[key][0],Rect2(32,86+i*54,806,46),func(): show_evidence(key),true)
		b.disabled=key not in evidence

func show_confrontation() -> void:
	if claims.size()!=3: toast("先在案卷中形成三条有依据的推论。" );return
	if not flags.get("truth",false): start_dialog([["林砚","记录足够了。但苏筠和宋屿还不知道发生了什么。先回公寓，向他们说明，再使用他们的陈述。"]]);return
	if court_step>=3: enter_scene("apartment");return
	new_modal("对质  /  邵为",true)
	add_portrait(modal,8,Rect2(30,93,228,443))
	var c: Dictionary=Story.CONFRONT[court_step]
	label_at(modal,"第 %d 次追问 / 3" % [court_step+1],Rect2(294,90,784,32),16,"aebaa8")
	label_at(modal,c.line,Rect2(294,143,815,122),27)
	label_at(modal,"选择能回应这句话的推论。",Rect2(294,285,813,35),18,"c4b692")
	var feedback:=label_at(modal,"",Rect2(294,513,820,48),18,"d6b187")
	var idx: int=0
	for key in Story.CLAIMS:
		button_at(modal,Story.CLAIMS[key].title,Rect2(294,339+idx*54,815,45),func():
			if submit_claim(key):
				start_dialog(c.reply,func():
					if court_step<3: show_confrontation()
					else: custody_scene())
			else: feedback.text="这条推论没有回应他当前的说法。请针对这句话举证。")
		idx+=1

func submit_claim(key: String) -> bool:
	if not flags.get("truth",false) or claims.size()!=3 or court_step>=3 or key!=Story.CONFRONT[court_step].claim: return false
	court_step+=1;verdict=court_step;refresh_evidence();save_game();return true

func show_identity() -> void:
	if court_step<3: return
	if not flags.get("custody",false): custody_scene();return
	if "lease" in observations and "bread" in observations and not decisions.has("future"): future_scene();return
	start_dialog([["宋屿","请给我一份自己的记录。我想记得，今天是我自己选的。"],["苏筠","店铺也好，别的事也好……你不用替他答应我。"]],show_identity_form)

func show_identity_form() -> void:
	new_modal("最后一页  /  现行实例身份报告")
	label_at(modal,"旧宋屿的死亡已经记录。\n现在要决定的，是如何承认眼前这个人的生活。",Rect2(32,99,810,116),25)
	label_at(modal,"宋屿明确提出，希望为自己单列记录。",Rect2(32,238,798,62),21,"ccb98c")
	button_at(modal,"单列现行实例，保留历史联系",Rect2(32,338,811,64),func(): finish_case("independent"))
	button_at(modal,"沿用原档案，明确注明生命中断",Rect2(32,420,811,64),func(): finish_case("continued"))

func finish_case(choice: String) -> void:
	if court_step!=3 or not flags.get("truth",false) or not flags.get("custody",false) or not Story.ENDINGS.has(choice): return
	identity_choice=choice;pending_event="ending";save_game();play_epilogue()

func show_ending() -> void:
	enter_scene("apartment",false)
	new_modal("第一章 · 睡过头的人",true)
	label_at(modal,"案件已结。\n人生还没有。",Rect2(72,111,1010,142),46,"eadab5")
	label_at(modal,"七份记录 · 三条推论 · "+str(observations.size())+" 份侧记\n身份报告："+("为现行宋屿单列记录" if identity_choice=="independent" else "沿用档案并注明生命中断")+"\n"+future_summary()+" · "+("已提交清理程序调查请求" if decisions.get("report")=="system" else "本案材料已独立封存"),Rect2(74,282,1008,125),21)
	label_at(modal,"第一章结束 · 后续五章尚未制作完成\n感谢游玩《启动阶段》章节版。人物、环境与音效为本项目制作。",Rect2(74,421,1008,66),18,"a9bbae")
	button_at(modal,"回到标题",Rect2(74,517,320,49),show_title)
	button_at(modal,"回访现场",Rect2(419,517,320,49),func(): enter_scene("apartment"),true)
	button_at(modal,"人物档案",Rect2(764,517,320,49),show_cast,true)

func show_pause() -> void:
	new_modal("暂停调查")
	label_at(modal,current_objective(),Rect2(34,90,804,85),22,"c5cbb6")
	button_at(modal,"继续调查",Rect2(34,196,802,51),close_modal)
	button_at(modal,"声音与显示",Rect2(34,260,802,51),show_settings,true)
	button_at(modal,"人物档案",Rect2(34,324,389 if testing else 802,51),show_cast,true)
	if testing: button_at(modal,"开发附录 · 骨骼检视",Rect2(447,324,389,51),func(): super.show_rig_lab(),true)
	button_at(modal,"回到标题",Rect2(34,388,389,51),show_title,true)
	button_at(modal,"退出游戏",Rect2(447,388,389,51),request_quit,true)
	if completed: button_at(modal,"重看章节尾声",Rect2(34,453,802,46),play_epilogue,true)

func show_settings() -> void:
	new_modal("声音与显示")
	label_at(modal,"音量",Rect2(34,111,210,38),24)
	var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.05;slider.value=sound.level
	modal.add_child(slider);slider.position=Vector2(250,123);slider.size=Vector2(576,24)
	slider.value_changed.connect(func(value: float): sound.level=value;sound.refresh();save_game())
	var mute:=CheckButton.new();mute.text="开启环境音与交互音效";mute.button_pressed=sound.enabled
	modal.add_child(mute);mute.position=Vector2(34,203);mute.size=Vector2(790,42)
	mute.toggled.connect(func(value: bool): sound.enabled=value;sound.refresh();save_game())
	var type:=CheckButton.new();type.text="逐字显示对白（关闭可立即阅读整句）";type.button_pressed=typewriter
	modal.add_child(type);type.position=Vector2(34,274);type.size=Vector2(790,42)
	type.toggled.connect(func(value: bool): typewriter=value;save_game())
	button_at(modal,"切换全屏  /  F11",Rect2(34,351,796,52),func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN),true)
	button_at(modal,"完成",Rect2(499,452,330,49),func():
		if title_mode: show_title()
		else: close_modal())

func show_hint() -> void:
	if truth_ready() and not flags.get("truth",false):
		new_modal("调查提示 / 回到当事人身边")
		label_at(modal,"去 07 号公寓，与苏筠或宋屿交谈。\n先说明已经核实的事实，再对质。",Rect2(34,132,796,190),28)
		return
	hint_level=mini(hint_level+1,3)
	var hints: Array=[]
	if "testimony" not in evidence: hints=["先听当事人各自的说法。","宋屿说他忘记了一段时间。","与宋屿交谈，追问最后一件记得的事。"]
	elif "calendar" not in evidence: hints=["生活中的日期也可以成为证据。","有人圈起了对两人重要的一天。","检查餐桌靠右的小日历。"]
	elif "note" not in evidence: hints=["抽屉里可能留下昨夜之前的记录。","锁盘上的字和日历指向同一天。","七月十四日，按月加两位日写作 714。"]
	elif "order" not in evidence: hints=["找出昨夜是谁来维护。","走廊公告板有夜班记录。","去维修走廊，查看 M-204 工单。"]
	elif "access" not in evidence: hints=["权限不是行动，要查凭据在谁手里。","签收簿、本人说明和邻居见证需要互相核对。","看门禁簿，问邵为凭据是否外借，再敲走廊左侧邻居的门。"]
	elif "restore" not in evidence: hints=["把时间排清楚，‘恢复’才有明确含义。","档案室终端按工单查询。","先 14 日备份，再 17 日 02:26 终止，最后 06:12 启动。"]
	elif "receipt" not in evidence: hints=["现在需要知道谁签署了操作。","闻遥提到独立审计端。","查看档案室右侧有三盏灯的审计柜。"]
	elif claims.size()<3: hints=["记录需要组成能回答问题的推论。","分别解释记忆缺口、执行人和举报动机。","案卷配对：陈述＋恢复；凭据＋回执；便条＋维修单。"]
	elif court_step<3: hints=["该听听执行者如何解释了。","邵为仍在走廊。","回去与邵为交谈，针对每句话选择对应推论。"]
	else: hints=["案子之外，还留下一个人的意愿。","回公寓找宋屿。","与宋屿交谈，然后完成身份报告。"]
	new_modal("调查提示  /  "+str(hint_level)+" 级")
	label_at(modal,hints[hint_level-1],Rect2(34,132,796,190),28)
	button_at(modal,"再明确一点",Rect2(34,431,377,52),show_hint,true)
	button_at(modal,"回到调查",Rect2(438,431,394,52),close_modal)

func save_game(path: String = CHAPTER_SAVE_PATH, force_test: bool = false) -> void:
	if testing and not force_test: return
	var data: Dictionary={"version":4,"scene":scene_id,"evidence":evidence,"flags":flags,"topics":seen_topics,"claims":claims,"court":court_step,"identity":identity_choice,"completed":completed,"intro":intro_done,"started":v2_started,"audio":sound.enabled,"volume":sound.level,"typewriter":typewriter,"observations":observations,"decisions":decisions,"pending_event":pending_event}
	var f:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null: toast("保存失败，请检查存档文件夹权限。" );return
	f.store_string(JSON.stringify(data));f.close()
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: toast("保存失败，当前进度暂未写入磁盘。")

func apply_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version")!=4 or not data.get("evidence") is Array: return false
	reset_game()
	for key in data.evidence:
		if key is String and Data.EVIDENCE.has(key) and key not in evidence: evidence.append(key)
	var input_flags: Variant=data.get("flags",{})
	if input_flags is Dictionary:
		for key in ["drawer","timeline","ledger","neighbor","credential"]: flags[key]=input_flags.get(key)==true
		flags.truth=input_flags.get("truth")==true and truth_ready()
	var input_topics: Variant=data.get("topics",[])
	if input_topics is Array:
		for person in Story.TOPICS:
			for t in Story.TOPICS[person]:
				if person+"/"+t[0] in input_topics: seen_topics.append(person+"/"+t[0])
	var input_claims: Variant=data.get("claims",[])
	if input_claims is Array:
		for key in Story.CLAIMS:
			if key in input_claims and Story.CLAIMS[key].pair[0] in evidence and Story.CLAIMS[key].pair[1] in evidence: claims.append(key)
	scene_id=str(data.get("scene","apartment"))
	if not SCENE_NAMES.has(scene_id): scene_id="apartment"
	var court: Variant=data.get("court",0)
	court_step=clampi(int(court),0,3) if (court is float or court is int) and claims.size()==3 and flags.get("truth",false) else 0
	flags.custody=input_flags is Dictionary and input_flags.get("custody")==true and court_step==3
	var input_observations: Variant=data.get("observations",[])
	if input_observations is Array:
		for key in Chapter.OBSERVATIONS:
			if key in input_observations: observations.append(key)
	var input_decisions: Variant=data.get("decisions",{})
	if input_decisions is Dictionary:
		if input_decisions.get("truth") in ["together","first"]: decisions.truth=input_decisions.truth
		if input_decisions.get("future") in ["breakfast","space"] and "lease" in observations and "bread" in observations and flags.get("truth",false): decisions.future=input_decisions.future
		if input_decisions.get("report") in ["case","system"] and flags.custody:
			decisions.report="system" if input_decisions.report=="system" and "pressure" in observations and "consent" in observations else "case"
	identity_choice=str(data.get("identity",""));completed=data.get("completed")==true and flags.custody and Story.ENDINGS.has(identity_choice)
	pending_event=str(data.get("pending_event",""))
	if pending_event not in ["opening","arrival","truth","future","custody","ending"]: pending_event=""
	if pending_event=="truth" and (not truth_ready() or flags.get("truth",false)): pending_event=""
	if pending_event=="future" and (not flags.get("truth",false) or "lease" not in observations or "bread" not in observations): pending_event=""
	if pending_event=="ending" and (not flags.custody or not Story.ENDINGS.has(identity_choice)): pending_event=""
	if pending_event=="custody" and court_step!=3: pending_event=""
	intro_done=data.get("intro")==true;v2_started=data.get("started")==true
	sound.enabled=data.get("audio",true)==true and not testing
	var volume: Variant=data.get("volume",.55)
	sound.level=clampf(float(volume),0,1) if volume is float or volume is int else .55
	typewriter=data.get("typewriter",true)==true;sound.refresh();refresh_evidence();return true

func load_game() -> void:
	if testing or not FileAccess.file_exists(CHAPTER_SAVE_PATH): return
	if not apply_save(JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_SAVE_PATH))): toast("新版存档无法识别，已保留原文件。")

func artifact_path(filename: String) -> String:
	if OS.has_feature("editor"): return "res://build/v4/"+filename
	return OS.get_executable_path().get_base_dir().path_join(filename)

func truth_ready() -> bool:
	return "restore" in evidence and "receipt" in evidence and "testimony" in evidence

func finish_event() -> void:
	pending_event="";refresh_evidence();save_game()

func resume_chapter() -> void:
	if pending_event=="opening": show_opening();return
	enter_scene(scene_id,false)
	match pending_event:
		"arrival": arrival_scene()
		"truth": truth_scene()
		"future": future_scene()
		"custody": custody_scene()
		"ending": play_epilogue()
		_:
			if not intro_done: arrival_scene()
			elif court_step==3 and not flags.get("custody",false): custody_scene()

func arrival_scene() -> void:
	enter_scene("apartment",false);pending_event="arrival";save_game()
	start_dialog(Chapter.ARRIVAL,func(): intro_done=true;finish_event();toast("先与苏筠和宋屿分别交谈。按 H 可显示调查热点。"))

func investigate_side(key: String) -> void:
	if key=="consent" and "order" not in evidence:
		start_dialog([["闻遥","先确认昨夜的工单编号，我才能找到对应授权。"]]);return
	var item: Array=Chapter.OBSERVATIONS[key]
	start_dialog(item[2],func():
		if key not in observations: observations.append(key);sound.play("found");toast("已记入现场侧记 / "+item[0])
		refresh_evidence();save_game();show_observation(key))

func show_observation(key: String) -> void:
	var item: Array=Chapter.OBSERVATIONS[key]
	new_modal("现场侧记 / "+item[0])
	label_at(modal,item[1],Rect2(34,109,800,240),25)
	label_at(modal,"侧记保留人物经历与待核实问题，不直接代替定案证据。",Rect2(34,367,800,72),18,"b6bfa7")
	button_at(modal,"收起侧记",Rect2(526,458,300,46),close_modal)

func future_summary() -> String:
	match decisions.get("future",""):
		"breakfast": return "两人约好试一次早餐"
		"space": return "租约暂缓，各自保留选择"
	return "两人的明天尚未商量"

func show_fieldnotes() -> void:
	new_modal("现场侧记 / 案子里的人",true)
	label_at(modal,"支线调查",Rect2(30,85,480,34),23,"d9c89b")
	var idx: int=0
	for key in Chapter.OBSERVATIONS:
		var b:=button_at(modal,Chapter.OBSERVATIONS[key][0] if key in observations else "",Rect2(30,136+idx*69,514,53),func(): show_observation(key),true)
		b.disabled=key not in observations;idx+=1
	label_at(modal,"人物关系与选择",Rect2(594,85,515,34),23,"d9c89b")
	var relation: String="苏筠记得和好的三天，宋屿的记忆停在那之前。"
	if flags.get("truth",false): relation="苏筠知道失去的是谁；宋屿同意将自己的完整陈述用于对质。"
	var delivery: String="尚未告知核实结果" if not flags.get("truth",false) else ("宋屿先知情，并亲自邀请苏筠" if decisions.get("truth")=="first" else "两人一起听取真相")
	label_at(modal,relation+"\n\n"+delivery+"\n\n"+future_summary()+"\n\n"+("追加调查：清理程序与资格续期" if decisions.get("report")=="system" else "追加调查尚未提出"),Rect2(594,141,512,267),21)
	label_at(modal,"待办："+current_objective(),Rect2(594,422,510,84),18,"ccb888")
	button_at(modal,"返回证据页",Rect2(30,524,514,44),show_journal)
	button_at(modal,"回到现场",Rect2(594,524,514,44),close_modal,true)

func lock_choices() -> void:
	choice_locked=true
	for child in modal.get_children():
		if child is Button and child.text=="×": modal.remove_child(child);child.queue_free()

func truth_scene() -> void:
	if not truth_ready(): return
	enter_scene("apartment",false);pending_event="truth";save_game()
	new_modal("把真相交还当事人")
	label_at(modal,"终止和恢复的时间已经核实。\n现在，他们有权知道这两条记录意味着什么。",Rect2(34,105,800,130),26)
	label_at(modal,"决定的是谈话顺序。两人都会获知完整事实。",Rect2(34,248,800,57),19,"bfc7b3")
	button_at(modal,"请两人一起听取结果",Rect2(34,337,800,61),func(): deliver_truth("together"))
	button_at(modal,"先让宋屿知情，由他邀请苏筠",Rect2(34,421,800,61),func(): deliver_truth("first"))
	lock_choices()

func deliver_truth(mode: String) -> void:
	if not truth_ready() or mode not in ["together","first"]: return
	decisions.truth=mode;save_game()
	start_dialog((Chapter.TRUTH_FIRST if mode=="first" else Chapter.TRUTH_TOGETHER)+Chapter.TRUTH_AFTER,func():
		flags.truth=true;finish_event();toast("当事人已知情。可继续调查生活支线，或准备对质。"))

func future_scene() -> void:
	if not flags.get("truth",false): return
	if "lease" not in observations or "bread" not in observations:
		start_dialog([["苏筠","照片后面还有那份租约。桌上也有他今早第一次烤的面包。"],["宋屿","先看看这些，再谈以后吧。"]]);return
	if decisions.has("future"):
		start_dialog(Chapter.FUTURE_REPLY[decisions.future]);return
	pending_event="future";save_game()
	start_dialog(Chapter.FUTURE,func():
		new_modal("明天，不必一次决定一生")
		label_at(modal,"你可以提出一个开头。\n两个人会分别回答，而非由报告替他们承诺。",Rect2(34,109,800,158),26)
		button_at(modal,"提议试一次早餐，不等于答应开店",Rect2(34,337,800,61),func(): choose_future("breakfast"))
		button_at(modal,"提议暂缓租约，留出各自考虑的时间",Rect2(34,421,800,61),func(): choose_future("space"))
		lock_choices())

func choose_future(value: String) -> void:
	if value not in ["breakfast","space"] or not flags.get("truth",false) or "lease" not in observations or "bread" not in observations: return
	start_dialog(Chapter.FUTURE_REPLY[value],func():
		decisions.future=value;finish_event()
		if court_step==3: show_identity())

func custody_scene() -> void:
	if court_step!=3: return
	enter_scene("corridor",false);pending_event="custody";save_game()
	start_dialog(Chapter.CUSTODY,func():
		new_modal("封存之后 / 调查请求")
		label_at(modal,"本案证据将完整移交，邵为的执行责任已经记录。\n是否同时提出对清理程序的独立调查请求？",Rect2(34,109,800,131),25)
		label_at(modal,"追加请求需调查：续期单 ＋ Q-17 本次授权。\n这不会减轻或替代邵为对本案的责任。",Rect2(34,251,800,69),18,"c7b990")
		button_at(modal,"封存本案，先交清楚已核实的事实",Rect2(34,337,800,61),func(): choose_report("case"))
		var extra:=button_at(modal,"附上材料，请求调查清理程序与资格续期",Rect2(34,421,800,61),func(): choose_report("system"))
		extra.disabled="pressure" not in observations or "consent" not in observations
		lock_choices())

func choose_report(value: String) -> void:
	if court_step!=3 or value not in ["case","system"]: return
	if value=="system" and ("pressure" not in observations or "consent" not in observations): return
	start_dialog([["闻遥 · 通话","收到。将材料另立调查索引，结果出来前不把请求当作结论。" if value=="system" else "收到。本案原件进入独立保管，双方都可申请核对记录。"],["林砚","还有两个人在等。我回去，把能确定的事告诉他们。"]],func():
		decisions.report=value;flags.custody=true;finish_event();enter_scene("apartment");toast("与宋屿交谈，完成身份报告。"))

func epilogue_lines() -> Array:
	var lines: Array=Story.ENDINGS[identity_choice].duplicate(true)
	if decisions.get("truth")=="first": lines.append(["苏筠","谢谢你让他自己开那扇门。我想记住的是他邀请我，不是有人通知我。"])
	else: lines.append(["宋屿","刚才我们一起听完，没有谁被留在门外。这件事，我会记得。"])
	match decisions.get("future",""):
		"breakfast": lines.append(["旁白","苏筠把租约收入抽屉，宋屿在面包配方旁写下新的温度。明早只有早餐，没有开业。"])
		"space": lines.append(["旁白","租约旁多了一张延期申请。两人各留了一把钥匙，没有约定必须同一时间回来。"])
		_: lines.append(["旁白","那份没有签完的租约还在照片后面。他们没有谈明天，林砚也没有替他们写下答案。"])
	lines.append(["闻遥 · 留言","程序调查已登记，等待逐项核实。邵为的本案记录另行保留。" if decisions.get("report")=="system" else "本案原件已封存。死亡记录与新实例记录分别保留，恢复不再被当成撤案理由。"])
	return lines

func play_epilogue() -> void:
	if not Story.ENDINGS.has(identity_choice): return
	enter_scene("apartment",false)
	if not completed: pending_event="ending";save_game()
	start_dialog(epilogue_lines(),show_horizon)

func clear_horizon() -> void:
	if is_instance_valid(horizon_layer): remove_child(horizon_layer);horizon_layer.queue_free()
	horizon_layer=null

func show_horizon() -> void:
	close_modal();clear_hotspots();ui.hide();actors.hide();set_background("street")
	clear_horizon()
	horizon_layer=Control.new();horizon_layer.z_index=3;horizon_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(horizon_layer)
	# Dissolve only the distant street, keeping the near buildings and the
	# character on the same 320 x 180 world grid as the approved artwork.
	var distance_view:=TextureRect.new();distance_view.texture=backgrounds.street
	distance_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;distance_view.size=Vector2(1280,720)
	distance_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
uniform float reveal : hint_range(0.0,1.0) = 1.0;
void fragment(){
 vec2 p=(floor(UV*vec2(320.,180.))+vec2(.5))/vec2(320.,180.);
 vec4 source=texture(TEXTURE,p);
 float depth=clamp((p.y-.04)/.72,0.,1.);
 float left=mix(.14,.38,depth*depth);
 float right=mix(.535,.445,depth*depth);
 float region=step(left,p.x)*step(p.x,right)*step(p.y,.76);
 float band=floor(p.y*12.)/12.;
 vec3 empty=mix(vec3(.31,.37,.36),vec3(.48,.52,.47),band);
 float frontier=step(.004,abs(p.x-left))*step(.004,abs(p.x-right));
 empty=mix(vec3(.59,.62,.49),empty,frontier);
 float wipe=1.-smoothstep(reveal-.08,reveal,p.y);
 COLOR=vec4(mix(source.rgb,empty,region*wipe),source.a);
}"""
	var material:=ShaderMaterial.new();material.shader=shader;distance_view.material=material
	horizon_layer.add_child(distance_view)
	if not testing:
		material.set_shader_parameter("reveal",0.0)
		create_tween().tween_method(func(v: float): material.set_shader_parameter("reveal",v),0.0,1.0,2.4)
	shade(horizon_layer,Rect2(0,0,1280,44),Color("081311"))
	shade(horizon_layer,Rect2(807,92,400,84),Color("0c1819e8"))
	label_at(horizon_layer,"维护广播 / 远景区块 07",Rect2(827,104,365,29),19,"c9c9a6")
	label_at(horizon_layer,"远景未加载 · 居民区域持续运行",Rect2(827,143,365,26),15,"96b5ac")
	var silhouette=Rig.new();silhouette.character_id=0;silhouette.position=Vector2(345,617);silhouette.scale=Vector2.ONE*4.9;horizon_layer.add_child(silhouette)
	start_dialog(Chapter.HORIZON,func():
		new_modal("街道尽头 / 维护窗口")
		label_at(modal,"灰色平面没有透视，也没有雨。\n广播称它为‘尚未加载的区块’。",Rect2(34,112,800,169),27)
		button_at(modal,"查看维护窗口与清理附页",Rect2(34,385,800,78),func():
			start_dialog(Chapter.REVEAL,func(): completed=true;finish_event();ui.show();show_ending()))
		lock_choices())

func drain_dialog() -> void:
	var loops: int=0
	while dialog_mode and loops<80:
		typing_elapsed=100;dialog_text.visible_characters=-1;advance_dialog();loops+=1

func run_tests() -> void:
	typewriter=false
	start_new()
	check(is_instance_valid(opening_layer) and pending_event=="opening","new game opens story context before investigation")
	opening_layer.finish();drain_dialog()
	check(intro_done,"intro completes into playable scene")
	check(not solve_lock("714"),"drawer requires observed calendar")
	perform_interaction("calendar");close_modal()
	check(not solve_lock("123"),"wrong lock code rejected")
	check(solve_lock("714"),"calendar date opens drawer")
	choose_topic("song","memory");drain_dialog();close_modal()
	check("testimony" in evidence,"dialogue grants memory testimony")
	enter_scene("corridor",false);perform_interaction("order");close_modal()
	var inspector=get("field")
	if inspector!=null:
		inspector.task("c1b").steps[0].values=[0]
		check(inspector.certify("c1b",0),"matching insurance chip restores authorized door access")
	perform_interaction("access");close_modal()
	check("access" not in evidence,"ledger alone does not prove custody")
	choose_topic("shao","credential");drain_dialog();close_modal()
	perform_interaction("neighbor");drain_dialog()
	check("access" in evidence,"ledger witness and custody triangulated")
	enter_scene("archive",false)
	perform_interaction("receipt");drain_dialog()
	check("receipt" not in evidence,"audit requires identified timeline")
	check(not solve_terminal([1,2,3]),"wrong timeline rejected")
	check(solve_terminal([2,3,1]),"chronological records resolve timeline")
	perform_interaction("receipt");close_modal()
	check(evidence.size()==7,"seven core records all reachable")
	check(combine_evidence(["order","calendar"]).is_empty(),"unsupported evidence combination rejected")
	check(combine_evidence(["order","order"]).is_empty(),"duplicate combination rejected")
	for key in Story.CLAIMS: check(combine_evidence(Story.CLAIMS[key].pair)==key,"supported claim "+key)
	check(not submit_claim("replacement"),"truth delivery cannot be skipped")
	truth_scene();deliver_truth("together");drain_dialog()
	check(not submit_claim("motive"),"irrelevant confrontation evidence rejected")
	for key in ["replacement","operator","motive"]: check(submit_claim(key),"confrontation "+key)
	custody_scene();drain_dialog();choose_report("case");drain_dialog()
	for ending in ["independent","continued"]:
		finish_case(ending);drain_dialog()
		preload("res://scripts/playthrough_test.gd").find_button(self,"查看维护窗口与清理附页").pressed.emit()
		drain_dialog();check(completed and identity_choice==ending,"ending and digital horizon: "+ending)
	var snapshot: String=artifact_path("test-save-v4.json")
	save_game(snapshot,true);reset_game()
	check(apply_save(JSON.parse_string(FileAccess.get_file_as_string(snapshot))),"disk save parse")
	check(completed and claims.size()==3 and court_step==3,"save restores complete narrative state")
	check(not apply_save({"version":4,"evidence":"bad"}),"malformed save rejected")
	check(apply_save({"version":4,"evidence":[],"claims":["motive"],"court":3,"completed":true,"identity":"independent"}),"untrusted save sanitized")
	check(not completed and court_step==0 and claims.is_empty(),"missing facts cannot unlock end")
	check(sound.clips.size()==7,"all audio assets available")
	check(backgrounds.size()>=4,"all production backgrounds available")
	verify_rigs()
	preload("res://scripts/rig_regression.gd").run(self)
	preload("res://scripts/narrative_test.gd").run(self)
	print("V4 TESTS PASSED" if test_failures==0 else "V4 FAILURES: "+str(test_failures))
	get_tree().quit(0 if test_failures==0 else 1)

func verify_rigs() -> void:
	for id in 12:
		var actor=Rig.new();actor.character_id=id;add_child(actor);actor.set_process(false)
		check(actor.bones.size()==25,"25 bones for character "+str(id))
		var max_foot_error: float=0
		var finite: bool=true
		for action_name in ["idle","walk","talk","think","reach"]:
			actor.action=action_name
			for sample in 80:
				actor.travelled=sample*.5;actor.elapsed=sample*.02;actor.pose(0)
				for b in actor.bones.values(): finite=finite and is_finite(b.rotation)
				if action_name=="walk":
					for side in ["front","back"]:
						var phase: float=fposmod(actor.travelled/actor.STRIDE+(0 if side=="front" else .5),1)
						var actual: Vector2=actor.skeleton.to_local(actor.bones[side+"_foot"].global_position)
						max_foot_error=maxf(max_foot_error,actual.distance_to(actor.foot_cycle(phase)))
		check(finite and max_foot_error<.05,"finite poses and foot IK for character "+str(id))
		actor.action="reach";actor.hand_target=Vector2(10,-32);actor.pose(0)
		var wrist: Vector2=actor.skeleton.to_local(actor.bones.front_hand.global_position)
		check(wrist.distance_to(actor.hand_target)<.05,"hand IK after skin alignment for character "+str(id))
		actor.hand_target=Vector2(10000,-10000);actor.pose(0)
		var reach_length: float=actor.bones.front_upperarm.global_position.distance_to(actor.bones.front_hand.global_position)
		check(is_finite(reach_length) and reach_length<21.01,"unreachable hand target clamped for character "+str(id))
		actor.free()

func run_ui_tests() -> void:
	typewriter=false
	await get_tree().process_frame
	await mouse_click(Vector2(220,512))
	check(is_instance_valid(opening_layer),"title button starts opening scene")
	await mouse_click(Vector2(1110,648))
	check(dialog_mode,"skip enters apartment arrival dialogue")
	for i in 10: await mouse_click(Vector2(1131,648))
	check(not dialog_mode and scene_id=="apartment","intro continue buttons reach apartment")
	await mouse_click(Vector2(625,326))
	check("calendar" in evidence,"visible calendar hotspot collects evidence")
	await mouse_click(Vector2(1026,131))
	await mouse_click(Vector2(435,498))
	check(is_instance_valid(modal),"actor hotspot opens dialogue topics")
	await mouse_click(Vector2(1026,131))
	await mouse_click(Vector2(1090,45))
	check(is_instance_valid(modal),"journal button opens evidence board")
	await mouse_click(Vector2(1163,111))
	await mouse_click(Vector2(268,685))
	check(scene_id=="corridor","bottom scene navigation works")
	await mouse_click(Vector2(510,252))
	check("order" in evidence,"noticeboard hotspot works")
	show_title();start_new()
	for shot in range(1,4):
		await mouse_click(Vector2(896,649))
		check(is_instance_valid(opening_layer) and opening_layer.shot_index==shot,"opening advances to shot "+str(shot+1))
	await mouse_click(Vector2(896,649))
	check(dialog_mode and not is_instance_valid(opening_layer),"final opening card enters arrival dialogue")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("ui-tested-v2.png"))
	print("V2 UI TESTS PASSED" if test_failures==0 else "V2 UI FAILURES: "+str(test_failures))
	get_tree().quit(0 if test_failures==0 else 1)

func capture_preview() -> void:
	typewriter=false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("title.png"))
	start_new()
	await get_tree().create_timer(.65).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("opening.png"))
	for shot in range(1,4):
		opening_layer.show_shot(shot)
		await get_tree().create_timer(.65).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(artifact_path("opening-%d.png" % [shot+1]))
	clear_opening()
	for key in ["apartment","corridor","archive"]:
		enter_scene(key,false)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(artifact_path(key+".png"))
	enter_scene("apartment",false)
	start_dialog(Story.TOPICS.su[1][2])
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("dialogue.png"))
	close_modal()
	for key in REQUIRED: collect(key,false)
	show_journal()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("journal.png"))
	get_tree().quit()
