extends Control

var g
var number: int = 2
var chapter: Dictionary
var state: Dictionary
var controls: Dictionary = {}
var selected: Array = []
var caption: Label
var objective_label: Label
var hover: bool = false
var pending: Callable
var entry_art
static var cache: Dictionary = {}

static func book() -> Dictionary:
	if cache.is_empty():
		cache=JSON.parse_string(FileAccess.get_file_as_string("res://assets/campaign-v5.json"))
		for c in cache.values():
			for i in c.puzzle.correct.size(): c.puzzle.correct[i]=int(c.puzzle.correct[i])
	return cache

static func blank() -> Dictionary:
	return {"scene":0,"intro":false,"evidence":[],"claims":[],"answers":[],"puzzle":false,"court":0,"reply":-1,"resolution":"","resolution_seen":false,"bridge_docs":[],"bridge_answer":-1,"bridge_done":false,"seen":[],"private":"","ended":false}

static func sanitize(raw: Dictionary) -> Dictionary:
	var clean: Dictionary={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[]}
	var met: Variant=raw.get("cast_met",[])
	if met is Array:
		for id in met:
			if (id is int or id is float) and int(id)==id and int(id)>=0 and int(id)<12 and int(id) not in clean.cast_met:
				clean.cast_met.append(int(id))
	var prefs: Variant=raw.get("settings",{})
	if prefs is Dictionary:
		var volume: Variant=prefs.get("volume",.55)
		clean.settings={"audio":prefs.get("audio",true)==true,"volume":clampf(float(volume),0,1) if volume is float or volume is int else .55,"typewriter":prefs.get("typewriter",true)==true}
	clean.desk=preload("res://scripts/investigation_desk.gd").clean(raw.get("desk",{}))
	clean.collection=preload("res://scripts/evidence_collection.gd").clean(raw.get("collection",{}))
	var raw_choices: Variant=raw.get("choices",{})
	if raw_choices is Dictionary:
		for k in {"first_identity":["independent","continued"],"first_future":["","breakfast","space"],"first_report":["case","system"]}:
			if raw_choices.get(k) in {"first_identity":["independent","continued"],"first_future":["","breakfast","space"],"first_report":["case","system"]}[k]: clean.choices[k]=raw_choices[k]
	if clean.choices.has("first_identity"): clean.unlocked=2
	var chapters: Variant=raw.get("chapters",{})
	if chapters is Dictionary:
		for n in range(2,7):
			var key: String=str(n)
			if n>int(clean.unlocked) or not chapters.get(key) is Dictionary: continue
			var s: Dictionary=chapters[key];var c: Dictionary=book()[key];var v: Dictionary=blank()
			v.scene=clampi(int(s.get("scene",0)),0,2) if s.get("scene",0) is float or s.get("scene",0) is int else 0
			v.intro=s.get("intro")==true
			if s.get("evidence") is Array:
				for e in c.evidence:
					if e in s.evidence: v.evidence.append(e)
			if s.get("claims") is Array:
				for e in c.claims:
					if e in s.claims and c.claims[e].pair[0] in v.evidence and c.claims[e].pair[1] in v.evidence: v.claims.append(e)
			if s.get("answers") is Array and s.answers.size()==c.puzzle.correct.size():
				for a in s.answers: v.answers.append(clampi(int(a),0,4) if a is float or a is int else 0)
			var ready: bool=true
			for e in c.puzzle.requires: ready=ready and e in v.evidence
			v.puzzle=ready and v.answers==c.puzzle.correct and s.get("puzzle")==true
			if s.get("court") is float or s.get("court") is int: v.court=clampi(int(s.court),0,3) if v.puzzle and v.claims.size()==3 else 0
			if s.get("reply") is float or s.get("reply") is int:
				var r: int=int(s.reply)
				if r>=0 and r<3 and r==int(v.court)-1: v.reply=r
			for choice in c.choices:
				if s.get("resolution")==choice.id and v.court==3 and v.reply==-1: v.resolution=choice.id
			if s.get("seen") is Array:
				for item in s.seen:
					if item is String and item.length()<80 and item not in v.seen: v.seen.append(item)
			if not v.resolution.is_empty():
				v.resolution_seen=s.get("resolution_seen")==true
				if s.get("bridge_docs") is Array:
					for d in s.bridge_docs:
						if (d is float or d is int) and int(d) in [0,1] and int(d) not in v.bridge_docs: v.bridge_docs.append(int(d))
				if (s.get("bridge_answer") is float or s.get("bridge_answer") is int) and int(s.bridge_answer) in [0,1] and v.bridge_docs.size()==2: v.bridge_answer=int(s.bridge_answer)
				v.bridge_done=s.get("bridge_done")==true and v.bridge_answer>=0
				if n==6 and s.get("private") in ["upload","decline"]: v.private=s.private
				v.ended=s.get("ended")==true and n==6 and not v.private.is_empty()
			clean.chapters[key]=v
			if n<6 and v.bridge_done: clean.unlocked=n+1
	var current: int=int(raw.get("chapter",1)) if raw.get("chapter",1) is float or raw.get("chapter",1) is int else 1
	clean.chapter=clampi(current,1,int(clean.unlocked))
	clean.field=preload("res://scripts/field_puzzles.gd").clean(raw.get("field",{}))
	for id in clean.field.tasks.keys():
		if int(preload("res://scripts/field_puzzles.gd").book()[id].chapter)>int(clean.unlocked): clean.field.tasks.erase(id)
	return clean

