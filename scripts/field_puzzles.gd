extends Node

const Art = preload("res://scripts/puzzle_art.gd")
static var catalog: Dictionary = {}
var g
var active_id: String = ""
var active_stage: int = 0
var controls: Dictionary = {}
var feedback: Label
var selected: int = -1
var digit_cursor: int = 0
var drawing

static func book() -> Dictionary:
	if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fieldwork-v10.json"))
	return catalog

static func ints(raw: Variant) -> Array:
	var result: Array=[]
	if not raw is Array: return result
	for x in raw:
		if not (x is int or x is float) or not is_finite(float(x)) or float(int(x))!=float(x): return []
		result.append(int(x))
	return result

static func legal(s: Dictionary, raw: Variant) -> bool:
	if not raw is Array: return false
	var v: Array=ints(raw)
	if v.size()!=raw.size(): return false
	if s.kind=="toggle":
		var seen: Array=[]
		for x in v:
			if x<0 or x>=s.items.size() or x in seen: return false
			seen.append(x)
		return true
	if v.size()!=s.initial.size(): return false
	if s.kind=="swap":
		var sorted: Array=v.duplicate();sorted.sort()
		return sorted==range(s.items.size())
	for i in v.size():
		var upper: int=10 if s.kind=="digits" else (int(s.limits[i]) if s.kind in ["map","adjust","rotate"] else s.items.size())
		if v[i]<0 or v[i]>=upper: return false
	return true

static func valid(s: Dictionary, raw: Variant) -> bool:
	if not legal(s,raw): return false
	var v: Array=ints(raw)
	if s.kind=="toggle": v.sort()
	return v==ints(s.answer)

static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary={"version":1,"tasks":{}}
	if not raw is Dictionary or not raw.get("tasks") is Dictionary: return out
	for id in book():
		if not raw.tasks.get(id) is Dictionary: continue
		var source: Dictionary=raw.tasks[id];var spec: Dictionary=book()[id]
		var steps: Array=[];var prior: bool=true
		var input_steps: Variant=source.get("steps",[])
		if not input_steps is Array: continue
		for i in spec.stages.size():
			var s: Dictionary=spec.stages[i];var entry: Variant=input_steps[i] if i<input_steps.size() else {}
			var v: Array=ints(s.initial);var passed: bool=false;var hint: int=0
			if entry is Dictionary:
				if legal(s,entry.get("values")): v=ints(entry.values)
				var copy_method: bool=id=="c1b" and i==0 and entry.get("method")=="certified_copy"
				passed=prior and entry.get("passed")==true and (valid(s,v) or copy_method)
				var h: Variant=entry.get("hint",0)
				if h is int or h is float: hint=clampi(int(h),0,3)
			var method: String="certified_copy" if entry is Dictionary and id=="c1b" and i==0 and entry.get("method")=="certified_copy" else ""
			steps.append({"values":v,"passed":passed,"hint":hint,"method":method});prior=passed
		out.tasks[id]={"steps":steps}
	return out

func data() -> Dictionary:
	if not g.journey.has("field"): g.journey.field={"version":1,"tasks":{}}
	return g.journey.field

func task(id: String) -> Dictionary:
	if not data().tasks.has(id):
		var steps: Array=[]
		for s in book()[id].stages: steps.append({"values":ints(s.initial),"passed":false,"hint":0})
		data().tasks[id]={"steps":steps}
	return data().tasks[id]

func reached(id: String) -> bool:
	return book().has(id) and int(book()[id].chapter)<=int(g.journey.unlocked)

func acquired(n: int) -> Array:
	return g.evidence if n==1 else g.journey.chapters.get(str(n),{}).get("evidence",[])

func event_ready(id: String) -> bool:
	var p: Dictionary=book()[id]
	if not p.optional: return true
	if p.event=="truth": return g.flags.get("truth",false)
	if p.event=="wen": return "闻遥/你为什么如此在意重新编号？" in g.journey.chapters.get("3",{}).get("seen",[])
	if p.event=="ended": return g.journey.chapters.get("6",{}).get("ended",false)
	return true

