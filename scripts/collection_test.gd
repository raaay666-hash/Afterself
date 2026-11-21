extends RefCounted
const UI=preload("res://scripts/playthrough_test.gd")
const DeskTest=preload("res://scripts/investigation_test.gd")

static func text_tree(node: Node) -> String:
	var result: String=node.text if node is Label or node is Button else ""
	result+=node.tooltip_text if node is Control else ""
	for child in node.get_children(): result+=text_tree(child)
	return result

static func reset(g: Node) -> void:
	g.close_modal();g.title_mode=false;g.typewriter=false;g.choice_locked=false
	g.evidence=[];g.observations=[];g.flags={}
	g.journey={"version":5,"chapter":1,"unlocked":1,"chapters":{},"choices":{},"cast_met":[]}

static func run(g: Node) -> void:
	reset(g)
	var c=g.collection
	g.check(c.book().size()==49,"49 authored evidence models")
	var pictures: int=0
	for id in c.book():
		var e: Dictionary=c.book()[id]
		for view in ["icon","front","secondary"]:
			var texture: Texture2D=load("res://assets/evidence-models-v2/"+e.assets[view])
			if texture!=null: pictures+=1
	g.check(pictures==147,"147 exported-ready pixel images load")
	c.show_album(1)
	g.check(c.controls.is_empty(),"uncollected slots have no clickable models")
	for id in c.book():
		g.check(not c.book()[id].title in text_tree(g.modal),"unowned title hidden "+id)
	c.inspect("c6.upload_form")
	g.check(c.active_kind=="album" and not c.book()["c6.upload_form"].title in text_tree(g.modal),"unowned inspection cannot reveal a later item")
	g.close_modal()
	g.collect("calendar",false)
	g.check(c.pending("c1.calendar"),"first acquisition queued")
	g.dialog_mode=true;c._process(0)
	g.check(not is_instance_valid(g.modal),"notification waits for dialogue")
	g.dialog_mode=false;g.choice_locked=true;c._process(0)
	g.check(not is_instance_valid(g.modal),"notification waits for critical choice")
	g.choice_locked=false;c._process(0)
	g.check(c.active_kind=="popup" and c.popup_count==1,"notification appears after dialogue and choice")
	var file: String=g.artifact_path("test-collection-pending.json")
	g.check(g.save_journey(file,true),"pending notification written to isolated disk file")
	var saved: Dictionary=g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(file)))
	g.check("c1.calendar" in saved.collection.pending,"unread notification survives disk round trip")
	c.controls.view.pressed.emit()
	g.check(c.active_kind=="inspect" and not c.pending("c1.calendar"),"immediate inspection acknowledges first popup")
	c.check_point("c1.calendar","front_0")
	c.check_point("c1.calendar","front_0")
	g.check(c.state().inspected["c1.calendar"].size()==1 and "1 /" in c.progress.text,"hotspot is unique and counter refreshes immediately")
	c.inspect("c1.calendar",Callable(),"secondary")
	for h in c.book()["c1.calendar"].hotspots:
		if h.view=="secondary": c.check_point("c1.calendar",h.id)
	var inspected: Array=c.state().inspected["c1.calendar"].duplicate()
	g.close_modal();g.collect("calendar",true)
	g.check(c.active_kind=="inspect" and c.popup_count==1,"repeat acquisition opens inspection without a new popup")
	g.close_modal()
	file=g.artifact_path("test-collection-checked.json")
	g.check(g.save_journey(file,true),"inspection progress saved")
	g.journey=g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(file)));c.reconcile()
	g.check(c.state().inspected["c1.calendar"]==inspected,"front and reverse checks survive reload")
	c.show_album(1)
	g.check(c.controls.size()==1 and c.controls.has("c1.calendar"),"only acquired slot receives image and interaction")
	var bad: Dictionary=c.clean({"stories":["c1.calendar","bad","c1.shoe","c1.shoe"],"pending":["bad","c1.calendar","c1.calendar"],"inspected":{"c1.calendar":["front_0","bad"],"bad":[]}})
	g.check(bad.stories==["c1.shoe"] and bad.pending==["c1.calendar"] and bad.inspected["c1.calendar"]==["front_0"],"malformed collection IDs stripped")
	reset(g);c.reconcile()
	g.check(c.state().stories.is_empty() and c.state().pending.is_empty(),"old save does not invent stories or notices")
	g.observations=["lease"];g.show_observation("lease");g.close_modal();c.reconcile()
	g.check(c.acquired("c1.lease"),"existing lease observation remains collected before calendar")
	reset(g)
	for id in c.book():
		if c.book()[id].category=="collection": g.check(not c.ready(id),"optional story gated "+id)
	DeskTest.completed_fixture(g);g.flags.truth=true
	g.journey.chapters["3"].seen=["闻遥/你为什么如此在意重新编号？"]
	g.journey.chapters["5"].seen=["顾舟/我有过一个孩子？"]
	c.reconcile()
	var total: int=0
	for id in c.book():
		if c.book()[id].category!="collection": continue
		g.check(c.ready(id) and not c.acquired(id),"optional task unlocked without automatic grant "+id)
		c.show_tasks(int(c.book()[id].chapter),c.book()[id].owner)
		g.close_modal()
		g.check(not c.acquired(id),"leaving task page grants nothing "+id)
		c.accept_task(id);g.drain_dialog()
		g.check(c.acquired(id) and c.active_kind=="popup","owner dialogue grants story and popup "+id)
		g.close_modal();total+=1
	g.check(total==12 and c.state().stories.size()==12,"all 12 optional stories have playable tasks")
	file=g.artifact_path("test-collection-all.json");g.save_journey(file,true)
	g.journey=g.Flow.sanitize(JSON.parse_string(FileAccess.get_file_as_string(file)));c.reconcile()
	g.check(c.state().stories.size()==12,"all story gates survive sanitized campaign reload")
	print("COLLECTION TESTS PASSED" if g.test_failures==0 else "COLLECTION FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)

static func window_run(g: Node) -> void:
	g.typewriter=false;g.simulate_walk=true
	await g.get_tree().process_frame
	await UI.click(g,"证物柜")
	g.check(g.collection.controls.is_empty(),"title cabinet starts with blank evidence slots")
	await UI.capture(g,"collection-empty")
	await UI.click(g,"返回调查")
	await UI.click(g,"开始调查   →");await UI.click(g,"跳过开场");await UI.dialog(g)
	await UI.hotspot(g,"calendar")
	g.check(g.collection.active_kind=="popup","walking to calendar opens acquisition popup")
	await UI.capture(g,"collection-acquired")
	await UI.click(g,"立即检查")
	await g.mouse_click(g.collection.controls["front_0"].get_global_rect().get_center())
	g.check("front_0" in g.collection.state().inspected["c1.calendar"],"mouse hotspot saves inspection")
	await UI.capture(g,"collection-inspect")
	await UI.click(g,g.collection.book()["c1.calendar"].secondary_label)
	for h in g.collection.book()["c1.calendar"].hotspots:
		if h.view=="secondary":
			await g.mouse_click(g.collection.controls[h.id].get_global_rect().get_center())
			break
	await UI.capture(g,"collection-reverse")
	await UI.click(g,"返回证物柜")
	g.check(g.collection.controls.size()==1,"cabinet shows only one collected model")
	await UI.capture(g,"collection-filled")
	await UI.click(g,"可调查的物件委托")
	await UI.click(g,"询问："+g.collection.book()["c1.lease"].title)
	await UI.dialog(g)
	g.check(g.collection.acquired("c1.lease") and g.collection.active_kind=="popup","real owner dialogue grants optional keepsake")
	await UI.capture(g,"collection-story")
	await UI.click(g,"稍后查看")
	await UI.hotspot(g,"calendar")
	g.check(g.collection.active_kind=="inspect","revisit goes straight to inspected model")
	await UI.key(g,KEY_ESCAPE)
	g.check(not is_instance_valid(g.modal),"escape closes inspection")
	print("COLLECTION WINDOW TESTS PASSED" if g.test_failures==0 else "COLLECTION WINDOW FAILURES: "+str(g.test_failures))
	g.get_tree().quit(0 if g.test_failures==0 else 1)
