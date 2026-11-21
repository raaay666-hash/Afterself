extends RefCounted

const CAST_SIZE = 12

static func chapter(g: Node, number: int) -> Dictionary:
	return g.journey.get("chapters",{}).get(str(number),{})

static func known(g: Node, id: int) -> bool:
	return id in g.journey.get("cast_met",[])

static func display_name(g: Node, id: int) -> String:
	if id==0: return "林砚" if not g.completed else "林砚 / 调查员"
	if id==1 and chapter(g,3).get("bridge_done")!=true: return "银发董事"
	return g.Data.CAST[id][0]

static func role(id: int) -> String:
	return ["异常案件调查员","现实侧董事","居民档案员","记忆医师","维修员","运营负责人","07 号公寓报案人","07 号公寓住户","夜班维护员","旧街居民代表","旧城登记处居民","记录核验员"][id]

static func notes(g: Node, id: int) -> Array[String]:
	var result: Array[String]=[]
	var c2: Dictionary=chapter(g,2)
	var c3: Dictionary=chapter(g,3)
	var c4: Dictionary=chapter(g,4)
	var c5: Dictionary=chapter(g,5)
	var c6: Dictionary=chapter(g,6)
	match id:
		0:
			result.append("异常案件调查员，受理 07 号公寓报案。")
			if g.completed: result.append("清理名单上出现他的编号；自己的档案也需要核对。")
			if not str(c3.get("resolution","")).is_empty(): result.append("旧授权、系统套用与现行反对不能合为一次签名。")
			if c3.get("bridge_done")==true: result.append("旧上传记录把他的过去连到现实中的另一位林砚。")
			if c5.get("bridge_done")==true: result.append("与现实侧通话后，要求由今天的居民自己表达选择。")
		1:
			result.append("现实侧董事，要求在表决前补齐居民材料。")
			if c3.get("bridge_done")==true: result.append("现实林砚。二十七岁时留下测试快照，自己继续活到八十岁。")
			if c4.get("bridge_done")==true: result.append("主张暂停清理执行，同时保留城市供给。")
			if c5.get("bridge_done")==true: result.append("承认早年签过隔离建议，准备把原件带进会议。")
		2:
			result.append("居民档案员，协助核对恢复记录。")
			if "receipt" in g.evidence: result.append("调出独立审计回执，要求把终止与启动分开记载。")
			for topic in c3.get("seen",[]):
				if str(topic).begins_with("闻遥/你为什么如此在意重新编号"):
					result.append("她曾被终止，现行的她从旧备份重新启动。")
					break
			if c6.get("intro")==true: result.append("坚持逐人核对当前意愿，不替旧实例补签。")
		3:
			result.append("记忆医师，保留早年的诊疗附件。")
			if "medical" in c3.get("evidence",[]): result.append("自愿清理曾用于治疗；批量程序越过了逐次同意。")
			if not str(c3.get("resolution","")).is_empty(): result.append("承认自己曾签署一次错误授权，并留下完整附件。")
		4:
			result.append("维修员，熟悉旧上传间与维护接口。")
			if "upload" in c3.get("evidence",[]): result.append("保留早期测试记录，帮助核对上传与实例链。")
			if "names" in c5.get("evidence",[]): result.append("私下保存被删除者名册，以及小满留下的信。")
		5:
			result.append("现实侧运营负责人，催促董事会表决。")
			if "attachment" in c6.get("evidence",[]): result.append("会议附件的变更链指向被删去的居民异议。")
			if not str(c6.get("resolution","")).is_empty(): result.append("批处理与删改附件的责任已在结案推论中指认。")
		6:
			result.append("07 号公寓报案人，担心宋屿失去的三天。")
			if g.flags.get("truth",false): result.append("知道旧实例已终止，仍愿意听现行宋屿自己的想法。")
			if g.completed: result.append("两人的生活安排，需要在知情之后重新商量。")
		7:
			result.append("07 号公寓住户，记忆止于三天前。")
			if g.flags.get("truth",false): result.append("得知自己由旧备份启动；要求保有自己的意愿。")
			if c6.get("intro")==true: result.append("反对用早于自己出生的备份替今天的他投票。")
		8:
			result.append("夜班维护员，负责 M-204 工单。")
			if "access" in g.evidence: result.append("签收并保管过一次性维修凭据；仍需核对执行记录。")
			if g.court_step>=3: result.append("对质后承认签署终止指令；恢复不能抵消这项责任。")
			if g.flags.get("custody",false): result.append("本案责任与清理程序的后续调查分别留档。")
		9:
			result.append("旧街居民代表，反对把住过的街道写成废弃关卡。")
			if "utility" in c2.get("evidence",[]): result.append("长期用水与修屋记录支持居民连续生活的事实。")
			if not str(c4.get("resolution","")).is_empty(): result.append("参与两城水源争议，今天的用水仍须共同核验。")
		10:
			result.append("旧城登记处居民，递交了新产权凭证。")
			if "stamp" in c2.get("evidence",[]): result.append("模板访问记录使新地契的来源受到质疑。")
			if not str(c2.get("resolution","")).is_empty(): result.append("伪造新凭证的责任与街区真实居住历史被分开处理。")
		11:
			result.append("记录核验员，先在历史地图室协助调查。")
			if not str(c2.get("resolution","")).is_empty(): result.append("用三代地图与现行记录，区分居住事实和新地契。")
			if "meters" in c4.get("evidence",[]): result.append("参与双城计量核对，追问数字省略了谁。")
			if "attachment" in c6.get("evidence",[]): result.append("协助追查董事会附件的变更来源。")
	return result