func ready(id: String, index: int) -> bool:
	if not reached(id) or not event_ready(id): return false
	var stages: Array=book()[id].stages
	if index<0 or index>=stages.size(): return false
	for i in index:
		if not passed(id,i): return false
	var s: Dictionary=stages[index]
	if id=="c1b" and index==0 and task(id).steps[0].get("method")=="certified_copy": return "access" in g.evidence and g.flags.get("ledger",false)
	for dep in s.needs:
		if not finished(dep): return false
	for key in s.requires:
		if key not in acquired(int(book()[id].chapter)): return false
	return true

func passed(id: String, index: int) -> bool:
	if not reached(id): return false
	var t: Dictionary=task(id)
	if index<0 or index>=t.steps.size(): return false
	if id=="c1b" and index==0 and t.steps[0].get("method")=="certified_copy": return t.steps[0].passed and ready(id,0)
	return t.steps[index].passed and valid(book()[id].stages[index],t.steps[index].values) and ready(id,index)

func finished(id: String) -> bool:
	if not reached(id): return false
	for i in book()[id].stages.size():
		if not passed(id,i): return false
	return true

func phase(id: String) -> int:
	for i in book()[id].stages.size():
		if not passed(id,i): return i
	return book()[id].stages.size()-1

func exempt(n: int) -> bool:
	# Existing confrontations and closed cases are never reopened by new puzzle gates.
	return g.completed or g.court_step>0 if n==1 else int(g.journey.chapters.get(str(n),{}).get("court",0))>0

func chapter_done(n: int) -> bool:
	return exempt(n) or (finished("c%da" % n) and finished("c%db" % n))

func next_task(n: int) -> String:
	for suffix in ["a","b"]:
		var id: String="c%d%s" % [n,suffix]
		if not finished(id): return id
	return "c%db" % n

func evidence_gate(n: int, key: String) -> String:
	if n==3 and key in ["upload","chain"] and key not in acquired(n) and not chapter_done(3): return "c3b"
	var gates: Dictionary={"2.utility":"c2a","2.stamp":"c2b","3.reuse":"c3a","3.dissent":"c3a","4.original":"c4a","4.revision":"c4a","5.port":"c5b","6.roll":"c6a","6.attachment":"c6b"}
	var id: String=gates.get("%d.%s" % [n,key],"")
	if id.is_empty() or key in acquired(n): return ""
	# Authorized certified copies retain the record, but do not solve the new board.
	for i in book()[id].stages.size():
		if key in book()[id].stages[i].grant and not passed(id,i): return id
	return ""

func grant(n: int, key: String) -> void:
	if key in acquired(n): return
	if n==1: g.collect(key,false)
	else:
		var state: Dictionary=g.journey.chapters[str(n)]
		state.evidence.append(key);g.collection.enqueue("c%d.%s" % [n,key]);g.campaign_flow.persist()

func certify(id: String, index: int) -> bool:
	if not ready(id,index): return false
	var s: Dictionary=book()[id].stages[index];var entry: Dictionary=task(id).steps[index]
	if not valid(s,entry.values): return false
	entry.passed=true
	entry.method=""
	var n: int=int(book()[id].chapter)
	for key in s.grant: grant(n,key)
	if id=="c1a": g.flags.drawer=true;g.save_game()
	if id=="c1b" and index==0: g.flags.ledger=true;g.maybe_access();g.save_game()
	if finished(id) and not book()[id].optional and finished("c%da" % n) and finished("c%db" % n):
		var c: Dictionary=g.Desk.book()[str(n)]
		var values: Array=range(c.pieces.size()) if c.kind=="order" else ints(c.correct if c.kind=="compare" else c.solution)
		g.desk.task_state(n).values=values
		g.desk.verify(n)
		if n>1:
			var state: Dictionary=g.journey.chapters[str(n)]
			state.answers=ints(g.Flow.book()[str(n)].puzzle.correct);state.puzzle=true
			g.campaign_flow.persist()
	g.save_journey();g.sound.play("lock" if s.art in ["lock","door"] else "found")
	g.refresh_field_scene()
	return true