func begin(n: int) -> void:
	number=n;chapter=book()[str(n)]
	if not g.journey.chapters.has(str(n)): g.journey.chapters[str(n)]=blank()
	state=g.journey.chapters[str(n)]
	show_scene(int(state.scene))
	if not state.intro:
		g.start_dialog(chapter.intro,func(): state.intro=true;persist())
	elif state.ended: show_final_card()
	elif not state.private.is_empty(): private_epilogue(state.private)
	elif not state.resolution.is_empty():
		if not state.resolution_seen: resolution_reply()
		elif n==6: public_epilogue()
		elif state.bridge_done: show_chapter_end()
		else: show_bridge()
	elif state.reply>=0: replay_reply()
	elif state.court==3: show_resolution()

func persist() -> void:
	if is_instance_valid(objective_label): objective_label.text=objective()
	refresh_entry_art()
	g.save_journey()

func refresh_entry_art() -> void:
	if is_instance_valid(entry_art): entry_art.sealed=g.field.finished("c2a");entry_art.queue_redraw()

func objective() -> String:
	if state.ended: return "一周目已结束。可回看结局或返回章节目录。"
	if not state.resolution.is_empty(): return "完成跨场景衔接，继续下一段经历。"
	if state.court==3: return "本案事实已查清，听取当事人回应并完成结案。"
	if state.evidence.size()<6: return "调查现场并询问证人。已取得 %d / 6 份记录。" % state.evidence.size()
	if not g.field.chapter_done(number): return "在现场操作台完成入口、来源与条件核验。"
	if state.claims.size()<3: return "打开案卷，将六份记录组合成三项推论。"
	return "提交结案推论，逐项回应争议。"

func clear_ui() -> void:
	for child in get_children(): remove_child(child);child.queue_free()
	entry_art=null
	controls.clear();pending=Callable();g.hover_name=""

