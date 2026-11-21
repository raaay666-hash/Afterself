extends "res://scripts/game.gd"

const Flow = preload("res://scripts/campaign_flow.gd")
const Dossier = preload("res://scripts/character_dossier.gd")
const Collection = preload("res://scripts/evidence_collection.gd")
const Field = preload("res://scripts/field_puzzles.gd")
const JOURNEY_PATH = "user://campaign-v10.json"
const FIRST_PATH = "user://chapter1-v10.json"
var journey: Dictionary = {"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[]}
const Desk = preload("res://scripts/investigation_desk.gd")
var desk
var campaign_flow
var collection
var field
var field_scene_art

func _ready() -> void:
	field=Field.new();field.g=self;add_child(field)
	desk=Desk.new();desk.g=self;add_child(desk)
	collection=Collection.new();collection.g=self;add_child(collection)
	super._ready()
	for key in ["oldquarter","clinic","waterworks","server","boardroom"]:
		backgrounds[key]=load("res://assets/scenes/"+key+"-v5.png")
	campaign_flow=Flow.new();campaign_flow.g=self;campaign_flow.z_index=10;add_child(campaign_flow);campaign_flow.hide()
	if "--campaign-test" in OS.get_cmdline_user_args(): call_deferred("campaign_tests")
	elif "--desk-test" in OS.get_cmdline_user_args(): call_deferred("desk_tests")
	elif "--desk-window-test" in OS.get_cmdline_user_args(): call_deferred("desk_window_tests")
	elif "--campaign-window-test" in OS.get_cmdline_user_args(): call_deferred("campaign_window_tests")
	elif "--dossier-preview" in OS.get_cmdline_user_args(): call_deferred("dossier_preview")
	elif "--collection-test" in OS.get_cmdline_user_args(): call_deferred("collection_tests")
	elif "--collection-window-test" in OS.get_cmdline_user_args(): call_deferred("collection_window_tests")
	elif "--field-test" in OS.get_cmdline_user_args(): call_deferred("field_tests")
	elif "--field-window-test" in OS.get_cmdline_user_args(): call_deferred("field_window_tests")
	elif "--field-story-test" in OS.get_cmdline_user_args(): call_deferred("field_story_tests")
	button_at(ui,"现场操作",Rect2(528,667,164,36),func(): field.show_chapter(1),true)
	status_tag.position=Vector2(713,667);status_tag.size=Vector2(288,36)
	objectives.position.y=16;objectives.size.y=66
	refresh_evidence()

func refresh_evidence() -> void:
	super.refresh_evidence()
	if is_instance_valid(status_tag): status_tag.text="记录 %d/7  推论 %d/3" % [evidence.size(),claims.size()]
	if is_instance_valid(objectives): objectives.text=current_objective()

func field_tests() -> void:
	preload("res://scripts/field_test.gd").run(self)

func field_window_tests() -> void:
	await preload("res://scripts/field_test.gd").window_run(self)

func field_story_tests() -> void:
	await preload("res://scripts/field_test.gd").story_run(self)

func full_playthrough() -> void:
	await preload("res://scripts/field_test.gd").story_run(self,"--full-story-test" in OS.get_cmdline_user_args())

func collection_tests() -> void:
	preload("res://scripts/collection_test.gd").run(self)

func collection_window_tests() -> void:
	await preload("res://scripts/collection_test.gd").window_run(self)

func campaign_tests() -> void:
	preload("res://scripts/campaign_test.gd").run(self)

func campaign_window_tests() -> void:
	await preload("res://scripts/campaign_test.gd").window_run(self)

func dossier_preview() -> void:
	journey={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[0]}
	show_cast()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("dossier-locked.png"))
	record_cast_meeting(6,false);record_cast_meeting(7,false)
	show_cast()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("dossier-first-case.png"))
	Dossier.show_person(self,6)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("dossier-detail.png"))
	completed=true
	journey.chapters["3"]={"resolution":"separate","bridge_done":true}
	journey.chapters["5"]={"bridge_done":true}
	Dossier.show_person(self,0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(artifact_path("dossier-later.png"))
	get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(field) and field.handle_key(event): get_viewport().set_input_as_handled();return
	if is_instance_valid(collection) and collection.handle_key(event): return
	if title_mode and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and is_instance_valid(modal):
		show_title();return
	if is_instance_valid(campaign_flow) and campaign_flow.visible:
		campaign_flow.handle_key(event)
	else: super._unhandled_key_input(event)

func render_dialog_line() -> void:
	super.render_dialog_line()
	var who: String=current_lines[line_index][0]
	if PERSON_IDS.has(who): record_cast_meeting(int(PERSON_IDS[who]))
	if is_instance_valid(campaign_flow) and campaign_flow.visible:
		if active_people.has(who): talk_actor=active_people[who]
		if is_instance_valid(talk_actor): talk_actor.action="talk"

func show_topics(person: String) -> void:
	if PERSON_IDS.has(person): record_cast_meeting(int(PERSON_IDS[person]))
	if not collection.state().pending.is_empty():
		collection.popup(str(collection.state().pending[0]),func(): show_topics(person));return
	super.show_topics(person)
	if not collection.available_tasks(1,TOPIC_NAMES[person]).is_empty():
		button_at(modal,"物件委托",Rect2(248,458,285,44),func(): collection.show_tasks(1,TOPIC_NAMES[person],func(): show_topics(person)),true)
	if person=="wen" and "order" in evidence and "access" not in evidence:
		button_at(modal,"申请签收副本",Rect2(30,478,191,32),field.request_custody_copy,true)

func enter_scene(key: String, persist: bool = true) -> void:
	if is_instance_valid(field_scene_art): field_scene_art.get_parent().remove_child(field_scene_art);field_scene_art.queue_free()
	field_scene_art=null
	super.enter_scene(key,persist)
	if key=="corridor":
		field_scene_art=preload("res://scripts/puzzle_art.gd").new();field_scene_art.kind="scene_door"
		field_scene_art.z_index=-10
		field_scene_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;field_scene_art.position=Vector2(692,152);field_scene_art.size=Vector2(224,384)
		ui.add_child(field_scene_art);field_scene_art.show_behind_parent=true;refresh_field_scene()

func refresh_field_scene() -> void:
	if is_instance_valid(field_scene_art):
		field_scene_art.sealed=field.passed("c1b",0) and field.task("c1b").steps[0].get("method","")!="certified_copy"
		field_scene_art.queue_redraw()
	if is_instance_valid(campaign_flow): campaign_flow.refresh_entry_art()

func close_modal() -> void:
	if is_instance_valid(field): field.modal_closed()
	if is_instance_valid(collection): collection.modal_closed()
	super.close_modal()

func collect(key: String, show: bool = true) -> void:
	var fresh: bool=key not in evidence
	super.collect(key,false)
	if fresh and key in evidence: collection.enqueue("c1."+key)
	if show: show_evidence(key)

func show_object(key: String) -> void:
	if key in evidence:
		var id: String="c1."+key
		if collection.pending(id): collection.popup(id)
		else: collection.inspect(id)
	else: super.show_object(key)

func show_restore() -> void:
	if "restore" not in evidence: return
	if collection.pending("c1.restore"): collection.popup("c1.restore")
	else: collection.inspect("c1.restore")

func show_evidence(key: String) -> void:
	if key not in evidence: return
	var id: String="c1."+key
	if collection.pending(id): collection.popup(id)
	else: collection.inspect(id)

func show_evidence_index() -> void:
	collection.show_album(1)

func show_observation(key: String) -> void:
	if key=="lease" and key in observations and not collection.acquired("c1.lease"):
		collection.state().stories.append("c1.lease");collection.enqueue("c1.lease")
		collection.popup("c1.lease");return
	super.show_observation(key)

func record_cast_meeting(id: int, persist: bool = true) -> void:
	if id<0 or id>=12: return
	if not journey.has("cast_met"): journey.cast_met=[]
	if id in journey.cast_met: return
	journey.cast_met.append(id)
	if persist: save_journey()

func show_cast() -> void:
	Dossier.show(self)

func show_title() -> void:
	if is_instance_valid(campaign_flow): campaign_flow.hide()
	super.show_title()
	for child in overlay.get_children():
		if child is Label:
			if child.text.begins_with("第一章    /"): child.text="六章一周目    /    第 %d 章" % int(journey.chapter)
			if child.text.begins_with("CHAPTER EDITION"): child.text="SIX CHAPTERS  0.10"
	button_at(overlay,"故事脉络",Rect2(441,608,144,36),func(): desk.show_overview(),true)
	button_at(overlay,"章节目录",Rect2(441,555,144,40),show_chapters,true)
	button_at(overlay,"从第二章开始",Rect2(84,608,326,36),show_catchup,true)
	button_at(overlay,"证物柜",Rect2(604,608,144,36),func(): collection.show_album(int(journey.chapter),show_title),true)
	button_at(overlay,"现场操作",Rect2(766,608,168,36),func(): field.show_chapter(int(journey.chapter)),true)

func show_catchup() -> void:
	new_modal("接续体验 / 第一章记录")
	label_at(modal,"已有首章存档会保留。\n\n直接体验后五章时，如无首章结案记录，将采用：\n为宋屿单列身份；生活支线未商量；本案独立封存。\n\n这不会覆盖原版首章进度。",Rect2(34,97,800,288),23)
	button_at(modal,"返回标题",Rect2(34,437,250,56),show_title,true)
	button_at(modal,"以此记录进入第二章",Rect2(312,437,520,56),func():
		if not journey.choices.has("first_identity"): journey.choices.first_identity="independent"
		journey.unlocked=maxi(2,int(journey.unlocked));start_campaign(2))

func show_chapters() -> void:
	new_modal("章节目录 / 已完成的案件可回访")
	for number in range(1,7):
		var title: String="睡过头的人" if number==1 else Flow.book()[str(number)].title
		var b:=button_at(modal,"%02d  /  %s" % [number,title],Rect2(34,86+(number-1)*64,800,53),func():
			if number==1:
				journey.chapter=1
				if is_instance_valid(campaign_flow): campaign_flow.hide()
				if intro_done or not evidence.is_empty() or completed or not pending_event.is_empty(): super.resume_chapter()
				else: super.start_new()
			else: start_campaign(number),true)
		b.disabled=number>int(journey.unlocked)
	button_at(modal,"返回当前进度",Rect2(34,483,800,34),func():
		if int(journey.chapter)>1: start_campaign(int(journey.chapter))
		else: show_title(),true)
	lock_choices()

func start_new() -> void:
	journey={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[0]}
	if is_instance_valid(campaign_flow): campaign_flow.hide()
	super.start_new()

func confirm_new_game() -> void:
	new_modal("重新开始六章故事")
	label_at(modal,"将重置本版六章调查进度、人物物件与检查记录。\n本版已作出的选择也将重新开始。\n\n旧版本的存档和程序仍会保留。",Rect2(34,116,800,221),25)
	button_at(modal,"返回标题",Rect2(34,425,365,57),show_title,true)
	button_at(modal,"确认从第一章重新开始",Rect2(427,425,410,57),start_new)

func resume_chapter() -> void:
	if int(journey.chapter)>1: start_campaign(int(journey.chapter))
	else: super.resume_chapter()

func start_campaign(number: int) -> void:
	if number<2 or number>6 or number>int(journey.unlocked): return
	record_cast_meeting(0,false)
	close_modal();clear_horizon();clear_hotspots();active_people.clear();ui.hide()
	title_mode=false;v2_started=true;pending_interaction="";journey.chapter=number
	campaign_flow.show();campaign_flow.begin(number)

func show_ending() -> void:
	super.show_ending()
	if completed:
		journey.unlocked=maxi(2,int(journey.unlocked))
		journey.choices.first_identity=identity_choice
		journey.choices.first_future=decisions.get("future","")
		journey.choices.first_report=decisions.get("report","case")
		save_journey()
		button_at(modal,"继续第二章  →",Rect2(790,22,260,44),func(): start_campaign(2))
		for child in modal.get_children():
			if child is Label and child.text.begins_with("第一章结束"):
				child.text="第一章结束 · 后续五章已可继续\n你在本章的选择会进入后续人物回应。"

func save_game(path: String = FIRST_PATH, force_test: bool = false) -> void:
	if int(journey.chapter)==1 or path!=FIRST_PATH: super.save_game(path,force_test)
	if not force_test: save_journey()

func save_journey(path: String = JOURNEY_PATH, force_test: bool = false) -> bool:
	if testing and not force_test: return false
	journey.settings={"audio":sound.enabled,"volume":sound.level,"typewriter":typewriter}
	var f:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null: toast("全篇进度保存失败，请检查存档目录。" );return false
	f.store_string(JSON.stringify(journey));f.close()
	var ok: bool=DirAccess.rename_absolute(path+".tmp",path)==OK
	if not ok: toast("全篇进度尚未写入磁盘。")
	return ok

func load_game() -> void:
	if testing: return
	var legacy_cast: bool=true
	var first: String=first_existing([FIRST_PATH,"user://chapter1-v9.json","user://chapter1-v6.json","user://chapter1-v5.json",CHAPTER_SAVE_PATH])
	if FileAccess.file_exists(first): apply_save(JSON.parse_string(FileAccess.get_file_as_string(first)))
	var campaign_path: String=first_existing([JOURNEY_PATH,"user://campaign-v9.json","user://campaign-v6.json","user://campaign-v5.json"])
	if FileAccess.file_exists(campaign_path):
		var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(campaign_path))
		if loaded is Dictionary and loaded.get("version")==5:
			legacy_cast=not loaded.has("cast_met")
			journey=Flow.sanitize(loaded)
	if completed:
		journey.unlocked=maxi(2,int(journey.unlocked))
		journey.choices.first_identity=identity_choice
		journey.choices.first_future=decisions.get("future","")
		journey.choices.first_report=decisions.get("report","case")
	if int(journey.chapter)>1: v2_started=true
	if legacy_cast: recover_legacy_cast()
	if journey.has("settings"):
		sound.enabled=journey.settings.audio;sound.level=journey.settings.volume
		typewriter=journey.settings.typewriter;sound.refresh()
	collection.reconcile()

