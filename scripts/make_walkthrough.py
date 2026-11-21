"""Build a spoiler-marked illustrated walkthrough from shipped game data."""
from pathlib import Path
import json, base64, hashlib, html, shutil, re
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'pdf'
WEB = ROOT / 'output' / 'walkthrough'
QA = ROOT / 'tmp' / 'walkthrough-qa'
OUT.mkdir(parents=True, exist_ok=True)
WEB.mkdir(parents=True, exist_ok=True)
BOOK = json.loads((ROOT/'assets/campaign-v5.json').read_text('utf-8'))
FIELD = json.loads((ROOT/'assets/fieldwork-v10.json').read_text('utf-8'))
ENTRIES = json.loads((ROOT/'assets/evidence-runtime-v9.json').read_text('utf-8'))['entries']
EVID = {e['id']:e for e in ENTRIES}
pdfmetrics.registerFont(TTFont('CN', 'C:/Windows/Fonts/msyh.ttc', subfontIndex=0))
pdfmetrics.registerFont(TTFont('CNBold', 'C:/Windows/Fonts/msyhbd.ttc', subfontIndex=0))
W,H=842,595
INK='#172d2b'; MUTED='#57665d'; PAPER='#f4f0e6'; GOLD='#a07b42'; RED='#8a4637'
PDF=OUT/'AFTERSELF-0.10.0-图文通关攻略.pdf'
C=canvas.Canvas(str(PDF),pagesize=(W,H),pageCompression=1)
C.setTitle('AFTERSELF / 启动阶段 - 0.10.0 图文通关攻略')
C.setAuthor('AFTERSELF 项目攻略')
NUM=0
WEB_PARTS=[]
IMAGE_FILES=set()
TEXT_CHECK=[]
TOC=[]