func show_scene(index: int) -> void:
	if number==3 and index==2 and not g.field.chapter_done(3):
		show_scene(0)
		g.field.open(g.field.next_task(3));g.toast("先查清三份签名来源，再进入旧上传间。");return
	g.close_modal();g.clear_hotspots();g.active_people.clear();clear_ui()
	state.scene=clampi(index,0,2)
	var room: Dictionary=chapter.scenes[state.scene]
	g.ui.hide();g.actors.show();g.title_mode=false;g.set_background(room.art)
	g.background.modulate=Color.WHITE
	g.hero=g.actor_at(1 if number==6 and index==2 else 0,140,2.65)
	if g.testing: g.hero.speed=120
	g.hero.footstep.connect(func(): g.sound.play("step"))
	g.hero.arrived.connect(func():
		if pending.is_valid():
			var call: Callable=pending;pending=Callable();call.call())
	g.shade(self,Rect2(0,0,1280,100),Color("0b1419d9"));g.shade(self,Rect2(0,652,1280,68),Color("0b1419ef"))
	g.label_at(self,"%02d / %s  ·  %s" % [number,chapter.title,room.name],Rect2(26,14,785,35),24,"e5d4ac")
	objective_label=g.label_at(self,objective(),Rect2(27,57,1120,32),17,"adbfba")
	g.button_at(self,"案卷 [J]",Rect2(821,15,123,38),show_journal,true)
	g.button_at(self,"现场推演",Rect2(958,15,153,38),show_puzzle,true)
	g.button_at(self,"菜单",Rect2(1128,15,123,38),show_menu,true)
	for i in 3:
		g.button_at(self,chapter.scenes[i].name,Rect2(24+i*250,667,238,38),func(): show_scene(i),true)
	g.button_at(self,"提交结案推论",Rect2(793,667,228,38),show_court,true)
	g.button_at(self,"提示",Rect2(1035,667,95,38),show_hint,true)
	g.button_at(self,"热点 [H]",Rect2(1143,667,112,38),toggle_hotspots,true)
	caption=g.label_at(self,"点击人物询问，点击物件阅读。按 H 显示调查位置。",Rect2(28,607,1225,33),18,"e1d8bd")
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_constant_override("outline_size",5);caption.add_theme_color_override("font_outline_color",Color("071416"))
	if number==2 and index==0:
		entry_art=preload("res://scripts/puzzle_art.gd").new();entry_art.kind="scene_door"
		entry_art.z_index=-10
		entry_art.position=Vector2(928,248);entry_art.size=Vector2(224,384);entry_art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(entry_art);refresh_entry_art()
	for item in room.items:
		add_hotspot(chapter.evidence[item.key].title,Rect2(item.x-75,item.y-42,150,84),"item/"+item.key,func(): interact_evidence(item.key))
	var pindex: int=0
	for person in room.people:
		var x: float=620 if room.people.size()==1 else 606+pindex*250
		var actor=g.actor_at(int(person.id),x,2.55);g.active_people[person.name]=actor
		add_hotspot(person.name,Rect2(x-63,283,126,311),"npc/"+person.name,func(): show_person(person,room))
		g.record_cast_meeting(int(person.id),false)
		pindex+=1
	persist()

func add_hotspot(title: String, rect: Rect2, key: String, action: Callable) -> void:
	var b:=Button.new();b.flat=true;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for s in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(s,StyleBoxEmpty.new())
	add_child(b);b.position=rect.position;b.size=rect.size;controls[key]=b
	b.pressed.connect(func():
		if is_instance_valid(g.modal): return
		pending=action;g.hero.walk_to(clampf(rect.get_center().x-78,92,1145)))
	b.mouse_entered.connect(func(): caption.text=title)
	b.mouse_exited.connect(func(): caption.text=objective())
	var marker=g.label_at(self,"◇ "+title,Rect2(rect.position.x-60,rect.position.y-29,rect.size.x+120,28),16,"ead3a0")
	marker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;marker.visible=hover;marker.set_meta("hotspot",true)
	marker.add_theme_constant_override("outline_size",4);marker.add_theme_color_override("font_outline_color",Color("091511"))

func toggle_hotspots() -> void:
	hover=not hover
	for child in get_children():
		if child.has_meta("hotspot"): child.visible=hover

func read_evidence(key: String) -> void:
	if not chapter.evidence.has(key): return
	var id: String="c%d.%s" % [number,key]
	if key not in state.evidence:
		state.evidence.append(key);g.sound.play("found");persist();g.collection.enqueue(id)
	if g.collection.pending(id): g.collection.popup(id)
	else: g.collection.inspect(id)

func interact_evidence(key: String) -> void:
	var gate: String=g.field.evidence_gate(number,key)
	if not gate.is_empty(): g.field.open(gate)
	else: read_evidence(key)