func request_custody_copy() -> void:
	if "order" not in g.evidence: return
	g.start_dialog([["闻遥","我按 M-204 申请管理处签收簿的认证副本。这和门内那一份是同一来源。"],["闻遥","副本只有领取和归还。仍需向值班邻居和邵为核对转交与补发，不会因多拿一份就证明执行责任。"]],func():
		g.flags.ledger=true;g.maybe_access()
		var entry: Dictionary=task("c1b").steps[0]
		if not passed("c1b",0): entry.method="certified_copy";entry.passed=true
		g.save_game();open("c1b"))

func show_chapter(n: int = 0) -> void:
	if n==0: n=int(g.journey.chapter)
	if n>int(g.journey.unlocked): return
	g.new_modal("现场操作 / 第 %d 章" % n,true)
	active_id="";controls.clear()
	g.label_at(g.modal,"现场入口、原件核验与人物侧记共用同一进度。",Rect2(34,75,1080,32),20,"adbfaf")
	for ch in range(1,int(g.journey.unlocked)+1):
		g.button_at(g.modal,"第 %d 章" % ch,Rect2(34+(ch-1)*181,110,168,28),func(): show_chapter(ch),true)
	for i in 2:
		var id: String="c%d%s" % [n,"a" if i==0 else "b"]
		var p: Dictionary=book()[id]
		g.panel_at(g.modal,Rect2(34+i*552,143,534,227),"22362e")
		g.label_at(g.modal,p.title,Rect2(51+i*552,161,498,48),24,"e5d3a8")
		g.label_at(g.modal,p.scene,Rect2(51+i*552,220,495,48),20,"aac0ad")
		g.button_at(g.modal,"回看操作" if finished(id) else "继续调查与操作",Rect2(52+i*552,300,493,51),func(): open(id))
	var sid: String="s%d" % n
	var optional_ready: bool=ready(sid,0)
	var b=g.button_at(g.modal,("已留侧记 / " if finished(sid) else "可选 / ")+book()[sid].title if optional_ready else "人物侧记 / 尚未获准或缺少材料",Rect2(34,393,1085,52),func(): open(sid),true)
	b.disabled=not optional_ready
	g.label_at(g.modal,"旧版已开始对质或结案的进度保留，可自愿回访新操作。" if exempt(n) else "错误不消耗材料；遇到障碍可请求三级提示或回查来源。",Rect2(34,457,1080,47),20,"c4b17e")
	g.button_at(g.modal,"返回调查",Rect2(745,528,375,42),g.close_modal,true)

