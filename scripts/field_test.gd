extends RefCounted
const UI = preload("res://scripts/playthrough_test.gd")

static func fixture(g: Node, n: int) -> void:
	preload("res://scripts/investigation_test.gd").completed_fixture(g)
	g.journey.chapter=n;g.journey.unlocked=n;g.seen_topics=["su/drawer"]
	g.flags={"truth":true};g.court_step=0;g.typewriter=false
	if n==1:
		g.completed=false;g.journey.choices={}
	else:
		var s: Dictionary=g.journey.chapters[str(n)]
		s.court=0;s.resolution="";s.resolution_seen=false;s.bridge_done=false;s.private="";s.ended=false;s.puzzle=false;s.answers=[]
		if n==3: s.seen=["闻遥/你为什么如此在意重新编号？"]

static func solve_logic(g: Node, id: String) -> bool:
	var okay: bool=true
	for i in g.Field.book()[id].stages.size():
		g.field.task(id).steps[i].values=g.Field.ints(g.Field.book()[id].stages[i].answer)
		okay=g.field.certify(id,i) and okay
	return okay

static func run(g: Node) -> void:
	g.typewriter=false
	g.check(g.Field.book().size()==18,"twelve main segments plus six optional puzzles authored")
	for n in range(1,7):
		fixture(g,n)
		g.check(not g.field.chapter_done(n),"new chapter cannot skip its manipulation "+str(n))
		for suffix in ["a","b"]:
			var id: String="c%d%s" % [n,suffix]
			var p: Dictionary=g.Field.book()[id]
			for i in p.stages.size():
				var s: Dictionary=p.stages[i];var state: Dictionary=g.field.task(id).steps[i]
				g.check(g.Field.legal(s,s.initial),"authored initial state legal "+id+"/"+str(i))
				var prior_count: int=g.field.acquired(n).size()
				state.values=[] if s.kind!="toggle" else range(s.items.size())
				g.check(not g.field.certify(id,i),"wrong or all-selected board rejected "+id+"/"+str(i))
				g.check(prior_count==g.field.acquired(n).size(),"wrong operation does not consume or grant records")
				state.values=g.Field.ints(s.initial)
				var restored: Dictionary=g.Flow.sanitize(JSON.parse_string(JSON.stringify(g.journey)))
				g.check(restored.field.tasks[id].steps[i].values==state.values,"partial operation survives save "+id+"/"+str(i))
				state.values=g.Field.ints(s.answer)
				g.check(g.field.certify(id,i),"sources and correct operation certify "+id+"/"+str(i))
				g.check(g.field.passed(id,i),"certification rechecks source and predecessors")
			g.check(g.field.finished(id),"segment complete "+id)
		g.check(g.field.chapter_done(n) and g.desk.done(n),"new flow closes existing desk without duplicate operation "+str(n))
		if n>1: g.check(g.journey.chapters[str(n)].puzzle,"existing narrative puzzle flags derive from new flow "+str(n))
		var sid: String="s%d" % n
		if n==6: g.journey.chapters["6"].ended=true
		g.check(solve_logic(g,sid) and g.field.finished(sid),"optional puzzle with consent/event "+sid)
		var file: String=g.artifact_path("test-field-%d.json" % n)
		g.check(g.save_journey(file,true),"isolated checkpoint writes "+str(n))
		var saved: Dictionary=g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(file)))
		g.check(saved.field.tasks.has("c%da" % n),"disk checkpoint preserves puzzle stages")
	fixture(g,1)
	g.evidence=[];g.field.task("c1a").steps[0].values=[7,1,4]
	g.check(not g.field.certify("c1a",0) and "note" not in g.evidence,"guessed code without observed calendar rejected")
	g.evidence=["calendar"];g.check(g.field.certify("c1a",0) and "note" in g.evidence,"date lock obtains real note exactly once")
	var count: int=g.evidence.size();g.field.certify("c1a",0)
	g.check(g.evidence.size()==count,"repeated certification is idempotent")
	fixture(g,1)
	g.evidence=["calendar","order","restore","receipt","note","testimony"]
	g.flags={};g.field.request_custody_copy();g.drain_dialog()
	g.check(g.field.task("c1b").steps[0].get("method")=="certified_copy" and not g.field.passed("c1b",0),"certified copy still requires custody witnesses")
	g.flags.credential=true;g.flags.neighbor=true;g.maybe_access()
	g.check(g.field.passed("c1b",0) and "access" in g.evidence,"certified copy is a playable alternative acquisition route")
	g.check(g.field.task("c1b").steps[0].values==[2],"copy route does not invent physical repair")
	var copied: Dictionary=g.Flow.sanitize(JSON.parse_string(JSON.stringify(g.journey)))
	g.check(copied.field.tasks.c1b.steps[0].method=="certified_copy","copy method survives migration")
	fixture(g,2)
	g.journey.chapters["2"].evidence=["map","deeds"]
	g.check(g.field.evidence_gate(2,"utility")=="c2a","account book is behind map entry")
	g.check(solve_logic(g,"c2a") and "utility" in g.field.acquired(2),"map solving really grants book")
	g.check(solve_logic(g,"c2b") and "stamp" in g.field.acquired(2),"template query really grants generation record")
	fixture(g,5)
	g.field.task("c5b").steps[0].values=[0,1,2,3]
	g.check(not g.field.certify("c5b",0),"communication needs prior fault investigation")
	g.check(not g.Field.legal(g.Field.book().c5b.stages[2],[1,1,6]),"duplicate masking selections rejected")
	fixture(g,3)
	g.journey.chapters["3"].scene=2;g.start_campaign(3)
	g.check(g.campaign_flow.state.scene==0 and g.campaign_flow.controls.has("item/old"),"legacy upload-room resume returns to usable investigation scene")
	g.close_modal()
	g.journey.chapters["3"].seen=[]
	g.check(not g.field.ready("s3",0),"Wen's private clock is not exposed before her account")
	var corrupt: Dictionary=g.Field.clean({"tasks":{
		"c1a":{"steps":[{"values":[7,1.4,4],"passed":true}]},
		"c1b":{"steps":[{"values":[2],"passed":true},{"values":[0,1,2,3],"passed":true},{"values":[0,2],"passed":true}]},
		"c3a":{"steps":[{"values":[0,0,2],"passed":true}]},
		"c6a":{"steps":[{"values":[0,2,2,3],"passed":true}]},
		"unknown":{"steps":[{"passed":true}]}}})
	g.check(not corrupt.tasks.c1a.steps[0].passed,"fractional code cannot certify")
	g.check(not corrupt.tasks.c1b.steps[2].passed,"forged later phase cannot skip wrong predecessor")
	g.check(not corrupt.tasks.c3a.steps[0].passed and not corrupt.tasks.c6a.steps[0].passed,"duplicate cards and votes cannot certify")
	g.check(not corrupt.tasks.has("unknown"),"unknown puzzle id discarded")
	fixture(g,6)
	var legacy: Dictionary=g.journey.duplicate(true);legacy.erase("field")
	var migrated: Dictionary=g.Flow.sanitize(legacy)
	g.check(migrated.unlocked==6 and migrated.field.tasks.is_empty(),"old save preserves unlocks without inventing new play")
	g.journey=migrated;g.journey.chapters["6"].court=1
	g.check(g.field.chapter_done(6),"ongoing legacy confrontation is not blocked")
	g.check(g.FIRST_PATH.ends_with("-v10.json") and g.JOURNEY_PATH.ends_with("-v10.json"),"new files never write into v9 saves")
	print("FIELD LOGIC TESTS PASSED" if g.test_failures==0 else "FIELD FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)

static func click_control(g: Node, key: String) -> void:
	await g.get_tree().process_frame
	g.check(g.field.controls.has(key),"visible puzzle control "+key)
	if not g.field.controls.has(key): return
	await g.mouse_click(g.field.controls[key].get_global_rect().get_center())

static func operate_window(g: Node, id: String, index: int, capture: bool = false) -> void:
	g.field.open(id,index);await UI.dialog(g)
	var s: Dictionary=g.Field.book()[id].stages[index]
	var answer: Array=g.Field.ints(s.answer)
	if g.field.passed(id,index): return
	g.check(g.field.ready(id,index),"mouse puzzle has sources "+id+"/"+str(index))
	if not g.field.ready(id,index): return
	if capture:
		await UI.capture(g,id+"-%d-before" % index)
		await click_control(g,"verify")
		g.check(not g.field.passed(id,index),"wrong initial mouse submission rejected")
	match s.kind:
		"digits":
			for digit in "714": await UI.key(g,digit.unicode_at(0),digit.unicode_at(0))
		"choice": await click_control(g,"item/%d" % int(answer[0]))
		"swap":
			for i in answer.size():
				var v: Array=g.field.task(id).steps[index].values
				var at: int=v.find(answer[i])
				if at!=i:
					await click_control(g,"slot/%d" % i);await click_control(g,"slot/%d" % at)
		"assign":
			for i in answer.size():
				await click_control(g,"slot/%d" % i);await click_control(g,"item/%d" % int(answer[i]))
		"toggle":
			for i in s.items.size():
				if (i in g.field.task(id).steps[index].values)!=(i in answer): await click_control(g,"item/%d" % i)
		"map":
			for axis in 2:
				for _tick in 5:
					var now: int=int(g.field.task(id).steps[index].values[axis])
					if now==int(answer[axis]): break
					await click_control(g,"map/%d/%d" % [axis,1 if now<int(answer[axis]) else -1])
			for _tick in 4:
				if int(g.field.task(id).steps[index].values[2])==int(answer[2]): break
				await click_control(g,"rotate")
		"adjust":
			for axis in 2:
				for _tick in 7:
					var now: int=int(g.field.task(id).steps[index].values[axis])
					if now==int(answer[axis]): break
					await click_control(g,"adjust/%d/%d" % [axis,1 if now<int(answer[axis]) else -1])
		"rotate":
			for _tick in 4:
				if int(g.field.task(id).steps[index].values[0])==int(answer[0]): break
				await click_control(g,"rotate")
	await click_control(g,"verify")
	g.check(g.field.passed(id,index),"actual mouse/keyboard solves "+id+"/"+str(index))
	if capture: await UI.capture(g,id+"-%d-after" % index)

static func solve_window(g: Node, id: String, capture: bool = false) -> void:
	for i in g.Field.book()[id].stages.size(): await operate_window(g,id,i,capture)
	g.check(g.field.finished(id),"window segment completed "+id)

static func window_run(g: Node) -> void:
	g.typewriter=false
	for n in range(1,7):
		fixture(g,n)
		if n==1:
			g.enter_scene("corridor",false);g.close_modal()
			g.check(not g.field_scene_art.sealed,"scene door starts closed")
			await g.get_tree().process_frame
			g.check(g.status_tag.get_visible_line_count()==g.status_tag.get_line_count(),"first chapter progress text is fully visible")
			g.check(g.objectives.get_visible_line_count()==g.objectives.get_line_count(),"first chapter objective text is fully visible")
			await UI.capture(g,"field-door-closed")
			g.enter_scene("apartment",false)
		else: g.start_campaign(n);g.drain_dialog()
		for suffix in ["a","b"]: await solve_window(g,"c%d%s" % [n,suffix],true)
		if n==1:
			g.enter_scene("corridor",false);g.close_modal()
			g.check(g.field_scene_art.sealed,"scene door remains open after solved board")
			await UI.capture(g,"field-door-open")
		if n==6: g.journey.chapters["6"].ended=true
		await solve_window(g,"s%d" % n,true)
		g.field.open("c%da" % n,0)
		await click_control(g,"sources")
		g.check(is_instance_valid(g.modal) and g.collection.active_kind=="album","source lookup opens actual collected items")
		g.collection.dismiss()
		g.check(g.field.active_id=="c%da" % n,"source lookup returns to same puzzle stage")
	print("FIELD WINDOW TESTS PASSED" if g.test_failures==0 else "FIELD WINDOW FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)

static func dismiss_notices(g: Node) -> void:
	g.close_modal()
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	while not g.collection.state().pending.is_empty():
		if not is_instance_valid(g.modal): g.collection.popup(str(g.collection.state().pending[0]))
		await UI.click(g,"稍后查看")
		await g.get_tree().process_frame

static func story_run(g: Node, continue_campaign: bool = true) -> void:
	g.typewriter=false;g.simulate_walk=true
	await UI.click(g,"开始调查   →");await UI.click(g,"跳过开场");await UI.dialog(g)
	await UI.hotspot(g,"calendar");await UI.click(g,"稍后查看")
	await UI.hotspot(g,"drawer");await UI.dialog(g)
	await solve_window(g,"c1a",true);await dismiss_notices(g)
	await UI.hotspot(g,"song");await UI.click(g,"·  最后一件记得的事是什么？");await UI.dialog(g);await dismiss_notices(g)
	await UI.click(g,"维修走廊")
	await UI.hotspot(g,"order");await UI.click(g,"稍后查看")
	await UI.hotspot(g,"access");await operate_window(g,"c1b",0,true);await dismiss_notices(g)
	await UI.hotspot(g,"shao");await UI.click(g,"·  维护凭据借给过别人吗？");await UI.dialog(g);g.close_modal()
	await UI.hotspot(g,"neighbor");await UI.dialog(g);await dismiss_notices(g)
	await UI.click(g,"居民档案室")
	await UI.hotspot(g,"terminal");await UI.click(g,"留存恢复登记");await dismiss_notices(g)
	await UI.hotspot(g,"receipt");await dismiss_notices(g)
	g.check(g.evidence.size()==7,"new scene entry route obtains all seven original records")
	await solve_window(g,"c1b",true);await dismiss_notices(g)
	await UI.click(g,"07号公寓");await UI.hotspot(g,"su")
	await UI.click(g,"先让宋屿知情，由他邀请苏筠");await UI.dialog(g);g.close_modal()
	await UI.click(g,"案 卷  [ J ]")
	for pair in [["宋屿的陈述","恢复登记"],["凭据签收与见证","独立执行回执"],["未寄出的举报便条","夜间维修单"]]:
		await UI.click(g,pair[0]);await UI.click(g,pair[1]);await UI.click(g,"组合这两份记录");await UI.click(g,"写入案卷")
	await UI.click(g,"返回现场");await UI.click(g,"维修走廊");await UI.hotspot(g,"shao")
	for title in ["不是失忆，是实例替换","M-204 的实际执行人","被删除的举报动机"]:
		await UI.click(g,title);await UI.dialog(g)
	await UI.click(g,"封存本案，先交清楚已核实的事实");await UI.dialog(g)
	await UI.click(g,"07号公寓");await UI.hotspot(g,"song");await UI.dialog(g)
	await UI.click(g,"单列现行实例，保留历史联系");await UI.dialog(g)
	await UI.click(g,"查看维护窗口与清理附页");await UI.dialog(g)
	g.check(g.completed,"new first chapter scene route reaches unchanged case ending")
	if not continue_campaign:
		print("FIRST CHAPTER WINDOW PLAYTHROUGH PASSED" if g.test_failures==0 else "FIRST CHAPTER FAILURES: "+str(g.test_failures))
		g.get_tree().quit(0 if g.test_failures==0 else 1);return
	await UI.click(g,"继续第二章  →");await UI.dialog(g)
	await preload("res://scripts/campaign_test.gd").window_run(g,true)