func show_person(person: Dictionary, room: Dictionary) -> void:
	g.new_modal(person.name+" / 询问")
	g.add_portrait(g.modal,int(person.id),Rect2(30,105,170,370))
	var y: int=102
	for t in person.topics:
		var seen_key: String=person.name+"/"+t.title
		g.button_at(g.modal,("✓ " if seen_key in state.seen else "· ")+t.title,Rect2(234,y,603,56),func():
			g.start_dialog(t.lines,func():
				if seen_key not in state.seen: state.seen.append(seen_key)
				persist();show_person(person,room)),true)
		y+=69
	g.label_at(g.modal,"现场原件 / 请求出示留存副本",Rect2(236,260,598,38),17,"b6b38c")
	for item in room.items:
		g.button_at(g.modal,"核对："+chapter.evidence[item.key].title,Rect2(234,304+room.items.find(item)*59,603,49),func(): read_evidence(item.key),true)
	g.button_at(g.modal,"暂时问到这里",Rect2(536,460,300,43),g.close_modal)
	if not g.collection.available_tasks(number,person.name).is_empty():
		g.button_at(g.modal,"物件委托",Rect2(30,478,300,32),func(): g.collection.show_tasks(number,person.name,func(): show_person(person,room)),true)

func show_journal() -> void:
	g.new_modal("第 %d 章案卷 / 两份记录，一项可核验的解释" % number,true)
	g.add_desk_tabs()
	selected=[]
	g.label_at(g.modal,"选中两份记录，再组合推论。原文可随时重读。",Rect2(30,77,604,44),19,"b9c7b4")
	var buttons: Dictionary={};var i: int=0
	for key in chapter.evidence:
		var b=g.button_at(g.modal,chapter.evidence[key].title if key in state.evidence else "",Rect2(30+(i%2)*289,135+int(i/2)*92,273,76),func():
			if key in selected: selected.erase(key)
			elif selected.size()<2: selected.append(key)
			for k in buttons: buttons[k].modulate=Color("ebd28e") if k in selected else Color.WHITE)
		b.disabled=key not in state.evidence;buttons[key]=b;i+=1
	i=0
	for key in chapter.claims:
		g.label_at(g.modal,("✓ "+chapter.claims[key].title) if key in state.claims else "— 尚未形成的推论",Rect2(650,141+i*99,468,86),22,"e0d0a3" if key in state.claims else "81998f");i+=1
	var feedback=g.label_at(g.modal,"",Rect2(30,427,1090,68),19,"dac391")
	g.button_at(g.modal,"组合选中的记录",Rect2(30,514,342,48),func():
		var result: String=combine(selected)
		if result.is_empty(): feedback.text="这两份材料不能独立回应同一个问题。分别核对行为来源、被省略的事实与权利边界。"
		else:
			g.new_modal(chapter.claims[result].title)
			g.label_at(g.modal,chapter.claims[result].body,Rect2(34,110,800,270),25)
			g.button_at(g.modal,"记入推论",Rect2(536,458,300,48),show_journal))
	g.button_at(g.modal,"重读原件",Rect2(396,514,342,48),show_records,true)
	g.button_at(g.modal,"返回现场",Rect2(762,514,342,48),g.close_modal,true)

func show_records() -> void:
	g.collection.show_album(number)

func combine(pair: Array) -> String:
	if pair.size()!=2 or pair[0]==pair[1]: return ""
	for p in pair:
		if p not in state.evidence: return ""
	for key in chapter.claims:
		var expected: Array=chapter.claims[key].pair
		if pair[0] in expected and pair[1] in expected:
			if key not in state.claims: state.claims.append(key);g.sound.play("found");persist()
			return key
	return ""

func puzzle_ready() -> bool:
	for key in chapter.puzzle.requires:
		if key not in state.evidence: return false
	return true

func show_puzzle() -> void:
	g.field.show_chapter(number)

