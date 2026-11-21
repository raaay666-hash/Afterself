"""Only authored runtime data and final PNGs enter the evidence collection."""
from pathlib import Path
import json
from evidence_hotspots import POINTS
ROOT=Path(__file__).resolve().parents[1]
manifest=json.loads((ROOT/'assets/evidence-models-v2/manifest.json').read_text('utf-8'))
# owner, prerequisites, optional previously heard topic, body, voluntary acquisition dialogue
stories={
'c1.lease':('苏筠',['calendar'],'','昨天的租约留下旧宋屿的签名，今日的签名栏仍空白。留下合同可以纪念过去；是否继续，需要重新询问双方。',[['苏筠','原件留在我这里。你可以记录签名栏，但别替今天的他补上。'],['林砚','我只留获准的副本，今天的决定另记。']]),
'c1.shoe':('苏筠',['restore'],'truth','修鞋票仍由苏筠保存。取件约定属于旧宋屿；现行宋屿可以选择是否帮助，不能被默认要求替死者履约。',[['苏筠','这张修鞋票，我想留着。不是要他去取那双鞋。'],['林砚','可以让我记录你愿意说的部分吗？'],['苏筠','可以。票不用带走。']]),
'c2.doorplate':('祝青',['map','utility'],'','旧门牌留下覆盖与重新固定的痕迹。地址改过，居民的生活并没有因此消失；这不能单独证明当前产权。',[['祝青','门牌改过几次，账册上的地址也跟着改。我把对应抄图留给你。'],['林砚','我会与地图和账簿对照，不单凭这块牌子确认产权。']]),
'c2.application':('许禾',['deeds','stamp'],'','申请因缺少居民房屋证明被退回，但旧地图又不承认居民房屋。它解释许禾遇到的困境，不能让伪造交易成为真实。',[['许禾','这是被退回的申请。理由是先证明这里有居民房屋。'],['林砚','困难和你伪造的文件都会留下，彼此不会抵消。'],['许禾','好。请留一份遮住住址的副本。']]),
'c3.clock':('闻遥',['reuse','dissent'],'闻遥/你为什么如此在意重新编号？','闻遥保存一只停钟，纪念旧实例停止的人生。模型指针只作造型示意，不是已设定的案发时点；钟不被拿走。',[['闻遥','那只钟，我没有重新上弦。它记录她停止的那一刻。'],['林砚','我可以留下你愿意交代的纪念索引，不记下没有核实的时间。'],['闻遥','可以。钟还是放在这里。']]),
'c3.blank':('孟岚',['old','medical'],'','这是甲案医疗附件的同源纪念索引。评估能否执行，不等于完成逐名询问；孟岚作证并不消除她原有的责任。',[['孟岚','评估栏填了，询问栏没有。我想把这处空白单独留下。'],['林砚','它仍属于原医疗附件，不会被算成第二份独立证明。']]),
'c4.school':('顾舟',['original','inscription'],'','孩子的抄本遗漏了适用条件。更正时补回干旱、共同核验与临时有效，不把旧教程当作今日永久授权。',[['顾舟','这份学校抄本把结论背熟了，页脚没抄。'],['林砚','把完整条件附上。更正不抹掉他们已有的历史。']]),
'c4.ruler':('罗荻',['meters','petition'],'puzzle','检测尺的两端留着双方当次观测签认。它归计量台保管；共同测量不等于永久分水授权。',[['罗荻','双方确认了这次测量。我可以给你尺背签认的记录。'],['林砚','注明是当次观测，不写成他们同意永久分水。']]),
'c5.empty':('顾舟',['names'],'','顾舟名册中的空页保留缺页和未知标记。它与完整名册同源，不能编名字填上，也不能当成新的独立人口统计。',[['顾舟','这里有人，但我没找回他的名字。'],['林砚','留下未知和核查请求，不替他编一个名字。'],['顾舟','这页也请记着。']]),
'c5.letter':('顾舟',['names'],'顾舟/我有过一个孩子？','小满的信是既有名册记录中的私人附件。现行林砚通过档案了解她，读取信件不会恢复亲历记忆；只记录获准的摘句。',[['林砚','我想单独保存已经获准阅读的摘句。读到她，不等于记得她的声音。'],['顾舟','原件和缺页一起保存。公开范围仍另行确认。']]),
'c6.recipe':('宋屿',['current'],'','宋屿在今天修改了自己的配方：火调低一点。这是新经历，不是用于证明他是不是新人、该不该继承婚姻的考试。',[['宋屿','火调低一点，这是今天试出来的。你想要就抄一份。'],['林砚','这次失败和下次尝试，都记在今天。']]),
'c6.upload_form':('现实林砚',['algorithm','attachment'],'ended','上传表初始两格都空白。公共案件与私人决定分别记录；提交备份指令不证明主观意识转移，不上传也有完整的纪念页。',[['旁白','表格曾经没有勾选。最后的决定由他自己作出。'],['林砚','把公共案件留在公共卷，把他的决定留在这一页。']])}
entries=[]
for m in manifest['items']:
    item={k:m[k] for k in ['id','title','chapter','category','assets','hotspots','linked_source','inspect_note','secondary_label','visual_role']}
    item['body']=m['story_body'];item['owner']='';item['requires']=[];item['event']='';item['dialogue']=[]
    if m['id'] in stories:
        owner,requires,event,body,dialogue=stories[m['id']]
        item.update(owner=owner,requires=requires,event=event,body=body,dialogue=dialogue)
    # Local canonical IDs; the chapter gate is checked at runtime, not by the filename.
    assert len(POINTS[m['id']]) == len(item['hotspots']), m['id']
    for h, text in zip(item['hotspots'],POINTS[m['id']]):
        h['rect']=[int(v) for v in h['rect']]
        h['text']=text
    entries.append(item)
(ROOT/'assets/evidence-runtime-v9.json').write_text(json.dumps({'version':1,'entries':entries},ensure_ascii=False,indent=2),'utf-8')
print('Authored runtime: 37 core entries, 12 optional stories, 49 model mappings')