func first_existing(paths: Array) -> String:
	for path in paths:
		if FileAccess.file_exists(path): return path
	return paths[0]

func recover_legacy_cast() -> void:
	# Older saves predate the encounter list. Infer only encounters backed by saved progress.
	if v2_started: record_cast_meeting(0,false)
	if intro_done or completed or not evidence.is_empty():
		record_cast_meeting(6,false);record_cast_meeting(7,false)
	if completed:
		record_cast_meeting(8,false);record_cast_meeting(2,false)
	else:
		if scene_id=="corridor" or "order" in evidence or "access" in evidence: record_cast_meeting(8,false)
		if scene_id=="archive" or "restore" in evidence or "receipt" in evidence: record_cast_meeting(2,false)
	for topic in seen_topics:
		var person: String=str(topic).get_slice("/",0)
		if PERSON_IDS.has(person): record_cast_meeting(int(PERSON_IDS[person]),false)
	for number in range(2,7):
		var state: Dictionary=journey.chapters.get(str(number),{})
		if state.is_empty(): continue
		var book: Dictionary=Flow.book()[str(number)]
		if state.get("intro")==true:
			for line in book.intro:
				if PERSON_IDS.has(line[0]): record_cast_meeting(int(PERSON_IDS[line[0]]),false)
		for room in book.scenes:
			var reached: bool=number<int(journey.unlocked) or (number==int(journey.chapter) and room==book.scenes[int(state.scene)])
			for item in room.items:
				if item.key in state.evidence: reached=true
			if reached:
				for person in room.people: record_cast_meeting(int(person.id),false)
		for entry in state.seen:
			var person: String=str(entry).get_slice("/",0)
			if PERSON_IDS.has(person): record_cast_meeting(int(PERSON_IDS[person]),false)
		if number==2 and state.get("bridge_done")==true:
			record_cast_meeting(1,false);record_cast_meeting(5,false)