func show_legacy_puzzle() -> void:
	var p: Dictionary=chapter.puzzle
	g.new_modal(p.title,true)
	g.label_at(g.modal,p.instruction,Rect2(30,73,1098,68),21,"d0d0b7")
	if not puzzle_ready():
		var missing: String="先取得这些原件：\n"
		for e in p.requires:
			if e not in state.evidence: missing+="\n"+chapter.evidence[e].title
		g.label_at(g.modal,missing,Rect2(36,168,1060,284),25);return
	var count: int=p.rows.size()
	if state.answers.size()!=count: state.answers.resize(count);state.answers.fill(0)
	var feedback=g.label_at(g.modal,"已核对并封存结果。可随时回读原件。" if state.puzzle else "",Rect2(30,460,1080,50),18,"d5c393")
	for i in count:
		if p.kind=="ballot":
			var b=g.button_at(g.modal,("☑  " if state.answers[i]==1 else "□  ")+p.rows[i],Rect2(34+(i%2)*550,160+int(i/2)*89,525,72),func():
				state.answers[i]=1-int(state.answers[i]);persist();show_puzzle())
			controls["puzzle/"+str(i)]=b
			b.disabled=state.puzzle
		else:
			var options: Array=p.get("options_by_row",[])[i] if p.has("options_by_row") else p.options
			state.answers[i]=clampi(int(state.answers[i]),0,options.size()-1)
			g.label_at(g.modal,p.rows[i],Rect2(34,164+i*66,120 if number==2 else 387,53),22)
			if number==2:
				# Miniature parcel diagrams keep the map comparison grounded in places.
				g.shade(g.modal,Rect2(172,159+i*66,220,51),Color("233e3b"))
				for house in 4:
					g.shade(g.modal,Rect2(184+house*44,174+i*66,28,23),Color("657864") if i==1 else Color("5b6260"))
					g.shade(g.modal,Rect2(196+house*44,184+i*66,8,13),Color("d1b575") if i==1 else Color("293c38"))
				g.shade(g.modal,Rect2(180,200+i*66,202,3),Color("b19160"))
			var b=g.button_at(g.modal,options[int(state.answers[i])]+"  ↻",Rect2(430,159+i*66,687,51),func():
				state.answers[i]=(int(state.answers[i])+1)%options.size();persist();show_puzzle())
			controls["puzzle/"+str(i)]=b
			b.disabled=state.puzzle
	if p.kind=="valves":
		g.shade(g.modal,Rect2(41,401,1066,5),Color("577c78"))
		for i in 3: g.shade(g.modal,Rect2(184+i*365,391,22,25),Color("99bba1") if int(state.answers[i])==1 else Color("b38b60"))
		g.label_at(g.modal,"三个条件必须同时满足；今日非干旱，不能据此主张永久锁闸。",Rect2(38,420,1070,29),17,"aebdae")
	elif p.kind=="ballot":
		var count_selected: int=0
		for a in state.answers: count_selected+=int(a)
		g.label_at(g.modal,"当前勾选 %d 条 / 赞成、反对与保留意见都可能是有效意愿。" % count_selected,Rect2(38,427,1070,29),17,"aebdae")
	g.button_at(g.modal,"核对本次推演",Rect2(756,522,360,44),func():
		if solve_puzzle(state.answers): show_puzzle()
		else: feedback.text="还存在矛盾。核对原件中的年代、主体与限制条件；试错不会损失进度。")
	g.button_at(g.modal,"查看推演提示",Rect2(34,522,340,44),func(): feedback.text=p.hint,true)
	g.button_at(g.modal,"返回现场",Rect2(395,522,340,44),g.close_modal,true)

func solve_puzzle(answers: Array) -> bool:
	if not puzzle_ready() or answers!=chapter.puzzle.correct: return false
	state.answers=answers.duplicate();state.puzzle=true;g.sound.play("found");persist();return true

func show_court() -> void:
	if not state.resolution.is_empty():
		if number==6: public_epilogue()
		elif state.bridge_done: show_chapter_end()
		else: show_bridge()
		return
	if not state.puzzle or state.claims.size()!=3:
		g.new_modal("还需要能回应质疑的材料")
		g.label_at(g.modal,objective()+"\n\n六份原件、现场推演、三项推论都完成后再提交。",Rect2(34,121,800,256),26);return
	if state.court==0 and not g.field.chapter_done(number):
		g.field.open(g.field.next_task(number));g.toast("对质前，完成本章现场操作。");return
	if state.reply>=0: replay_reply();return
	if state.court==3: show_resolution();return
	var r: Dictionary=chapter.rounds[state.court]
	g.new_modal("结案对质 / %d · 3" % [int(state.court)+1],true)
	g.label_at(g.modal,r.line,Rect2(38,109,1070,107),30)
	g.label_at(g.modal,"选择能直接回应这项主张的推论。",Rect2(38,237,1050,38),19,"b9c2a9")
	var feedback=g.label_at(g.modal,"",Rect2(38,495,1060,52),20,"dfb990")
	var i: int=0
	for key in chapter.claims:
		g.button_at(g.modal,chapter.claims[key].title,Rect2(38,298+i*61,1067,51),func():
			if submit(key): replay_reply()
			else: feedback.text="这项推论没有直接回应当前的说法。请检查质疑针对的是来源、行为还是权利。")
		i+=1