ROUTES={
1:[('07号公寓','读餐桌日历，调查旧抽屉，输入714取得举报便条。询问宋屿“最后一件记得的事是什么？”，取得本人陈述。'),
   ('维修走廊','读公告栏维修单；点击签收簿入口，装A保险芯并核验。分别问邵为“维护凭据借给过别人吗？”，再问值班邻居，完成保管见证。'),
   ('居民档案室','点击恢复终端，以M-204工单调阅并“留存恢复登记”；读取独立执行回执。回现场操作完成四时点排序与保管区间。'),
   ('回公寓，再对质','点击苏筠，完成真相告知；J案卷组成三项推论，回走廊对质邵为。封存后回公寓与宋屿交谈，完成身份报告。'),
   ('章末别漏读','身份尾声后点“查看维护窗口与清理附页”，读完揭示，再点“继续第二章”。')],
2:[('先去历史地图室','取得三代地图与高倍测试累计表。地图是账房操作的前提；先读地图可避免在旧街来回寻找。'),
   ('回旧街','读拆除公告。点击账册入口或“现场推演”，对齐地图，沿水塔侧路→桥下通道→B巷账房，取得用水与修屋簿。'),
   ('旧城登记处','读两份新产权凭证，调查模板记录入口，查询交易编号与生成来源；再把A、B、C分开归类。'),
   ('结案与幕间','六份记录齐全后组合三项推论，提交结案。选择证人保护方式；幕间读完人口简报与共享资源批注，再选任一意见进入第三章。')],
3:[('记忆诊所','读甲案原始授权与医疗附件，保留旧实例真实的错误。'),
   ('独立签名库','按甲1804、乙2211、丙2390调卷；取得乙案批处理与丙案反对书。纸带按列读“反对／扩大／清理”，再核对三条来源链。'),
   ('旧上传间','必须完成本章两段主线操作后才能进入。取得原始上传记录与实例链计时对照；提前点入口会被引回核验。'),
   ('结案与幕间','组合三项推论，按旧错误→套用与反对→独立人生对质。选择归档方式；读启动日志与现实现行档案，再作答解锁第四章。')],
4:[('分水闸门','取得刻碑与现行计量；注意今天不是干旱紧急期。'),
   ('教学抄本室','拼接三个页脚：适用时期、双方核验、到期规则，取得教学原文与修订记录。'),
   ('共同计量台','读联合异议书与运行依赖清单；东表+2、西表-3，两表校为20，再判断三个情境的适用性。'),
   ('结案与幕间','完成组合与三轮对质，选择轮值核验或限期试测。幕间读公共服务架构、独立供给评估，再选意见进入第五章。')],
5:[('冻结街区与维修机房','取得冻结时间、独立门禁日志、协议冲突堆栈、本地删除与独立残留。F1-F3与历史D分别归因。'),
   ('只读排障','日志分批后，选择“只读导出并同步窗口”。先完成这段，通信模块才开放。'),
   ('旧调试间','接镜像→同步→审计→发送口，取得接线说明；遮罩三角向上，读取蓝杯／缺口／朝内。另读名册与小满的信。'),
   ('结案与幕间','组合与对质后选择名册发送范围。幕间读挑战回执和同步通信记录，再回应现实林砚。解开端口不会自动发送私人资料。')],
6:[('居民会场','取得三名居民当期陈述与被省略的异议。反对和保留也属于有效表达。'),
   ('签名核验台','读取表决时点登记，核票选择0、2、3，取得六条票据；再逐项标明1、4、5的排除理由。'),
   ('现实董事会','读算法与调用账号；对照原件与摘要，标记前三处改写并取得附件变更链；封存四项事实更正包。'),
   ('公共与私人结局','组成三项推论并完成三轮对质，选择公共方案。读完公共尾声后，再单独决定上传或不上传，直至一周目完成卡。')]
}
PITFALL={1:'仅凭工号或维修资格不能锁定执行者；保管见证必须与独立回执相互印证。',
2:'假地契指向具体制作者，不能据此取消整条街的居住历史。',
3:'旧授权真实、模板被套用、独立实例反对，三件事要同时保留。',
4:'校准的是标准样本；侦探不能替双方决定实际供水量。',
5:'三次冻结来自协议互等；邵为另一次删除行为仍要追究。',
6:'三张有效样例票不代表全城人数，也不表示三张都赞成。'}
STAGE_NOTES={
'c1a-0':'输入714（七月十四日），点击“核验操作结果”。',
'c1b-0':'选择A：铜壳／圆脚／2A，再核验；随后询问本人及邻居。',
'c1b-1':'02:14领取 → 02:26终止 → 02:41归还 → 06:12启动。',
'c1b-2':'保管起点02:14，终点02:41；02:26落在该区间内。',
'c2a-0':'旋转回0°，横纵偏移都归零。初始状态：右移一次、上移一次、旋转三次。',
'c2a-1':'水塔侧路 → 桥下通道 → B巷账房。',
'c2b-0':'只选“交易编号”与“生成来源”，不选边框和印章。',
'c2b-1':'A台=空置布景；B巷=连续居住；C地=当前凭证伪造。',
'c3a-0':'甲卷=1804／甲；乙卷=2211／乙；丙卷=2390／丙。',
'c3b-0':'按列向下读：反对 → 扩大 → 清理。',
'c3b-1':'甲=L-018主动授权；乙=服务账号套用；丙=L-062独立反对。',
'c4a-0':'干旱紧急期 → 双方共同核验 → 到期恢复共同管理。',
'c4b-0':'东表+2，西表-3：18+2=20，23-3=20。',
'c4b-1':'情境A成立；B、C均不成立。今天非干旱，不满足旧条款。',
'c5a-0':'F1、F2、F3=握手失败与互等；历史D=邵为删除本地Q-17。',
'c5a-1':'选择“只读导出并同步窗口”。不删日志、不重启居民。',
'c5b-0':'只读镜像 → 双端同步 → 独立审计 → 发送口。',
'c5b-1':'转回0°，三角定位标朝上。',
'c5b-2':'只选蓝杯／缺口／朝内，对应(1,2)、(2,3)、(3,2)。',
'c6a-0':'选择编号0、2、3：L-now、W-now、S-new。',
'c6a-1':'1=历史备份；4=已终止实例；5=重复来源。',
'c6b-0':'标记宋屿意见、闻遥意见、L-old身份三项；L-now不标记。',
'c6b-1':'选表达与回执、当期登记、历史调用、附件变更链四项。'
}
OPTION_NOTE={1:'告知真相后开放；需日历与本人陈述。',2:'需三代地图与用水修屋簿。',3:'需甲案授权、丙案反对书，并先听闻遥“你为什么如此在意重新编号？”。',4:'需完整教学原文与修订记录。',5:'需名册；只标明14页缺失，不补猜测姓名。',6:'需当期陈述与附件变更链，并已完成私人尾声。'}
OPTION_ANSWER={1:'选“旧宋屿的旧约定”。',2:'旧门牌B巷 → 改建后同址 → 现住户核对。',3:'选“对应旧实例终止”。',4:'选“教学任务的编号与修订”。',5:'选“页14缺失／内容未知”。',6:'公共方案的回应 → 私人上传的回应。'}
EVENT_LABEL={'':'取得前提材料即可','truth':'已完成真相告知','puzzle':'已完成本章主线推演','ended':'已完成私人结局',
'闻遥/你为什么如此在意重新编号？':'已听闻遥“你为什么如此在意重新编号？”',
'顾舟/我有过一个孩子？':'已听顾舟“我有过一个孩子？”'}

def esc(s): return html.escape(str(s))
def source_image(name):
    for p in [QA/name,ROOT/'build/v10'/name,ROOT/'build/v10/windows'/name,ROOT/'build/v9/windows'/name]:
        if p.exists(): return p
    raise FileNotFoundError(name)
def image_path(p):
    p=Path(p); IMAGE_FILES.add(p)
    return str(p)
def uri(p):
    image_path(p)
    return 'data:image/png;base64,'+base64.b64encode(Path(p).read_bytes()).decode('ascii')
def web_img(p,caption): return f'<figure><img src="{uri(p)}" alt="{esc(caption)}" tabindex="0"><figcaption>{esc(caption)}</figcaption></figure>'
def rect(x,t,w,h,fill,stroke=None):
    C.setFillColor(HexColor(fill));C.setStrokeColor(HexColor(stroke or fill));C.rect(x,H-t-h,w,h,stroke=bool(stroke),fill=1)