func artifact_path(filename: String) -> String:
	if OS.has_feature("editor"): return "res://build/v10/"+filename
	return OS.get_executable_path().get_base_dir().path_join(filename)

func desk_tests() -> void:
	preload("res://scripts/investigation_test.gd").run(self)

func desk_window_tests() -> void:
	await preload("res://scripts/investigation_test.gd").window_run(self)

func label_at(parent: Node, text: String, rect: Rect2, size: int = 18, color: String = "d8d5c8") -> Label:
	var px: int=20 if size<22 else (24 if size<30 else (36 if size<44 else int(size/12)*12))
	var l: Label=super.label_at(parent,pixel_text(text),rect,px,color)
	l.add_theme_font_override("font",load("res://assets/fonts/pixel-small.otf") if px==20 else load("res://assets/fonts/pixel-text.otf"))
	l.size.y=maxf(l.size.y,l.get_theme_font("font").get_height(px))
	l.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return l

func button_at(parent: Node, text: String, rect: Rect2, callback: Callable, quiet: bool = false) -> Button:
	var b: Button=super.button_at(parent,pixel_text(text),rect,callback,quiet)
	b.add_theme_font_override("font",load("res://assets/fonts/pixel-small.otf"))
	b.add_theme_font_size_override("font_size",20)
	b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	return b