func submit(key: String) -> bool:
	if not g.field.chapter_done(number): return false
	if not state.puzzle or state.claims.size()!=3 or state.court>=3 or state.reply>=0: return false
	if key!=chapter.rounds[state.court].claim: return false
	state.reply=state.court;state.court+=1;persist();return true

func replay_reply() -> void:
	if state.reply<0: return
	g.start_dialog(chapter.rounds[state.reply].reply,func(): state.reply=-1;persist();show_court())

func show_resolution() -> void:
	if state.court!=3 or state.reply>=0: return
	g.new_modal(chapter.choice_title,true)
	g.label_at(g.modal,"本案的原件、责任与仍待协商的部分已经分别记录。\n选择会影响人物回应，并进入最后的公共结局。",Rect2(36,99,1081,117),24,"d7d5bb")
	for i in chapter.choices.size():
		var c: Dictionary=chapter.choices[i]
		g.button_at(g.modal,c.label,Rect2(36,262+i*88,1081,68),func(): choose_resolution(c.id))
	g.lock_choices()

func choose_resolution(id: String) -> bool:
	if state.court!=3 or state.reply>=0 or not state.resolution.is_empty(): return false
	for c in chapter.choices:
		if c.id==id:
			# Save the confirmed choice before its response, then replay on resume.
			state.resolution=id;persist()
			resolution_reply()
			return true
	return false

func resolution_reply() -> void:
	for c in chapter.choices:
		if c.id==state.resolution:
			g.start_dialog(c.lines,func():
				state.resolution_seen=true;persist()
				if number==6: public_epilogue()
				else: show_bridge())
			return

func show_bridge() -> void:
	if chapter.bridge==null or state.resolution.is_empty(): return
	var b: Dictionary=chapter.bridge
	g.close_modal();g.clear_hotspots();g.active_people.clear();clear_ui();g.set_background(b.art)
	g.actors.show();g.hero=g.actor_at(int(b.id),295,2.65)
	g.shade(self,Rect2(0,0,1280,111),Color("0a1319e9"))
	g.label_at(self,"幕间 / "+b.name,Rect2(34,21,1138,39),27,"e1d1aa")
	g.label_at(self,"查阅两份材料，再留下你的意见。",Rect2(34,68,1100,35),19,"afc4b8")
	for i in 2:
		g.button_at(self,("✓ " if i in state.bridge_docs else "· ")+b.docs[i].title,Rect2(555,172+i*89,650,67),func():
			if i not in state.bridge_docs: state.bridge_docs.append(i);persist()
			g.new_modal(b.docs[i].title)
			g.label_at(g.modal,b.docs[i].body,Rect2(34,112,800,279),25)
			g.button_at(g.modal,"读完，回到现场",Rect2(430,445,403,51),show_bridge))
	g.label_at(self,b.question,Rect2(555,371,650,83),24,"ded0a7")
	for i in 2:
		var button=g.button_at(self,b.options[i],Rect2(555,477+i*73,650,57),func(): answer_bridge(i))
		button.disabled=state.bridge_docs.size()!=2
	g.button_at(self,"保存并返回标题",Rect2(34,666,300,37),g.show_title,true)

func answer_bridge(answer: int) -> bool:
	if state.bridge_docs.size()!=2 or state.resolution.is_empty() or answer not in [0,1]: return false
	state.bridge_answer=answer;persist()
	g.start_dialog([[chapter.bridge.name,chapter.bridge.options[answer]+"。"]]+chapter.bridge.lines,func():
		state.bridge_done=true;g.journey.unlocked=maxi(number+1,int(g.journey.unlocked));persist();show_chapter_end())
	return true