static func show(g: Node) -> void:
	g.new_modal("人物档案 / 随调查更新",true)
	var found: int=0
	for id in CAST_SIZE:
		var x: float=24+(id%4)*285
		var y: float=76+int(id/4)*158
		var card: Panel=g.panel_at(g.modal,Rect2(x,y,267,145),"26372f" if known(g,id) else "111a1b")
		if known(g,id):
			found+=1
			card.add_theme_stylebox_override("panel",g.box_style("26372f","b7a06e",2))
			g.shade(card,Rect2(0,0,4,145),Color("d4bd86"))
			g.add_portrait(card,id,Rect2(5,19,81,111))
			g.label_at(card,display_name(g,id),Rect2(91,15,170,35),20,"f2dfab")
			var detail: Array[String]=notes(g,id)
			g.label_at(card,role(id),Rect2(91,55,166,49),18,"d9e2d5")
			g.label_at(card,"%d 条记录 / 查看" % detail.size(),Rect2(91,109,168,29),16,"b6d1bc")
			g.button_at(g.modal,"",Rect2(x,y,267,145),func(): show_person(g,id),true)
		else:
			g.shade(card,Rect2(16,23,55,93),Color("263334"))
			g.label_at(card,"?",Rect2(30,43,50,54),42,"536663")
			g.label_at(card,"未遇见",Rect2(93,46,155,39),22,"71847e")
			g.label_at(card,"随剧情推进解锁",Rect2(93,91,158,31),16,"62746f")
	g.label_at(g.modal,"已认识 %d / 12 人。档案只记录目前亲历或查证的内容。" % found,Rect2(27,553,1095,31),18,"9eb7aa")

static func show_person(g: Node, id: int) -> void:
	if not known(g,id): return
	g.new_modal("人物档案 / "+display_name(g,id),true)
	g.add_portrait(g.modal,id,Rect2(58,129,249,360))
	g.label_at(g.modal,"已知记录 / %d 条" % notes(g,id).size(),Rect2(350,96,750,46),24,"d4bd86")
	var detail: Array[String]=notes(g,id)
	var scroll:=ScrollContainer.new()
	scroll.position=Vector2(350,151);scroll.size=Vector2(742,325)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	g.modal.add_child(scroll)
	var list:=VBoxContainer.new()
	list.custom_minimum_size=Vector2(705,0)
	list.add_theme_constant_override("separation",9)
	scroll.add_child(list)
	for index in detail.size():
		var entry: Label=g.label_at(list,"%02d  %s" % [index+1,detail[index]],Rect2(0,0,705,59),23,"e1e4d6")
		entry.custom_minimum_size=Vector2(705,59)
		entry.add_theme_constant_override("line_spacing",6)
	g.label_at(g.modal,"向下滚动查看记录；更多内容随剧情补入。" if detail.size()>4 else "更多内容将在后续相遇、查证或结案后补入。",Rect2(350,481,730,34),18,"9bb4aa")
	g.button_at(g.modal,"返回人物档案",Rect2(787,518,304,49),func(): show(g),true)