def text(s,x,t,w,size=11,color=INK,bold=False,leading=None):
    TEXT_CHECK.append(s)
    style=ParagraphStyle('p',fontName='CNBold' if bold else 'CN',fontSize=size,leading=leading or size*1.5,textColor=HexColor(color),wordWrap='CJK')
    p=Paragraph(esc(s).replace('\n','<br/>'),style)
    _,height=p.wrap(w,1000)
    assert t+height < (590 if t>=569 else 558), (NUM,s,t,height)
    p.drawOn(C,x,H-t-height)
    return height
def shot(p,x,t,w,caption='',height=None):
    p=Path(p); image_path(p)
    im=Image.open(p);iw,ih=im.size; h=w*ih/iw
    if height is not None and h>height: w=height*iw/ih;h=height
    C.drawImage(str(p),x,H-t-h,w,h,mask='auto')
    if caption: text(caption,x,t+h+5,w,9,MUTED,leading=12)
    return h
def start(title,kicker='完整剧透 / 0.10.0',anchor=None):
    global NUM
    NUM+=1
    C.setFillColor(HexColor(PAPER));C.rect(0,0,W,H,stroke=0,fill=1)
    rect(0,0,9,H,INK);rect(32,29,30,3,GOLD)
    text(kicker,72,20,735,9,MUTED)
    text(title,32,43,775,23,bold=True,leading=29)
    rect(32,561,778,1,'#d4cabb')
    text('AFTERSELF / 启动阶段    图文通关攻略',32,569,600,8,MUTED,leading=10)
    C.setFont('CN',9);C.setFillColor(HexColor(MUTED));C.drawRightString(810,16,f'{NUM:02d}')
    key=anchor or 'page'+str(NUM);C.bookmarkPage(key);C.addOutlineEntry(title,key,level=0,closed=False);TOC.append((title,NUM,key))
def end(): C.showPage()
def web_section(title,body,anchor):
    WEB_PARTS.append(f'<section id="{anchor}"><h2>{esc(title)}</h2>{body}</section>')
def callout(s,x,t,w):
    h=text(s,x+13,t+10,w-26,10,INK,leading=15)
    # Background is drawn first by callers where a fixed card is needed.
    return h

# Cover
start('图文通关攻略','AFTERSELF / 启动阶段    2026.10.02', 'cover')
cover=ROOT/'assets/branding/afterself-approved-installer-art.png'
shot(cover,32,103,322,height=322)
text('把事实留下来。\n把选择还给当事人。',391,115,410,29,bold=True,leading=43)
text('六章主线 / 23步现场操作 / 18轮对质\n六种公共与私人结尾组合\n37份主线记录 + 12件人物物件',391,238,410,14,leading=25)
rect(391,345,411,91,'#e7ddc9')
text('完整剧透提示',406,356,380,13,RED,bold=True)
text('本手册直接给出谜题答案与后期身份。首次游玩可按章节阅读；网页版的答案可折叠查看。',406,382,380,11,leading=17)
text('适用版本：游戏内部0.10.0。基于当前关卡数据、剧情逻辑与实机测试截图编写。攻略不承诺陌生玩家通关时长。',32,481,771,11,MUTED,leading=18)
end()
web_section('阅读前先确认',f'<div class="intro">{web_img(cover,"已选定的AFTERSELF封面美术")}<div><p class="lead">把事实留下来。把选择还给当事人。</p><p>适用游戏内部版本0.10.0。含六章主线、23步现场操作、18轮对质、六种结尾组合，以及49件证物的收集条件。</p><aside>完整剧透：后续章节包含身份揭示与结局信息。按当前进度展开答案。</aside></div></div>','cover')

# Quickstart
start('先掌握调查循环','操作与索引 / 无剧情答案','start')
text('调查取证 → 现场核验 → 两份记录组合 → 逐轮对质 → 结案选择',32,94,774,15,bold=True)
controls=[('鼠标','点人物交谈、点物件阅读；主角走近后才触发。'),('H / J','H显示热点；J打开案卷。'),('空格 / 回车','推进对白；打字未结束时先显示整句。'),('Esc / M / F11','暂停或关闭普通面板 / 静音 / 全屏。关键选择须明确点选。'),('现场操作','第一章在底部；后五章点“现场推演”。J内“现场核验”也进同一目录。'),('核验操作','交换卡片需点两张；分配题先点槽位再点项目；勾选题检查误选和漏选。')]
y=140
for label,desc in controls:
    text(label,32,y,116,11,bold=True);h=text(desc,155,y,360,11,leading=17);y+=max(43,h+13)
text('阅读顺序',550,140,250,14,bold=True)
for i in range(1,7): text(f'{i:02d}  '+('睡过头的人' if i==1 else BOOK[str(i)]['title'])+f'  /  p{[3,6,9,12,15,19][i-1]:02d}',550,174+(i-1)*34,250,11)
text('每章依次看：路线 → 现场答案 → 证据组合与对质。末尾附可选谜题、人物物件、结尾和卡关排查。',550,396,250,11,leading=18)
rect(32,457,778,75,'#e8dfce')
text('完成标准',47,466,110,12,bold=True)
text('主线通关：走到第六章私人结局完成卡。收集通关：另补12件人物物件。检查全部热点、六件可选小谜题均不作为主线结案门槛。',166,466,623,11,leading=18)
end()
web_section('操作与调查循环','<p class="lead">调查取证 → 现场核验 → 两份记录组合 → 逐轮对质 → 结案选择</p><dl>'+''.join(f'<dt>{esc(a)}</dt><dd>{esc(b)}</dd>' for a,b in controls)+'</dl><aside>主线通关以第六章私人结局完成卡为准。12件人物物件、全部检查热点和六件可选谜题均不阻断主线。</aside>','start')