func show_chapter_end() -> void:
	g.new_modal("第 %d 章结束 / %s" % [number,chapter.title],true)
	var result: String=""
	for c in chapter.choices:
		if c.id==state.resolution: result=c.label
	g.label_at(g.modal,"事实留下来。\n选择继续发生。",Rect2(47,110,1060,143),44,"e4d2a7")
	g.label_at(g.modal,"六份原件 · 三项推论 · 本案已结\n\n"+result,Rect2(49,297,1042,117),23)
	g.button_at(g.modal,"继续第 %d 章  →" % [number+1],Rect2(650,496,450,57),func(): g.start_campaign(number+1))
	g.button_at(g.modal,"返回标题",Rect2(49,496,270,57),g.show_title,true)
	g.button_at(g.modal,"故事脉络",Rect2(340,496,280,57),func(): g.desk.show_archive(number),true)
	g.lock_choices()

func public_epilogue() -> void:
	if number!=6 or state.resolution.is_empty(): return
	var lines: Array=[]
	match state.resolution:
		"isolate":
			lines=[["旁白","现实侧通过独立供给与停止强制清理的保障案。数字居民另行确认内部治理程序；外部联系仍受限。"],["顾舟","机房换了独立的计量表。亮着的灯暂时稳了，外面的来信却还进不来。"]]
		"open":
			lines=[["旁白","历史材料公开。经双方同意的通信窗口开始试运行；安全争议和资源支出同时列入公开账本。"],["罗荻","第一封获准的家书送到了。第一份越权读取投诉，也在同一天立案。"]]
		"joint":
			lines=[["旁白","实例与原件得到保全，监督通信启用。九十日审查期限和退出办法公开，临时机构无权自行无限续期。"],["闻遥","我把到期日写在最前面。下一次开会，先读这一行。"]]
	if g.journey.choices.get("first_identity")=="independent" and chapter_choice(3)=="separate":
		lines.append(["宋屿","我和闻遥支持这次重新核验。我们在名册里各有自己的位置，不再靠一个旧名字借票。"])
	else:
		lines.append(["宋屿","我接受先保住运行的安排，但仍要求把每个当前的人单列出来。这项保留请继续记。"])
	if chapter_choice(2)=="public": lines.append(["许禾","公开作证后，有人不再愿意雇我。街区给了我核验员的工作，我也得公开自己当年的伪造。"])
	else: lines.append(["许禾","我的身份还由独立核验人保管。街坊知道有一份证词，但我暂时不能公开解释每一个误会。"])
	if chapter_choice(5)=="full": lines.append(["顾舟","完整名册在两处保管。第一批家庭核验已经开始；没同意公开的名字仍封着。"])
	else: lines.append(["顾舟","外部只有摘要。城内原件还在，但部分家庭的查找要等新的查阅窗口，不能说已经全找到了。"])
	if chapter_choice(4)=="public": lines.append(["祝青","两城轮值台第一次贴出双方都看得懂的水表。争吵没停，偷偷改数变难了。"])
	else: lines.append(["祝青","试测到期，两城又开了会。新条款没有被供起来，因为所有人都能要求再测一次。"])
	var life: String=g.journey.choices.get("first_future","")
	lines.append(["苏筠","早餐还是会烤焦。现在他会自己把失败那一页留下来。" if life=="breakfast" else ("铺子延期了。我们偶尔见面，没有拿旧合同追问谁该回来。" if life=="space" else "那份租约后来又被拿出来过。这一次，我们从头商量。")])
	lines.append(["现实林砚","我能提出和承担现实侧的方案，不能替城里的人过完他们的未来。"])
	g.start_dialog(lines,show_private_choice)

func chapter_choice(n: int) -> String:
	return str(g.journey.chapters.get(str(n),{}).get("resolution",""))

func show_private_choice() -> void:
	private_stage()
	g.new_modal("私人尾声 / 生命末期")
	g.label_at(g.modal,"表决之后不久，现实林砚的病情恶化。\n终端询问：是否提交最终人格备份？\n\n上传会创建一份副本。它不能证明此刻的主观体验\n会转移，也不会替任何公共方案补上保证。",Rect2(34,105,805,218),24)
	g.button_at(g.modal,"不上传 / 在这里告别",Rect2(34,353,804,60),func(): private_epilogue("decline"))
	g.button_at(g.modal,"上传 / 提交最终备份指令",Rect2(34,436,804,60),func(): private_epilogue("upload"))
	g.lock_choices()

func private_stage() -> void:
	g.close_modal()
	g.set_background("clinic");g.clear_hotspots();g.active_people.clear();clear_ui()
	g.background.modulate=Color.WHITE
	g.hero=g.actor_at(1,427,2.65)