func open(id: String, requested: int = -1) -> void:
	if not reached(id): return
	if id=="c1a" and "su/drawer" not in g.seen_topics:
		g.start_dialog([["苏筠","可以查看抽屉。他改成了三位日期锁，锁签写着从和好的那天开始。"],["林砚","我只留存获准的记录，原物放回。"]],func():
			g.seen_topics.append("su/drawer");g.save_game();open(id,requested))
		return
	var p: Dictionary=book()[id];var index: int=phase(id) if requested<0 else clampi(requested,0,p.stages.size()-1)
	if index>phase(id): index=phase(id)
	var s: Dictionary=p.stages[index];var entry: Dictionary=task(id).steps[index]
	g.new_modal(p.title,true)
	active_id=id;active_stage=index;controls.clear();selected=-1;digit_cursor=0
	g.label_at(g.modal,"%02d / %02d   %s" % [index+1,p.stages.size(),s.title],Rect2(34,76,1093,38),24,"ddc38e")
	for i in p.stages.size():
		var b=g.button_at(g.modal,("+ " if passed(id,i) else "· ")+str(i+1),Rect2(34+i*65,117,57,27),func(): open(id,i),true)
		b.disabled=i>phase(id)
	if not ready(id,index):
		var text: String="先补足调查依据：\n\n"
		if not event_ready(id): text+="等待当事人主动公开，或完成本次尾声。\n"
		if id=="c1b" and index==0 and entry.get("method")=="certified_copy": text+="副本已收到，仍需询问邵为与值班邻居核对凭据保管。\n"
		for dep in s.needs:
			if not finished(dep): text+="完成："+book()[dep].title+"\n"
		for key in s.requires:
			if key not in acquired(int(p.chapter)):
				text+=(g.Data.EVIDENCE[key][0] if int(p.chapter)==1 else g.Flow.book()[str(p.chapter)].evidence[key].title)+"\n"
		g.label_at(g.modal,text,Rect2(40,170,1080,257),24)
		g.label_at(g.modal,"可回到现场或向保管人申请同源认证副本。副本不算独立互证。",Rect2(40,444,1080,65),20,"baa77b")
		button("menu","操作目录",Rect2(34,530,230,42),func(): show_chapter(int(p.chapter)))
		button("close","返回调查",Rect2(772,530,348,42),g.close_modal)
		return
	var via_copy: bool=id=="c1b" and index==0 and entry.get("method")=="certified_copy"
	drawing=Art.new();drawing.kind="receipt" if via_copy else s.art;drawing.values=entry.values;drawing.sealed=passed(id,index)
	drawing.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.modal.add_child(drawing);drawing.position=Vector2(30,147);drawing.size=Vector2(720,304)
	g.panel_at(g.modal,Rect2(775,147,344,300),"22372e")
	g.label_at(g.modal,"现场规则与来源",Rect2(790,163,319,31),20,"dcc58c")
	g.label_at(g.modal,s.rule,Rect2(790,207,314,205),20,"d5d9bb")
	feedback=g.label_at(g.modal,"通过认证副本完成取件，未实际修门。来源仍须和独立回执共同核对。" if via_copy else (s.result if passed(id,index) else "选择实物并操作，再核验；已检查原件可从下方回查。"),Rect2(34,455,1085,66),20,"d8bf86")
	if via_copy: g.label_at(g.modal,"签收簿认证副本\n同一来源 / 没有新增互证\n维修门仍保持原状态",Rect2(85,241,610,142),24,"293b35")
	else: build_controls(s,entry,passed(id,index))
	button("verify","下一阶段 →" if passed(id,index) and index<p.stages.size()-1 else ("返回操作目录" if passed(id,index) else "核验操作结果"),Rect2(806,532,312,42),func():
		if passed(id,index):
			if index<p.stages.size()-1: open(id,index+1)
			else: show_chapter(int(p.chapter))
		elif certify(id,index): open(id,index)
		else: feedback.text=error_text(s,entry.values))
	button("hint","逐步提示",Rect2(34,532,175,42),func():
		entry.hint=mini(3,int(entry.hint)+1);g.save_journey();feedback.text="%d / 3  %s" % [entry.hint,s.hints[int(entry.hint)-1]])
	button("sources","回查原件",Rect2(223,532,175,42),func():
		g.collection.show_album(int(p.chapter),func(): open(id,index)))
	button("menu","操作目录",Rect2(412,532,175,42),func(): show_chapter(int(p.chapter)))
	var reset=button("reset","重置本步",Rect2(601,532,188,42),func():
		entry.values=ints(s.initial);g.save_journey();open(id,index))
	reset.disabled=passed(id,index)

func button(key: String, text: String, rect: Rect2, action: Callable, transparent: bool = false, paper_color: bool = false) -> Button:
	var b: Button=g.button_at(g.modal,text,rect,action,transparent)
	b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;b.clip_text=true
	b.add_theme_color_override("font_disabled_color",Color("d8d5c8"))
	if transparent:
		for name in ["normal","disabled"]:
			var style: StyleBoxFlat=g.box_style("00000000","00000000",0);style.shadow_size=0
			b.add_theme_stylebox_override(name,style)
	if paper_color:
		for name in ["font_color","font_disabled_color"]: b.add_theme_color_override(name,Color("293b35"))
	controls[key]=b
	return b