func box_style(bg: String, border: String = "35464b", width: int = 1) -> StyleBoxFlat:
	var style: StyleBoxFlat=super.box_style(bg,border,maxi(2,width))
	style.shadow_color=Color("060e10a0");style.shadow_size=4;style.shadow_offset=Vector2(4,4)
	return style

func show_journal() -> void:
	if is_instance_valid(campaign_flow) and campaign_flow.visible:
		campaign_flow.show_journal();return
	if title_mode:
		show_title();return
	super.show_journal()
	add_desk_tabs()

func add_desk_tabs() -> void:
	# Dedicated free strip, above the evidence actions.
	button_at(modal,"现场核验",Rect2(652,76,214,39),func(): desk.show_task(),true)
	button_at(modal,"故事脉络",Rect2(882,76,232,39),func(): desk.show_overview(),true)
	for child in modal.get_children():
		if child is Label and child.position.y>=73 and child.position.y<=80: child.size.x=600

func show_confrontation() -> void:
	if claims.size()==3 and flags.get("truth",false) and court_step==0 and not field.chapter_done(1):
		field.open(field.next_task(1));toast("对质前，先完成现场操作与凭据区间核验。");return
	super.show_confrontation()

func show_lock() -> void:
	field.open("c1a")

func solve_lock(code: String) -> bool:
	if not super.solve_lock(code): return false
	field.task("c1a").steps[0].values=[7,1,4]
	field.certify("c1a",0)
	return true