func private_epilogue(value: String) -> void:
	if number!=6 or state.resolution.is_empty() or value not in ["upload","decline"]: return
	private_stage()
	state.private=value;persist()
	var lines: Array
	if value=="decline":
		lines=[["现实林砚","不用替我延长这一段了。把窗口留给还要说话的人。"],["旁白","终端熄灭。城市的记录继续增加，没有一条要求所有人生使用同一种结尾。"]]
	else:
		lines=[["现实林砚","提交。我知道那不是对连续性的保证。让以后醒来的人，自己决定怎么开始。"],["终端","备份指令已接收。执行结果未在当前窗口确认。"],["旁白","窗外的灯还亮着。我们没有看见一个意识离开身体，也没有得到任何人永远不会失去的承诺。"]]
	g.start_dialog(lines,func(): state.ended=true;persist();show_final_card())

func show_final_card() -> void:
	private_stage()
	g.new_modal("启动阶段 / 一周目结束",true)
	g.label_at(g.modal,"他们终于可以\n自己写下一页。",Rect2(51,99,1044,155),45,"e7d7b2")
	var titles: Dictionary={"isolate":"隔离保存","open":"开放连接","joint":"限期共治"}
	g.label_at(g.modal,"公共方案："+titles.get(state.resolution,"")+"\n私人选择："+("提交最终人格备份" if state.private=="upload" else "不上传，在此告别")+"\n六章案件真相与公共抉择已经完整呈现。",Rect2(54,281,1030,121),24)
	g.label_at(g.modal,"上传是复制，恢复不是复活。\n另一视角的二周目尚未制作；本篇结局不依赖它补充必要真相。",Rect2(54,426,1030,71),19,"adbfb0")
	g.button_at(g.modal,"返回标题",Rect2(54,520,308,46),g.show_title)
	g.button_at(g.modal,"回看公共尾声",Rect2(399,520,308,46),public_epilogue,true)
	g.button_at(g.modal,"章节目录",Rect2(744,520,360,46),g.show_chapters,true)
	g.button_at(g.modal,"证物柜与回访",Rect2(744,472,360,36),func(): g.collection.show_album(6,show_final_card),true)
	g.lock_choices()

func show_hint() -> void:
	g.new_modal("本章调查提示")
	var hint: String=objective()
	if state.evidence.size()<6:
		hint+="\n\n各现场有两份原件。也可询问该处人物，请求出示留存副本。"
	elif not state.puzzle: hint+="\n\n"+chapter.puzzle.hint
	elif state.claims.size()<3:
		hint+="\n\n"
		for key in chapter.claims:
			if key not in state.claims:
				hint+=chapter.evidence[chapter.claims[key].pair[0]].title+" ＋ "+chapter.evidence[chapter.claims[key].pair[1]].title+"\n"
	g.label_at(g.modal,hint,Rect2(34,108,800,301),23)
	g.button_at(g.modal,"回到现场",Rect2(536,459,300,44),g.close_modal)

func show_menu() -> void:
	g.new_modal("暂停 / 第 %d 章" % number)
	g.label_at(g.modal,objective(),Rect2(34,91,803,76),23)
	g.button_at(g.modal,"继续调查",Rect2(34,205,804,48),g.close_modal)
	g.button_at(g.modal,"声音与显示",Rect2(34,273,804,48),g.show_settings,true)
	g.button_at(g.modal,"章节目录",Rect2(34,341,804,48),g.show_chapters,true)
	g.button_at(g.modal,"保存并返回标题",Rect2(34,409,394,48),g.show_title,true)
	g.button_at(g.modal,"退出游戏",Rect2(448,409,390,48),g.request_quit,true)

func handle_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if g.choice_locked: return
	if g.dialog_mode:
		if event.keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]: g.advance_dialog()
		return
	if event.keycode==KEY_ESCAPE:
		if is_instance_valid(g.modal): g.close_modal()
		else: show_menu()
	elif event.keycode==KEY_J: show_journal()
	elif event.keycode in [KEY_H,KEY_TAB]: toggle_hotspots()
	elif event.keycode==KEY_M: g.sound.enabled=not g.sound.enabled;g.sound.refresh()
	elif event.keycode==KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