func build_controls(s: Dictionary, entry: Dictionary, readonly: bool) -> void:
	var v: Array=entry.values;var count: int=v.size()
	match s.kind:
		"digits":
			for i in 3:
				g.label_at(g.modal,s.items[i],Rect2(119+i*196,160,148,32),20,"f0d89a")
				var b=button("slot/%d" % i,str(v[i]),Rect2(128+i*196,223,112,116),func(): change(i,(int(v[i])+1)%10),true,true)
				b.add_theme_font_size_override("font_size",48);b.disabled=readonly
			g.label_at(g.modal,"键盘输入数字；回车核验。点击数字轮可逐格转动。",Rect2(53,409,677,35),20,"d6c897")
		"choice":
			if s.art=="door": g.label_at(g.modal,"门锁保险座 / 2A",Rect2(113,188,495,38),20,"c6cdb0")
			for i in s.items.size():
				var w: float=690.0/s.items.size()
				var rect: Rect2=Rect2(94+i*200,272,144,119) if s.art=="door" else Rect2(43+i*w,253,w-12,133)
				var b=button("item/%d" % i,("[X] " if i==int(v[0]) else "[ ] ")+str(s.items[i]).replace("／","\n"),rect,func(): change(0,i),s.art=="door",s.art=="door")
				b.disabled=readonly
			if s.art=="debug":
				g.label_at(g.modal,"旧端口等回执 →",Rect2(72,178,293,62),20,"d8cfaa")
				g.label_at(g.modal,"← 审查端等结束",Rect2(449,178,265,62),20,"d8cfaa")
		"swap":
			var w: float=690.0/count
			for i in count:
				g.label_at(g.modal,s.slots[i] if s.slots.size()==count else "%02d" % [i+1],Rect2(45+i*w,158,w-14,41),20,"d5bd86")
				var b=button("slot/%d" % i,str(s.items[int(v[i])]),Rect2(48+i*w,218,w-21,162),func(): swap_at(i),s.art in ["tape","rubbing","archive","letters"],s.art in ["tape","rubbing","archive","letters"])
				if s.art=="tape": b.add_theme_font_size_override("font_size",36)
				b.disabled=readonly
			g.label_at(g.modal,"点一张拿起，再点另一张交换；点原张取消。",Rect2(49,409,683,34),20,"cfbe91")
		"assign":
			var w: float=690.0/count
			for i in count:
				var b=button("slot/%d" % i,s.slots[i]+"\n"+str(s.items[int(v[i])]),Rect2(44+i*w,164,w-12,109),func():
					selected=i;highlight_slots(count);feedback.text="已选："+s.slots[i]+"。再点下面的记录放入。")
				b.disabled=readonly
			var columns: int=3 if s.items.size() in [3,5,6] else (4 if s.items.size()==4 else 2)
			var bank_width: float=690.0/columns
			for i in s.items.size():
				var b=button("item/%d" % i,s.items[i],Rect2(44+(i%columns)*bank_width,327+int(i/columns)*57,bank_width-12,50),func():
					if selected<0: feedback.text="先点上方一个目标槽，再选记录。";return
					change(selected,i))
				b.disabled=readonly
		"toggle":
			var mask: bool=s.art=="mask_read"
			var ballots: bool=s.art=="ballots"
			var columns: int=4 if mask else (3 if ballots else 2)
			var w: float=690.0/columns
			var h: int=60 if mask else 76
			for i in s.items.size():
				var rect: Rect2=Rect2(44+(i%columns)*w,165+int(i/columns)*h,w-12,h-9)
				if mask: rect=Rect2(82+(i%4)*156,171+int(i/4)*56,144,48)
				elif ballots: rect=Rect2(64+(i%3)*232,179+int(i/3)*132,186,82)
				var item_text: String=str(s.items[i]).replace("／","\n") if ballots else str(s.items[i])
				var b=button("item/%d" % i,("[X] " if i in v else "[ ] ")+item_text,rect,func():
					if i in v: v.erase(i)
					else: v.append(i)
					g.save_journey();open(active_id,active_stage),mask or ballots,mask or ballots)
				b.disabled=readonly
			g.label_at(g.modal,"有效意见不等于赞成；这六张只是核验样例。" if s.art=="ballots" else ("从上到下读取金框的孔，不读取其余字组。" if mask else "逐项检查；全选不代表材料充分。"),Rect2(48,410,684,32),20,"ccbd94")
		"map":
			g.label_at(g.modal,"初始底图",Rect2(63,159,270,29),20,"40574a")
			g.label_at(g.modal,"改建透明层",Rect2(431,159,267,29),20,"40574a")
			for axis in 2:
				for direction in [-1,1]:
					var x: int=45+axis*252+(0 if direction<0 else 118)
					var label: String=("←" if direction<0 else "→") if axis==0 else ("↑" if direction<0 else "↓")
					var b=button("map/%d/%d" % [axis,direction],label,Rect2(x,412,106,32),func(): change(axis,clampi(int(v[axis])+direction,0,4)))
					b.disabled=readonly
			var b=button("rotate","旋转90°",Rect2(559,412,163,32),func(): change(2,(int(v[2])+1)%4));b.disabled=readonly
		"adjust":
			for i in 2:
				g.label_at(g.modal,s.items[i],Rect2(110+i*350,162,253,32),20,"e0c691")
				g.label_at(g.modal,"修正 %+d / 标准槽 %d" % [int(v[i])-3,(18 if i==0 else 23)+int(v[i])-3],Rect2(97+i*350,342,289,46),24,"e2d9b7")
				for direction in [-1,1]:
					var b=button("adjust/%d/%d" % [i,direction],"-" if direction<0 else "+",Rect2(142+i*350+(0 if direction<0 else 119),406,103,38),func(): change(i,clampi(int(v[i])+direction,0,6)))
					b.disabled=readonly
		"rotate":
			g.label_at(g.modal,"定位标必须向上",Rect2(68,164,610,36),20,"293b35")
			var b=button("rotate","转动遮罩 90° / 当前%d°" % [int(v[0])*90],Rect2(156,410,470,34),func(): change(0,(int(v[0])+1)%4));b.disabled=readonly