for n in range(1,7):
    title='睡过头的人' if n==1 else BOOK[str(n)]['title']
    anchor=f'ch{n}'
    start(f'{n:02d} / {title}：最顺的调查路线',f'主线攻略 / 第{n}章',anchor)
    y=96; left=ROUTES[n]
    for i,(place,desc) in enumerate(left,1):
        text(f'{i:02d}  {place}',32,y,388,12,bold=True,leading=17);y+=21
        hh=text(desc,32,y,388,10.5,leading=16);y+=hh+15
    if n==1:
        p1=source_image('field-door-open.png'); p2=source_image('c1b-1-after.png')
        cap1='维修门已打开；签收记录还需本人和邻居核实。';cap2='四个当夜时点分别对应原始记录。'
    else:
        p1=source_image(f'chapter-{n}-scene-0.png');
        p2=source_image(f'chapter-{n}-scene-{1 if n==3 else 2}.png')
        cap1=BOOK[str(n)]['scenes'][0]['name'];cap2=BOOK[str(n)]['scenes'][1 if n==3 else 2]['name']
    shot(p1,449,98,360,cap1);shot(p2,449,325,360,cap2)
    end()
    body='<div class="columns"><ol class="route">'+''.join(f'<li><h3>{esc(a)}</h3><p>{esc(b)}</p></li>' for a,b in left)+'</ol><div>'+web_img(p1,cap1)+web_img(p2,cap2)+'</div></div>'
    web_section(f'第{n}章 / {title}：路线',body,anchor)

    stages=[]
    for suffix in 'ab':
        pid=f'c{n}{suffix}'
        for j,s in enumerate(FIELD[pid]['stages']):
            stages.append((f'{pid}-{j}',s,FIELD[pid]))
    chunks=[stages] if len(stages)<=4 else [stages[:3],stages[3:]]
    web_cards=[]
    for ci,group in enumerate(chunks):
        start(f'{n:02d} / 现场操作答案'+(f'（{ci+1}/{len(chunks)}）' if len(chunks)>1 else ''),f'主线攻略 / 第{n}章 / 每步完成后点击核验')
        for k,(sid,s,task) in enumerate(group):
            x=32+(k%2)*396;t=92+(k//2)*232
            text(s['title'],x,t,378,11,bold=True,leading=15)
            p=source_image(sid+'-after.png')
            shot(p,x,t+23,378,height=169)
            text(STAGE_NOTES[sid],x,t+198,378,10.2,leading=14.5)
            req='、'.join(EVID[f'c{n}.{r}']['title'] for r in s['requires'])
            web_cards.append('<article><h3>'+esc(s['title'])+'</h3><p class="small">入口：'+esc(task['scene'])+'；前提：'+esc(req or '完成前一步')+'</p><details><summary>展开正确操作与实机图</summary><p class="answer">'+esc(STAGE_NOTES[sid])+'</p>'+web_img(p,s['title']+' / 核验通过状态')+'<p>'+esc(s['result'])+'</p></details></article>')
        if len(group)<4:
            k=len(group);x=32+(k%2)*396;t=92+(k//2)*232
            rect(x,t,378,218,'#e8dfce')
            text('核验前检查',x+16,t+15,346,16,bold=True)
            text(PITFALL[n],x+16,t+54,346,12,leading=21)
            text('若操作尚未开放，先读对应原件或完成前序阶段。错误核验会给反馈，不会损失调查进度。',x+16,t+137,346,10.5,leading=17)
        end()
    web_section(f'第{n}章 / 现场答案','<div class="grid">'+''.join(web_cards)+'</div><aside>'+esc(PITFALL[n])+'</aside>',anchor+'-answers')

    start(f'{n:02d} / 证据组合、对质与结案',f'主线攻略 / 第{n}章 / 案卷按名称组合')
    if n==1:
        claims=[('宋屿的陈述','恢复登记','不是失忆，是实例替换','旧实例终止与现行备份启动分别记录。'),('凭据签收与见证','独立执行回执','M-204 的实际执行人','独占凭据与独立端终止回执相互印证。'),('未寄出的举报便条','夜间维修单','被删除的举报动机','两份材料对应同一附档Q-17。')]
        choices=[('身份报告','单列现行实例更直接回应宋屿意愿；沿用原档案也能结案，需注明中断。'),('真相与生活','真相告知两种方式均可推进。租约和面包侧记均读过，才出现早餐／暂缓的生活安排。'),('封存与追加调查','追加程序调查须先查续期通知与Q-17本次授权；不追加也可正常结案。')]
    else:
        c=BOOK[str(n)];claims=[]
        for rnd in c['rounds']:
            q=c['claims'][rnd['claim']];a,b=q['pair'];claims.append((c['evidence'][a]['title'],c['evidence'][b]['title'],q['title'],q['body']))
        choices=[('可选结案方式',ch['label']) for ch in c['choices']]
    text('按下列顺序完成三轮对质',32,92,446,13,bold=True)
    y=126
    for i,(a,b,q,desc) in enumerate(claims,1):
        rect(32,y,450,113,'#e9e2d4')
        text(f'{i:02d}  {q}',44,y+9,426,11,bold=True,leading=16)
        text(a+' ＋ '+b,44,y+37,426,10.5,GOLD,bold=True,leading=16)
        text(desc,44,y+65,426,10,leading=15)
        y+=128
    text('结案选择',508,92,300,14,bold=True)
    y=126
    for a,b in choices:
        text(a,508,y,302,10,MUTED,bold=True,leading=14);y+=19
        hh=text(b,508,y,302,11,leading=18);y+=hh+17
    if n in [2,3,4,5]:
        c=BOOK[str(n)];docnames=' / '.join(d['title'] for d in c['bridge']['docs'])
        text('幕间必读',508,y+4,302,12,bold=True);y+=29
        text(docnames+'。两份都点开读完，再任选一条意见；读完回应才解锁下一章。',508,y,302,10.5,leading=17)
    elif n==6:
        text('再决定私人上传',508,y+4,302,12,bold=True)
        text('三种公共方案之后均可选择上传／不上传。上传只确认备份指令已接收，执行结果未确认，更不证明意识转移。',508,y+30,302,11,leading=18)
    end()
    hb='<p>J案卷中选两份记录并组合，确认记入案卷后返回现场。以下三项按显示顺序用于三轮对质。</p><div class="claims">'
    for i,(a,b,q,desc) in enumerate(claims,1): hb+=f'<article><h3>{i:02d} / {esc(q)}</h3><p class="answer">{esc(a)} ＋ {esc(b)}</p><p>{esc(desc)}</p></article>'
    hb+='</div><h3>结案选择</h3><ul>'+''.join(f'<li>{esc(b)}</li>' for a,b in choices)+'</ul>'
    if n in [2,3,4,5]: hb+='<aside>幕间必读：'+esc(docnames)+'。两份都查阅后，任选一条意见并读完回应。</aside>'
    if n==1:hb+='<aside>封存后回公寓与宋屿交谈，完成身份报告；尾声后必须查看维护窗口与清理附页。</aside>'
    if n==6:hb+='<aside>公共方案后另选上传／不上传，两次选择独立。上传只确认备份指令已接收，执行结果未确认。读至一周目完成卡。</aside>'
    web_section(f'第{n}章 / 组合与对质',hb,anchor+'-proof')

# Optional puzzles: two pages, each with three visual cards.
for group in [[1,2,3],[4,5,6]]:
    start('可选小谜题：人物侧记',f'补充玩法 / 第{group[0]}至{group[-1]}章 / 不增加证物数量')
    hb=[]
    for k,n in enumerate(group):
        pz=FIELD[f's{n}'];x=32+k*265
        text(f'第{n}章 / '+pz['title'],x,94,248,12,bold=True,leading=18)
        shot(source_image(f's{n}-0-after.png'),x,139,248)
        text('开放条件',x,297,248,11,bold=True)
        h=text(OPTION_NOTE[n],x,321,248,10.5,leading=17)
        text('正确操作',x,321+h+18,248,11,bold=True)
        text(OPTION_ANSWER[n],x,321+h+43,248,11,GOLD,bold=True,leading=18)
        hb.append('<article><h3>第'+str(n)+'章 / '+esc(pz['title'])+'</h3><p>'+esc(OPTION_NOTE[n])+'</p><details><summary>展开答案</summary><p class="answer">'+esc(OPTION_ANSWER[n])+'</p>'+web_img(source_image(f's{n}-0-after.png'),pz['title'])+'</details></article>')
    text('从“现场操作／现场推演”目录进入。完成只追加侧记；人物物件仍须另外接受委托并读完对白。',32,515,778,10.5,MUTED)
    end();web_section('可选小谜题 / 第'+str(group[0])+'至'+str(group[-1])+'章','<p>从现场操作目录进入。这六项追加人物侧记，不额外增加证物数量。</p><div class="grid">'+''.join(hb)+'</div>','optional'+str(group[0]))

# Collectibles: exact runtime conditions, two pages.
for group in [[1,2,3],[4,5,6]]:
    start('人物物件收集清单',f'49件证物 / 37份主线 + 12件可选 / 第{group[0]}至{group[-1]}章')
    text('在人物询问菜单或证物柜打开“物件委托”，接受后读完全部对白才收录。',32,91,778,11,bold=True)
    hb=[]
    y=125
    for e in [e for e in ENTRIES if e['category']=='collection' and e['chapter'] in group]:
        icon=ROOT/'assets/evidence-models-v2'/e['assets']['icon']
        # Nearest-neighbor enlarged icon keeps the original 32x32 silhouette.
        target=WEB/(e['id'].replace('.','-')+'-icon.png')
        Image.open(icon).resize((96,96),Image.Resampling.NEAREST).save(target)
        shot(target,32,y,54)
        text(f"第{e['chapter']}章 / {e['title']}",101,y,709,12,bold=True)
        req=' ＋ '.join(EVID[f"c{e['chapter']}.{r}"]['title'] for r in e['requires'])
        text('前提：'+req+'；'+EVENT_LABEL[e['event']]+'。',101,y+22,709,10.5,leading=16)
        text('委托人：'+e['owner']+'。原件与披露范围按当事人同意保留。',101,y+45,709,9,MUTED,leading=14)
        hb.append(f'<article class="item"><img src="{uri(target)}" alt="{esc(e["title"])}像素模型"><div><h3>第{e["chapter"]}章 / {esc(e["title"])}</h3><p>前提：{esc(req)}；{esc(EVENT_LABEL[e["event"]])}。</p><p>委托人：{esc(e["owner"])}。接受并读完对白后收录。</p></div></article>')
        y+=67
    text('租约也可通过首章原有侧记入柜。最后的上传表在私人结局后回访证物柜领取，上传／不上传均可。',32,533,778,9.5,MUTED,leading=14)
    end();web_section('人物物件 / 第'+str(group[0])+'至'+str(group[-1])+'章','<p>在人物询问或证物柜打开“物件委托”。满足前提不等于自动获得；接受后读完全部对白才收录。</p>'+''.join(hb),'collect'+str(group[0]))

# Endings
start('结尾对照：公共方案 × 私人决定','六种组合 / 均能完成一周目','endings')
text('事实核验有明确答案，公共与私人抉择各有代价。攻略不把某条路线标成唯一“真结局”。',32,92,778,11,bold=True)
ending_rows=[('隔离保存','独立供给、内部自治；停止新上传和外部联系。','运行边界更清楚；亲友通信与迁移受限。'),('开放连接','公布历史，允许双方同意的连接与迁移。','增加联系与选择；也增加资源争议和攻击风险。'),('限期共治','保全实例与原件，监督通信，九十日内共同立新规。','短期损失较少；须防临时权力拖延，公开期限与退出办法。')]
y=137
for a,b,d in ending_rows:
    rect(32,y,778,86,'#e9e2d4');text(a,45,y+13,115,13,bold=True)
    text(b,179,y+10,612,11,leading=18);text(d,179,y+47,612,10.5,MUTED,leading=17);y+=100
text('私人尾声另选',32,451,155,13,bold=True)
text('不上传：在现实生命末期告别。上传：提交最终备份指令；当前窗口未确认执行结果，也不证明此刻主观体验会转移。',191,451,610,11,leading=18)
text('六种：隔离+不上传 / 隔离+上传 / 开放+不上传 / 开放+上传 / 共治+不上传 / 共治+上传。',32,513,778,10.5,GOLD,bold=True)
end()
web_section('六种结尾组合','<p>公共方案与私人上传是两次独立选择。均能完成一周目，没有统一标准答案。</p><table><thead><tr><th>公共方案</th><th>行为</th><th>收益与代价</th></tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+esc(s)+'</td>' for s in r)+'</tr>' for r in ending_rows)+'</tbody></table><aside>每一公共方案之后都能选择不上传或上传。上传意在创建副本，但当前窗口只确认备份指令已接收，执行结果未确认，更不能证明主观体验转移。</aside>'+web_img(source_image('private-choice.png'),'公共尾声结束后才出现的私人选择')+web_img(source_image('campaign-ending.png'),'一周目完成卡 / 图中为测试路线的一种组合'),'endings')

start('选择怎样进入人物尾声','分支影响 / 结案方式不决定全部公共路线','branches')
branch_rows=[('首章身份 + 第三章归档','首章“单列现行实例”且第三章“按实例分别立卷”，宋屿与闻遥会支持重新核验；其他组合保留单列当前者的要求。'),('首章生活支线','读租约和面包后：早餐→留下新的烘焙经验；暂缓→店铺延期、各自留空间；未谈→尾声说明以后从头商量。'),('第二章证人','署名公开→许禾可能受雇佣压力，并承担核验工作；保护身份→核验者可查身份，对外仍有难解释的误会。'),('第四章核验','公开轮值→两城共同监督水表；限期试测→到期重新开会，不把临时条款永久化。'),('第五章名册','完整加密托管→两处保管、逐人核验较慢；匿名摘要→较少隐私暴露，具体家庭追索仍依赖城内原件。')]
y=99
for a,b in branch_rows:
    text(a,32,y,165,12,bold=True);hh=text(b,220,y,590,11,leading=18);y+=max(77,hh+23)
text('章内结案选择确认后会保存。第六章“回看公共尾声”重播已经确认的路线，不能用它改选六种结局。',32,513,778,10.5,RED,leading=17)
end();web_section('前章选择对人物尾声的影响','<dl>'+''.join(f'<dt>{esc(a)}</dt><dd>{esc(b)}</dd>' for a,b in branch_rows)+'</dl><aside>章内选择确认后保存。“回看公共尾声”重播已确认路线，不是自由改选结尾的入口。</aside>','branches')

start('卡关排查与通关验收','最后检查 / 保存与回访','help')
trouble=[('入口灰着或材料不够','回查该步所需原件；部分材料由操作解锁。先完成前序步骤，再核验。第三章上传间尤其如此。'),('七份／六份记录齐了仍不能对质','主线现场操作全部完成吗？三项推论都写入案卷了吗？首章还需完成真相告知。'),('已结案，下一章没开放','首章读维护窗口与清理附页。第二至第五章读两份幕间材料、选意见并读完回应。'),('物件委托不显示','核对材料、特定人物话题、已完成本章推演或私人结局。条件完整后再打开委托目录。'),('没显示“新证物”弹窗','关键对白、选择和现有面板结束后才显示。若选择稍后查看，可直接从证物柜检查。'),('证物检查还有空白或未检查点','未收集槽位本来就空白。正面与背页的热点分别计数，全部点击不是主线必需。')]
y=95
for a,b in trouble:
    text(a,32,y,319,11,bold=True);hh=text(b,374,y,436,10.5,leading=17);y+=max(57,hh+14)
text('存档与回访',32,457,319,12,bold=True)
text('%APPDATA%/StartupPhase/ 内的chapter1-v10.json与campaign-v10.json保存进度。回访不改写已确认选择；测试使用独立目录，未读取或覆盖玩家存档。',374,457,436,10,leading=16)
text('主线完成：六章案件 + 第六章公共与私人尾声。全收集：证物柜37份主线记录、12件人物物件。',32,532,778,9.5,GOLD,bold=True,leading=14)
end();web_section('卡关排查与存档','<dl>'+''.join(f'<dt>{esc(a)}</dt><dd>{esc(b)}</dd>' for a,b in trouble)+'</dl><p>存档目录：<code>%APPDATA%/StartupPhase/</code>；本版使用<code>chapter1-v10.json</code>与<code>campaign-v10.json</code>。回访不改写已经确认的选择。</p>','help')

start('版本依据与快速核对','资料说明 / 2026.10.02','sources')
text('适用对象',32,98,154,13,bold=True)
text('当前工作区的游戏内部版本0.10.0。截图来自该版本的主线窗口测试；可选谜题图沿用已留存的0.10.0核验截图。封面与证物像素图均为项目现有资产。',212,98,598,11,leading=19)
text('内容来源',32,187,154,13,bold=True)
source_names=['README.md：版本、操作、存档与制作边界。','assets/fieldwork-v10.json：12段主线、23步答案与6件小谜题。','assets/campaign-v5.json：后五章原件、证据组合、对质、幕间和结案。','assets/evidence-runtime-v9.json：49件证物及人物委托的材料与话题条件。','scripts/field_puzzles.gd、campaign_flow.gd、game.gd：入口门槛、推进与尾声行为。']
y=187
for s in source_names: hh=text(s,212,y,598,10.5,leading=17);y+=hh+9
text('核对范围',32,371,154,13,bold=True)
text('答案以当前程序的合法输入与核验条件为准；公共／私人结尾说明取自剧情分支。自动窗口路线不等于陌生玩家体验评估，也不代表跨设备兼容性验收。',212,371,598,11,leading=19)
text('六章速查',32,460,154,13,bold=True)
text('01 日期714与时点    02 地图与地契    03 三份签名来源\n04 条款与校准    05 冻结与通信    06 当期核票与更正包',212,460,598,12,GOLD,bold=True,leading=23)
end();web_section('版本依据与图片来源','<p>适用当前游戏内部0.10.0。主线截图来自独立窗口测试，可选小谜题沿用同版本已留存截图。图中测试路线仅是其中一种选择。</p><ul>'+''.join('<li>'+esc(s)+'</li>' for s in source_names)+'</ul><p>自动窗口路线不等于陌生玩家体验或跨设备兼容性验收。攻略不承诺通关时长。</p>','sources')
C.save()

nav=['<a href="#start">操作</a>']+[f'<a href="#ch{n}">第{n}章</a>' for n in range(1,7)]+['<a href="#optional1">小谜题</a>','<a href="#collect1">收集</a>','<a href="#endings">结尾</a>','<a href="#help">卡关</a>']
template='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AFTERSELF 0.10.0 图文通关攻略</title><style>
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#f4f0e6;color:#172d2b;font-family:"Microsoft YaHei",sans-serif;line-height:1.8}header{background:#172d2b;color:#f4f0e6;padding:44px max(24px,calc((100vw - 1160px)/2)) 32px}header p{color:#cfc1a1;margin:0}h1{font-size:clamp(26px,4vw,46px);margin:9px 0}nav{position:sticky;top:0;z-index:5;background:#e6decdfa;border-bottom:1px solid #cbbd9f;display:flex;gap:7px;flex-wrap:wrap;padding:9px 18px;justify-content:center}nav a{color:#172d2b;text-decoration:none;padding:3px 10px;font-size:14px}nav a:hover{background:#d0c09c}main{max-width:1160px;margin:auto;padding:16px 24px 60px}section{scroll-margin-top:115px;padding:36px 0;border-bottom:1px solid #cfc4b3}h2{font-size:28px;line-height:1.4;margin:0 0 23px}h3{font-size:18px;margin:0 0 12px}p{margin:0 0 13px}figure{margin:0 0 22px}figure img{width:100%;display:block;cursor:zoom-in;border:1px solid #bac1b2}figcaption{color:#57665d;font-size:13px;padding-top:6px}.intro,.columns{display:grid;grid-template-columns:1fr 1fr;gap:35px}.intro figure{max-width:420px}.lead{font-size:23px;line-height:1.6}.grid{display:grid;grid-template-columns:1fr 1fr;gap:23px}article{background:#ece5d7;padding:20px}.small{font-size:14px;color:#57665d}.answer{font-weight:700;color:#865f2e}details{margin-top:12px}summary{cursor:pointer;color:#805b29;font-weight:700;padding:8px 0}details[open] summary{margin-bottom:13px}.claims{display:grid;grid-template-columns:1fr;gap:15px}aside{border-left:4px solid #a07b42;background:#e6ddc9;padding:15px 18px;margin:20px 0}dt{font-weight:700;padding-top:15px}dd{margin:3px 0 10px 0}.route{margin:0;padding-left:25px}.route li{padding-left:7px;margin-bottom:22px}.item{display:flex;align-items:center;gap:22px;margin-bottom:12px}.item img{width:80px;height:80px;image-rendering:pixelated;flex-shrink:0}table{width:100%;border-collapse:collapse;margin:20px 0}th,td{padding:16px;text-align:left;vertical-align:top;border:1px solid #c8bca8}th{background:#e2d7c0}button{background:#172d2b;color:white;border:0;padding:10px 16px;cursor:pointer;font:inherit}dialog{padding:12px;max-width:96vw;max-height:95vh;background:#172d2b;border:0}dialog img{max-width:90vw;max-height:85vh;display:block}dialog::backdrop{background:#000b}.toolbar{display:flex;gap:12px;align-items:center;margin-top:20px}footer{text-align:center;color:#57665d;padding:28px;font-size:13px}@media(max-width:720px){main{padding:10px 18px 50px}.intro,.columns,.grid{grid-template-columns:1fr;gap:18px}h2{font-size:23px}nav{gap:0;justify-content:flex-start}nav a{font-size:13px;padding:2px 7px}section{scroll-margin-top:132px}article{padding:16px}td,th{font-size:13px;padding:10px}.item{align-items:flex-start;gap:14px}}@media print{nav,.toolbar,dialog{display:none}details:not([open])>*:not(summary){display:block}section{break-before:page}article{break-inside:avoid}header{color:#172d2b;background:white}body{background:white}}
</style><header><p>AFTERSELF / 启动阶段 · 游戏内部0.10.0</p><h1>图文通关攻略</h1><p>六章主线 · 现场解谜 · 证据组合 · 人物物件 · 六种结尾</p><div class="toolbar"><button id="expand">展开全部答案</button><span>完整剧透 / 点击图片放大</span></div></header><nav>__NAV__</nav><main>__BODY__</main><footer>2026.10.02 · 基于当前关卡与剧情数据核对 · 离线单文件网页版</footer><dialog id="viewer"><button id="close">关闭</button><img alt="放大查看实机图片"></dialog><script>
const d=document.querySelector('#viewer');document.querySelectorAll('figure img').forEach(i=>{function open(){d.querySelector('img').src=i.src;d.querySelector('img').alt=i.alt;d.showModal()}i.addEventListener('click',open);i.addEventListener('keydown',e=>{if(e.key==='Enter')open()})});document.querySelector('#close').onclick=()=>d.close();d.addEventListener('click',e=>{if(e.target===d)d.close()});document.querySelector('#expand').onclick=e=>{const all=[...document.querySelectorAll('details')];const state=all.some(x=>!x.open);all.forEach(x=>x.open=state);e.target.textContent=state?'收起全部答案':'展开全部答案'};
</script></html>'''
HTML=WEB/'AFTERSELF-0.10.0-图文通关攻略.html'
HTML.write_text(template.replace('__NAV__',''.join(nav)).replace('__BODY__',''.join(WEB_PARTS)),'utf-8')
assert len(STAGE_NOTES)==23
assert sum(len(p['stages']) for p in FIELD.values() if not p['optional'])==23
assert sum(1 for e in ENTRIES if e['category']=='collection')==12
assert sum(1 for e in ENTRIES if e['category']=='core')==37
from pypdf import PdfReader
reader=PdfReader(PDF)
assert len(reader.pages)==NUM
extracted='\n'.join(p.extract_text() for p in reader.pages)
for term in ['714','02:14','02:41','蓝杯','朝内','隔离保存','开放连接','限期共治','没有勾选的上传表']:
    assert term in extracted,term
report={'game_version':'0.10.0','pages':NUM,'main_steps':23,'optional_puzzles':6,'core_records':37,'character_objects':12,
        'image_sources':len(IMAGE_FILES),'chapters':6,'public_private_combinations':6,'pdf':str(PDF),'html':str(HTML),
        'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [PDF,HTML]},
        'window_test_log':str(QA/'playthrough.log'),
        'window_test_passed':'CAMPAIGN WINDOW PLAYTHROUGH PASSED' in (QA/'playthrough.log').read_text('utf-8'),
        'sources':[str(p.relative_to(ROOT)) for p in sorted(IMAGE_FILES) if p.is_relative_to(ROOT)],
        'toc':[{'title':a,'page':b,'anchor':c} for a,b,c in TOC]}
(WEB/'攻略核对记录.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['sources','toc']},ensure_ascii=False,indent=2))