func perform_interaction(key: String) -> void:
	if key=="access" and "access" not in evidence and not field.passed("c1b",0):
		field.open("c1b");return
	super.perform_interaction(key)

func show_terminal() -> void:
	new_modal("恢复记录终端 / M-204 只读调阅")
	if "order" not in evidence:
		label_at(modal,"先从维修走廊取得工单号，再由闻遥调阅。",Rect2(34,135,800,160),24);return
	label_at(modal,"闻遥已按 M-204 调出记录：\n\n07/14 00:00 保存快照\n07/17 02:26 旧实例终止\n07/17 06:12 从旧备份启动现行者\n\n先留存原件，四时点与保管区间在现场核验台统一核对。",Rect2(34,90,800,332),24)
	button_at(modal,"留存恢复登记",Rect2(429,451,403,45),func():
		flags.timeline=true;collect("restore",false);show_restore())
	button_at(modal,"返回调查",Rect2(34,451,370,45),close_modal,true)

func pixel_text(value: String) -> String:
	return value.replace("✓", "+").replace("☑", "[X]").replace("□", "[ ]").replace("↻", ">").replace("−","-")

func panel_at(parent: Node, rect: Rect2, color: String = "151e25") -> Panel:
	var panel: Panel=super.panel_at(parent,rect,color)
	if color in ["d6ccb0","cec5ac","cbbfa1"] and rect.size.y>200:
		# Small punched edge and archive seal, away from the original text.
		for y in range(18,int(rect.size.y)-16,24):
			shade(panel,Rect2(7,y,5,5),Color("978e78"))
		shade(panel,Rect2(rect.size.x-149,rect.size.y-40,131,2),Color("8d6f50"))
		label_at(panel,"原件留存",Rect2(rect.size.x-147,rect.size.y-36,132,29),20,"79614a")
	return panel