func highlight_slots(count: int) -> void:
	for i in count: controls["slot/%d" % i].modulate=Color("edd49b") if i==selected else Color.WHITE

func change(index: int, value: int) -> void:
	var id: String=active_id;var at: int=active_stage
	if id.is_empty() or not ready(id,at) or passed(id,at): return
	task(id).steps[at].values[index]=value;g.sound.play("click");g.save_journey();open(id,at)

func swap_at(index: int) -> void:
	if selected<0:
		selected=index;highlight_slots(task(active_id).steps[active_stage].values.size());feedback.text="已拿起一张，再点另一张交换。";return
	var v: Array=task(active_id).steps[active_stage].values
	var old: int=int(v[index]);v[index]=v[selected];v[selected]=old
	selected=-1;g.save_journey();open(active_id,active_stage)

func error_text(s: Dictionary, v: Array) -> String:
	if s.kind=="digits": return "锁没有打开。核对和好日期与月／日格式，已取得材料不会丢失。"
	if s.kind=="choice" and s.art=="door": return "保险芯规格不符。检修座拒绝接入，备件未损耗；核对2A、铜壳、圆脚。"
	if s.kind=="toggle": return "还有误选或遗漏。逐项对照来源，不要用全选代替核验。"
	if s.kind=="map": return "三个定位点仍有重影。先转正，再核对横纵偏移。"
	if s.kind=="adjust": return "标准槽两表尚未共同显示20。只改校正值，不改现场水量。"
	for i in v.size():
		if int(v[i])!=int(s.answer[i]): return "第%d个位置仍与来源不符。回查规则，再操作；不会损失调查进度。" % [i+1]
	return "来源或前序条件尚不完整。"

func handle_key(event: InputEvent) -> bool:
	if active_id.is_empty() or not is_instance_valid(g.modal) or not event is InputEventKey or not event.pressed or event.echo: return false
	var s: Dictionary=book()[active_id].stages[active_stage]
	if s.kind!="digits" or not ready(active_id,active_stage) or passed(active_id,active_stage): return false
	if event.keycode in [KEY_ENTER,KEY_KP_ENTER]: controls.verify.pressed.emit();return true
	var number: int=event.unicode-48
	if number>=0 and number<=9:
		var cursor: int=digit_cursor;change(cursor,number);digit_cursor=(cursor+1)%3;return true
	if event.keycode==KEY_BACKSPACE:
		var cursor: int=(digit_cursor+2)%3;change(cursor,0);digit_cursor=cursor;return true
	return false

func modal_closed() -> void:
	active_id="";controls.clear();selected=-1
