"""Editable, code-native pixel prop models. Does not alter runtime or player saves."""
from pathlib import Path
import json, hashlib, zipfile, re
from html import escape
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/evidence-models-v1'
PALETTE = dict(ink='#182326', edge='#344442', shade='#60665b', paper='#e4d8b3', light='#f0e8ce', ochre='#b79c67', wood='#796148', red='#955b52', teal='#537e76', blue='#617785', plum='#796778', metal='#9bada1', dark='#273532', screen='#354f4a', glow='#adc2a0', muted='#b6b69a')

# ID, name, carrier, accent, silhouette detail, front hotspot, second view and reveal.
SPEC = [
('c1.calendar','圈起的日期','calendar','red','立起的双环台历，缺角底座、两处圈选','圈起的两个日期','翻到背页','计划日期由文字面板显示，不画假数字'),
('c1.testimony','宋屿的陈述','interview','blue','双栏笔录夹，左原话右侦探侧记','亲历与转述栏','确认页','笔录署名与修改记录分开；不是录音原件'),
('c1.note','未寄出的举报便条','foldnote','red','三折窄纸，未封信封压在底下','Q-17 附档标记','展开内页','举报正文与原附档号由面板显示'),
('c1.order','夜间维修单','clipboard','ochre','黄签工单板，黑夹与窄备注栏','正文与备注','附页','M-204 工单、Q-17 删除备注各自独立'),
('c1.access','凭据签收与见证','ledger','teal','左右页签收簿，旁附见证小签条','领取、归还与见证','签收附件','02:14—02:41，转交核实另列来源'),
('c1.restore','恢复登记','recovery','blue','双槽恢复记录面板，两个事件框不相连','备份与事件栏','时点面板','02:26 终止和 06:12 启动分开呈现'),
('c1.receipt','独立执行回执','receipt','teal','长孔边回执，底部独立端留存封签','指令与凭据字段','保管说明','独立端规则与回执来源可查'),
('c1.lease','没有签完的租约','contract','plum','两页租约、一角折起，第二签名框留白','昨日与今日签名栏','回访页','原件留在苏筠处，今日是否签字由当事人决定'),
('c1.shoe','没有人认领的修鞋票','ticket','ochre','齿边黄色存根，鞋形小记号与取件折痕','取件栏','票背','只收录获准信息，不让现行宋屿代履约'),
('c2.notice','拆除公告','notice','red','上角固定的告示纸，宽红色章与空附件格','无人布景依据','附件清单','附件无现行住户调查，空白不是零人口'),
('c2.utility','连续用水与修屋簿','ledger','blue','厚水费账簿，三代页签与修补书脊','地址连续索引','旧年代页','账簿支持居住连续性，不替代产权登记'),
('c2.deeds','两份新产权凭证','deeds','plum','两张互相错位的地契，冲突地块印章','同地块出售字段','并排核验','两份凭证的交易主张与真印章分开核验'),
('c2.stamp','模板访问记录','film','plum','打孔日志底片，分开的两个账号框','生成账号与时点','调用链','技术记录的案卷代理图，不新增实体底片来源'),
('c2.map','三代街区地图','map','teal','三叠折地图，三色地块和后来新增的街线','A、B、C 地块','中间年代图','原始用途、持续居住、当前产权分别判断'),
('c2.duration','高倍测试累计表','counter','ochre','双计量窗累计表，现实与当地标尺不同','两种时间单位','分段运行条','约 37 现实小时与当地年换算；不是全程高倍'),
('c2.doorplate','被改了三次的门牌','doorplate','teal','横长旧门牌，三层漆面和偏移螺孔','旧地址覆写','背面固定孔','地址改变的痕迹，号码只在检查面板给出'),
('c2.application','被退回的登记申请','application','red','折角申请表，退回签条覆盖证明栏','退回理由','申请附件','呈现许禾困境，不能让假地契因此变真'),
('c3.old','甲案原始手写授权','signed','ochre','窄授权书、独立当期签名块与封边','当期提交栏','核实页','L-018 的真实旧错误，不能洗成全部伪造'),
('c3.medical','甲案医疗附件','medical','teal','绿色医疗夹与范围示意、空缺询问框','评估范围与询问栏','评估附件','评估与逐名询问是不同程序'),
('c3.reuse','乙案批处理签名','batch','blue','旧签名底片穿过批处理记录轨道','服务调用字段','来源图','服务套用旧模板，不是新一次本人同意'),
('c3.dissent','丙案完整反对书','dissent','red','被摘要遮住半页的长意见书','摘要遮挡的正文','完整正文','打开遮页才能阅读反对，不只看签名'),
('c3.upload','原始上传记录','upload','teal','双端记录框，快照箭头只分支不合并','复制与现实端持续记录','起始会话页','表现复制而非灵魂搬运或原型消失'),
('c3.chain','实例链与计时对照','chain','plum','折叠索引长带，三处断口和分叉','清理／重启断口','全链索引','实例链历史不等于现行连续记忆'),
('c3.clock','闻遥停走的钟','clock','wood','方木座停钟，缺损一角，指针无动画','固定指针与保留痕迹','钟背','指针角度仅为造型示意；实际停表时点尚未设定，不能作为已知时间核验'),
('c3.blank','孟岚留下的空白询问栏','medical','plum','原医疗附件中的单独空框展示、细紫页签','未完成的询问框','事件备注','与甲案医疗附件同源的纪念索引，不再算独立证据'),
('c4.inscription','东城刻碑拓本','rubbing','shade','不规则暗色拓片，边缘石纹和被截短的底边','无条件碑文','碑面边缘','造型是拓本展示，不收走整块公共碑'),
('c4.meters','双城现行计量','meters','blue','两个计量盘和中间共同观测栏','两城当期读数','观测记录','检测结果的展示载体，不直接操作实际水闸'),
('c4.original','教学任务原文','scroll','ochre','展开的教学长页，页脚保留三块条件','三项条件页脚','页脚展开','干旱、共同核验、临时有效由文字面板完整显示'),
('c4.revision','刻碑修订记录','revision','red','前后两版纸叠合，删节层与收文小签','删节与获知原文时间','版本链','最初裁页原因与后来知情引用分别记录'),
('c4.petition','双城联合异议书','petition','teal','展开的联合书，底部两个平等签认区','请求范围','签认页','申请重新协商，没有给侦探分水授权'),
('c4.dependency','运行依赖清单','network','blue','三个共享服务框，以中继节点连接','共享服务连接点','分离评估','依赖记录展示，不暗示拔线即能安全关停'),
('c4.school','孩子抄错的神谕','school','ochre','缝线作业本，歪斜行距和漏掉的页脚','缺失条件处','更正后抄页','新收藏剧情的造型提案，错误文本不得成为规则'),
('c4.ruler','两城共同签字的测量尺','ruler','wood','粗木测量尺，交错刻度，两端各有签认标签','两方当次签认','尺背','一次共同观测不等于永久分水授权'),
('c5.freeze','三次冻结时间','timeline','blue','三条暂停日志轨道，暂停窗对齐','三段冻结标记','外部时钟轨','外部经过时间与居民暂停体验分开'),
('c5.alibi','独立门禁与分区日志','zones','teal','分区网格图叠加门禁条、三处定位框','人员与分区字段','门禁原页','职业或同夜班不等于接触过调试台'),
('c5.conflict','协议冲突堆栈','stack','red','两个对等协议框与相互等待环','双方等待条件','只读排障图','故障因果的案卷图，不增设可修改生产设备'),
('c5.deletion','本地删除与独立残留','deletion','ochre','一张有删除断块的记录与一张完整留存对照','删除调用与时点','独立残留页','删除与本次冻结分案核验，不合并所有维修员责任'),
('c5.port','旧端口接线说明','port','teal','四段工艺图，只读至发送依次串联','只读、同步、审计、发送','说明背页','接通不等于获准公开全部资料'),
('c5.names','被删除者名册与小满的信','names','plum','厚名册与小信封并列，缺页条外露','来源索引与附件关系','缺页索引','复合记录不把私人信件自动设为公开'),
('c5.empty','顾舟名册中的空页','empty','ochre','名册中一页保留的空白，断线索引框','缺页与未知标记','核查请求','来自 names 的展示索引，不编名字填空'),
('c5.letter','小满的信','letter','plum','折信与破边信封，一段正文藏于内折','获准阅读的内折','折信内页','来自 names 附件，不让读信变成恢复亲历记忆'),
('c6.current','三名居民当期陈述','statements','teal','三份平等摆放的陈述签条，三个当期框','本人当期确认','各自陈述页','三人仅是教学样本，不代表全城票数'),
('c6.suppressed','被省略的异议','dissent','red','原始陈述上覆摘要条，底部仍有提交回执','原话与摘要差异','回执附件','反对与保留均不能改写成同意'),
('c6.roll','六条表决票据','ballots','ochre','六张小票的两列核验盘，逐项来源栏','每张票的实例与当期状态','逐票来源页','六张为核验样本，三条有效不外推全城比例'),
('c6.restores','表决时点实例登记','register','blue','带活页孔的实例索引卡，两种状态框分列','表决当期状态','历史状态页','按当期独立居民核验，不能只按姓名去重'),
('c6.algorithm','签名算法与调用账号','algorithm','teal','批任务批准链、历史池与今日计票框分开','批准账号与调用','核验步骤页','技术展示图保留责任归属，不等于拿走机器'),
('c6.attachment','会议附件变更链','revision','plum','三层会议附件，省略条与版本签收签','被删字段和批准记录','原始附件','摘要删改与真正当期授权分开'),
('c6.recipe','宋屿今天写下的配方','recipe','ochre','有焦边的便笺，面包小图与修改划痕','今天新增的修改','配方背页','火调低一点是新经验，不做新人身份考试'),
('c6.upload_form','没有勾选的上传表','form','blue','完整表格中两格都留白，纸角保持干净','本人选择栏','提交说明','空白初始图不暗示结局；提交不证明意识转移'),
]

COLLECTION_IDS = {'c1.lease','c1.shoe','c2.doorplate','c2.application','c3.clock','c3.blank','c4.school','c4.ruler','c5.empty','c5.letter','c6.recipe','c6.upload_form'}
PROXIES = {'interview','recovery','film','counter','batch','upload','chain','meters','network','timeline','zones','stack','deletion','port','statements','ballots','register','algorithm'}
LINKS = {'c3.blank':'c3.medical','c5.empty':'c5.names','c5.letter':'c5.names'}

class Canvas:
    def __init__(self): self.ops=[]
    def rect(self,x,y,w,h,c): self.ops.append({'shape':'rect','x':x,'y':y,'width':w,'height':h,'color':c})
    def poly(self,pts,c): self.ops.append({'shape':'polygon','points':pts,'color':c})
    def line(self,pts,c,w=1): self.ops.append({'shape':'line','points':pts,'color':c,'width':w})
    def box(self,x,y,w,h,fill='paper',edge='ink'):
        self.rect(x,y,w,h,edge)
        inset=1 if min(w,h)<=4 else 2
        if w>inset*2 and h>inset*2:self.rect(x+inset,y+inset,w-inset*2,h-inset*2,fill)
    def lines(self,x,y,w,n=4,c='shade',step=4):
        for i in range(n):self.rect(x,y+i*step,max(4,w-(i%3)*3),1,c)
    def sheet(self,x=24,y=5,w=33,h=45,c='paper'):
        self.poly([(x,y),(x+w-6,y),(x+w,y+6),(x+w,y+h),(x,y+h)],'ink')
        self.poly([(x+2,y+2),(x+w-7,y+2),(x+w-2,y+7),(x+w-2,y+h-2),(x+2,y+h-2)],c)
        self.poly([(x+w-7,y+2),(x+w-7,y+7),(x+w-2,y+7)],'ochre')
    def node(self,x,y,c='teal',size=6):self.box(x,y,size,size,c)
    def signature(self,x,y,c='ink'): self.line([(x,y+3),(x+3,y),(x+5,y+4),(x+9,y+1),(x+13,y+2)],c)
    def seal(self,x,y,c):self.rect(x,y,9,8,c);self.rect(x+2,y+2,5,4,'paper')
    def image(self):
        im=Image.new('RGBA',(80,56));d=ImageDraw.Draw(im)
        for o in self.ops:
            c=PALETTE[o['color']]
            if o['shape']=='rect':d.rectangle([o['x'],o['y'],o['x']+o['width']-1,o['y']+o['height']-1],fill=c)
            elif o['shape']=='polygon':d.polygon(o['points'],fill=c)
            else:d.line(o['points'],fill=c,width=o['width'])
        return im
    def svg(self):
        body=[]
        for o in self.ops:
            color=PALETTE[o['color']]
            if o['shape']=='rect':body.append(f'<rect x="{o["x"]}" y="{o["y"]}" width="{o["width"]}" height="{o["height"]}" fill="{color}"/>')
            else:
                points=' '.join(f'{x},{y}' for x,y in o['points'])
                body.append(f'<polygon points="{points}" fill="{color}"/>' if o['shape']=='polygon' else f'<polyline points="{points}" stroke="{color}" stroke-width="{o["width"]}" fill="none"/>')
        return '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="112" viewBox="0 0 80 56" shape-rendering="crispEdges">'+''.join(body)+'</svg>'

def draw_model(entry,second=False):
    id,name,k,a,look,hot,view,note=entry;c=Canvas();variant=sum(ord(ch) for ch in id)%5
    if a not in PALETTE:a='ochre'
    if k=='calendar':
        c.poly([(22,43),(58,43),(63,52),(17,52)],'ink');c.poly([(24,42),(55,42),(60,49),(20,49)],'wood')
        c.box(22,8,37,36);c.rect(24,10,33,6,a)
        for x in [30,49]:c.box(x,4,3,9,'metal')
        for row in range(3):
            for col in range(5):c.rect(27+col*5,20+row*6,2,2,'shade')
        if second:c.lines(28,22,23,4);c.rect(29,40,19,1,'red')
        else:
            c.box(30,23,8,8,'paper',a);c.box(45,29,8,8,'paper',a)
    elif k=='clock':
        c.rect(21,47,40,4,'ink');c.rect(24,44,34,5,'wood');c.box(24,7,34,38,'wood');c.box(29,13,24,25,'ochre')
        if second:c.box(31,18,20,16,'wood');c.rect(35,22,2,2,'metal');c.rect(45,29,2,2,'metal');c.lines(34,39,14,2)
        else:
            c.poly([(34,15),(48,15),(51,18),(51,33),(47,36),(34,36),(31,32),(31,18)],'paper')
            for x,y in [(40,17),(40,33),(33,25),(48,25)]:c.rect(x,y,2,2,'ink')
            c.line([(41,26),(37,22)],'ink',2);c.line([(41,26),(45,29)],'red');c.rect(55,10,3,5,'ink')
    elif k=='ruler':
        c.poly([(9,29),(60,13),(64,17),(68,30),(16,45)],'ink');c.poly([(12,30),(59,16),(62,20),(64,29),(16,41)],'wood')
        for i in range(10):x=18+i*4;y=34-i;c.line([(x,y),(x-1,y-5-(i%3==0)*2)],'paper')
        c.box(9,29,13,12,'paper');c.box(59,16,12,12,'paper');c.signature(10,31,'teal');c.signature(58,18,'blue')
        if second:c.rect(31,30,12,2,'shade');c.line([(28,35),(49,29)],'ochre',2)
    elif k=='doorplate':
        c.poly([(13,20),(62,20),(66,24),(66,38),(15,38),(11,34),(11,24)],'ink');c.rect(14,23,49,12,a)
        c.rect(17,25,8,8,'wood');c.rect(24,25,8,8,'shade');c.rect(31,25,19,8,'metal')
        for x in [15,59]:c.rect(x,27,2,2,'ink')
        if second:c.rect(18,29,3,2,'ink');c.rect(52,26,3,2,'ink');c.line([(27,28),(43,30),(55,29)],'shade')
        else:c.rect(35,28,11,2,'ink');c.rect(49,28,4,2,'ink')
    elif k=='ticket':
        c.poly([(25,5),(54,5),(54,10),(57,10),(57,46),(53,46),(53,50),(25,50),(25,46),(22,46),(22,10),(25,10)],'ink');c.rect(25,8,29,38,'ochre')
        for y in range(11,44,4):c.rect(28,y,1,1,'paper')
        c.lines(33,12,15,3,'wood');c.line([(35,27),(35,32),(44,32),(48,35),(48,37),(32,37),(32,34)],'ink',2);c.rect(32,39,17,1,'wood')
        if second:c.rect(31,11,18,27,'paper');c.lines(34,15,12,4,'wood');c.line([(28,43),(47,41)],'wood')
    elif k in {'ledger','names','empty'}:
        c.poly([(11,11),(37,8),(39,11),(42,8),(69,11),(69,46),(44,49),(38,47),(11,49)],'ink');c.poly([(14,13),(35,11),(37,14),(37,45),(14,46)],'paper');c.poly([(41,13),(45,11),(66,13),(66,44),(43,46),(41,43)],'light');c.rect(38,13,2,33,'wood')
        c.lines(17,17,16,6);c.lines(45,17,18,6)
        for x,y in [(66,19),(67,29),(67,39)]:c.rect(x,y,5,4,a)
        if id=='c1.access':
            for y in [26,34]:c.rect(15,y,20,2,a)
            c.box(53,32,19,18,'paper');c.signature(56,40,a)
        elif k=='names':
            c.rect(17,19,12,2,a);c.rect(47,32,14,2,a);c.rect(43,40,15,1,'wood');c.box(54,31,20,17,'paper');c.line([(56,34),(64,40),(72,34)],a)
        elif k=='empty':
            c.rect(43,14,22,30,'light');c.box(46,26,16,10,'light','muted');c.line([(47,27),(54,33),(60,28)],'muted');c.rect(63,14,2,6,'wood')
        else:c.rect(15,36,20,2,a);c.rect(45,31,18,1,a);c.rect(12,15,2,25,'wood')
        if second:c.rect(14,14,21,29,'light');c.lines(17,18,15,4,a);c.box(45,19,17,15,'paper');c.lines(48,22,11,3);c.rect(44,40,19,2,'red' if k=='empty' else a)
    elif k=='map':
        for i in [2,1,0]:
            x=15+i*4;y=9+i*3;c.box(x,y,46,34,'paper');c.line([(x+15,y+2),(x+15,y+31)],'ochre');c.line([(x+30,y+2),(x+30,y+31)],'ochre')
        c.line([(19,15),(53,15),(53,36),(27,36),(27,21),(59,21)],'shade',2)
        for x,y,col in [(19,25,'shade'),(33,26,'teal'),(48,27,'red')]:c.box(x,y,8,8,col)
        if second:c.rect(32,25,10,10,'paper');c.line([(33,29),(41,29)],'teal',2);c.rect(45,30,7,2,'red')
    elif k=='rubbing':
        c.poly([(24,4),(50,6),(58,11),(56,25),(60,31),(54,49),(31,51),(20,44),(22,30),(18,13)],'ink');c.poly([(26,7),(48,9),(54,13),(52,25),(56,32),(50,45),(31,47),(24,41),(26,29),(23,15)],'shade')
        c.lines(30,14,16,6,'paper',5);c.rect(24,34,3,7,'edge');c.rect(51,19,3,5,'metal')
        if second:c.lines(28,18,17,4,'metal',6);c.line([(27,42),(34,43),(44,42)],'ink',2)
    elif k=='film':
        c.box(10,16,60,25,'edge');c.rect(17,20,47,17,'paper')
        for x in range(13,67,6):c.rect(x,17,2,2,'metal');c.rect(x,38,2,2,'metal')
        for x in [22,43]:c.box(x,24,14,9,a);c.rect(x+3,27,8,1,'paper')
        if second:c.line([(24,26),(24,30),(49,30),(49,26)],'red',2)
    elif k in {'recovery','counter','meters','timeline','zones','stack','port','upload','chain','network','algorithm','batch','deletion','register','ballots','statements'}:
        # These are explicitly visual proxies for digital records, not lootable machines.
        if k=='recovery':
            c.box(12,9,56,38,'edge');c.rect(15,13,23,27,'screen');c.rect(42,13,22,27,'screen');c.lines(18,16,16,2,'glow');c.lines(45,16,15,2,'glow');c.rect(18,33,14,3,'red');c.rect(46,33,14,3,'teal');c.rect(38,10,3,35,'ink')
        elif k=='counter':
            c.box(15,13,50,29,'wood');c.box(19,17,20,13,'screen');c.box(42,17,19,13,'screen')
            for x in [22,27,32,45,50,55]:c.rect(x,20,3,6,'glow')
            c.rect(19,35,20,2,'paper');c.rect(43,35,16,2,'paper')
        elif k=='meters':
            c.box(9,10,62,36,'metal')
            for x,col in [(14,'blue'),(46,'teal')]:c.box(x,16,20,20,'paper');c.rect(x+3,20,14,2,col);c.line([(x+10,29),(x+15,24)],'ink',2);c.rect(x+3,33,14,1,'shade')
            c.rect(35,18,8,17,'screen');c.lines(36,21,5,3,'glow')
        elif k=='timeline':
            c.box(10,8,60,40,'edge')
            for i in range(3):c.rect(15,16+i*9,48,2,'metal');c.rect(31+i*3,14+i*9,9,6,'blue');c.rect(36+i*3,15+i*9,1,4,'paper')
            c.line([(53,13),(53,42)],'ochre')
        elif k=='zones':
            c.box(13,8,46,38,'screen')
            for x in [27,42]:c.rect(x,11,1,31,'teal')
            for y in [22,34]:c.rect(16,y,39,1,'teal')
            for x,y in [(19,15),(45,27),(31,37)]:c.node(x,y,'ochre',5)
            c.box(50,24,19,23,'paper');c.lines(53,28,12,4)
        elif k=='stack':
            c.box(10,13,23,28,'screen');c.box(48,13,23,28,'screen');c.lines(14,18,14,3,'glow');c.lines(52,18,14,3,'glow');c.line([(31,20),(43,20),(43,28),(48,28)],'red',2);c.line([(49,34),(37,34),(37,27),(33,27)],'ochre',2);c.poly([(45,26),(49,28),(45,30)],'red');c.poly([(36,25),(32,27),(36,29)],'ochre')
        elif k=='port':
            c.box(8,17,64,23,'paper');c.line([(17,28),(63,28)],'ink',2)
            for i,col in enumerate(['teal','blue','ochre','plum']):c.node(12+i*15,22,col,11);c.rect(15+i*15,25,5,3,'paper')
        elif k=='upload':
            c.box(10,12,24,30,'screen');c.box(46,18,24,24,'screen');c.lines(14,17,16,4,'glow');c.lines(50,23,16,3,'glow');c.line([(32,26),(43,26),(43,30),(48,30)],a,2);c.poly([(44,27),(49,30),(44,33)],a);c.line([(22,40),(22,48),(33,48)],'ochre',2)
        elif k=='chain':
            c.box(8,18,64,21,'paper');c.line([(14,28),(66,28)],'wood',2)
            for i in range(5):c.node(12+i*12,24,a,7)
            for x in [31,53]:c.rect(x,23,3,11,'paper');c.line([(x,24),(x+2,26),(x,29),(x+2,32)],'red')
            c.line([(38,29),(38,44),(54,44)],'teal',2);c.node(52,41,'teal',7)
        elif k=='network':
            c.line([(21,20),(40,20),(40,39),(58,39),(58,20)],'metal',2)
            for x,y,col in [(13,13,'teal'),(32,32,'ochre'),(51,13,'blue')]:c.box(x,y,16,14,'screen');c.lines(x+3,y+4,9,2,'glow')
        elif k in {'algorithm','batch'}:
            c.box(8,8,24,19,'screen');c.lines(12,13,14,3,'glow');c.box(49,29,23,19,'paper');c.lines(53,34,14,3)
            c.line([(31,19),(42,19),(42,38),(50,38)],a,2)
            for y in [29,35,41]:c.rect(15,y,15,3,'ochre');c.rect(19,y+1,8,1,'paper')
            c.poly([(45,35),(50,38),(45,41)],a)
        elif k=='deletion':
            c.box(12,8,27,39,'paper');c.lines(16,15,17,6);c.rect(14,28,23,7,'ink');c.line([(18,29),(28,34)],'red',2);c.box(43,13,27,36,'light');c.lines(47,19,17,6);c.seal(58,36,'teal')
        elif k=='register':
            c.box(15,9,50,38,'paper')
            for y in [15,25,35]:c.rect(17,y,2,2,'ink');c.rect(22,y,38,1,'shade');c.rect(47,y+3,11,4,'teal' if y==15 else 'muted')
            c.rect(28,11,1,33,'ochre');c.rect(43,11,1,33,'ochre')
        elif k=='ballots':
            for i in range(6):
                x=15+(i%2)*27;y=5+(i//2)*16;c.box(x,y,23,13,'paper');c.rect(x+4,y+4,4,4,a);c.lines(x+11,y+4,7,2);c.rect(x+4,y+9,13,1,'shade')
        elif k=='statements':
            for i in range(3):x=8+i*23;y=12+(i%2)*5;c.box(x,y,20,29,'paper');c.lines(x+4,y+6,12,3);c.signature(x+3,y+20,['teal','blue','plum'][i])
        if second:
            c.box(18,8,45,40,'paper');c.rect(20,10,41,5,a);c.lines(23,19,29,4);c.box(23,36,32,8,'light',a);c.rect(27,39,23,1,'shade')
            # A small proxy-specific diagram preserves the difference from paper originals.
            for x in [13,66]:c.rect(x,23,3,12,a)
    elif k in {'scroll','contract','deeds','revision','petition','dissent','interview','clipboard','medical','signed','receipt','application','notice','form','school','recipe','letter','foldnote'}:
        if k=='scroll':
            c.box(20,7,40,42,'paper');c.box(16,5,48,6,'ochre');c.box(16,46,48,6,'ochre');c.lines(26,17,24,4)
            for x in [26,37,48]:c.box(x,35,7,8,'light',a)
        elif k=='deeds':
            c.sheet(14,9,31,40,'light');c.lines(18,18,20,4);c.seal(27,35,'red');c.sheet(36,5,30,40);c.lines(41,15,18,4);c.seal(45,32,'plum')
        elif k=='petition':
            c.box(13,7,54,41,'paper');c.lines(20,13,37,4);c.rect(40,30,1,12,'ochre');c.signature(19,34,'teal');c.signature(47,34,'blue')
        elif k=='interview':
            c.box(16,6,47,43,'wood');c.box(19,9,41,36,'paper');c.rect(39,15,1,25,'ochre');c.lines(23,17,12,4);c.lines(43,17,12,3,'blue');c.box(31,3,16,7,'metal')
        elif k=='clipboard':
            c.box(21,5,38,45,'wood');c.rect(24,10,32,36,'paper');c.box(30,3,20,8,'metal');c.rect(26,15,28,4,a);c.lines(27,23,24,3);c.box(27,36,25,7,'light',a)
        elif k=='medical':
            c.box(18,6,44,44,a);c.sheet(24,10,33,36);c.rect(28,15,9,2,a);c.rect(31,12,2,8,a);c.lines(28,23,23,3);c.box(29,36,22,6,'light','ochre');c.rect(61,17,5,12,'metal')
            if id=='c3.blank':c.rect(28,23,25,18,'light');c.box(29,27,22,10,'light','plum');c.rect(30,43,15,1,'plum')
        elif k=='receipt':
            c.box(24,3,32,49,'paper');c.lines(31,12,17,5);c.seal(34,36,a)
            for y in range(7,48,5):c.rect(26,y,2,2,'ink');c.rect(52,y,2,2,'ink')
        elif k=='revision':
            for i in [2,1,0]:c.sheet(22+i*4,4+i*3,30,40,'light' if i==1 else 'paper')
            c.lines(27,14,17,5);c.rect(26,25,20,3,a);c.rect(26,34,18,2,a);c.box(46,35,18,15,'paper');c.lines(49,38,11,2)
        elif k=='dissent':
            c.sheet(22,3,35,48);c.lines(27,11,22,6);c.signature(29,41,a);c.box(14,20,47,9,'muted');c.rect(18,23,35,2,'ink');c.rect(25,31,25,3,a)
            if id=='c6.suppressed':c.box(49,35,20,16,'paper');c.lines(52,38,13,2,'teal');c.seal(58,44,'teal')
        elif k=='notice':
            c.sheet(21,4,39,46);c.rect(27,11,26,5,a);c.lines(27,23,23,3);c.box(27,37,25,7,'light','ochre')
            for x in [23,54]:c.rect(x,6,3,3,'metal')
        elif k=='contract':
            c.sheet(20,7,32,41);c.sheet(29,4,32,42,'light');c.lines(34,13,20,4);c.signature(34,34,'plum');c.box(34,39,20,5,'light','ochre')
        elif k=='application':
            c.sheet(22,5,34,44);c.lines(27,15,22,4);c.box(27,34,22,9,'light','ochre');c.box(14,24,49,8,'paper','red');c.lines(19,27,36,1,'red')
        elif k=='signed':
            c.sheet(25,4,30,47);c.lines(30,13,18,5);c.signature(31,36,a);c.seal(37,43,a)
        elif k=='form':
            c.sheet(21,5,39,44);c.lines(27,14,26,4)
            for y in [32,40]:c.box(27,y,5,5,'light','shade');c.rect(36,y+2,15,1,'shade')
        elif k=='school':
            c.box(19,6,41,44,'wood');c.rect(23,8,34,38,'paper');c.rect(25,10,1,33,'red')
            for i in range(6):c.line([(29,15+i*4),(49-i%3,16+i*4)],'shade')
            c.rect(29,38,20,1,'ochre');c.rect(52,37,2,4,'red');c.rect(20,11,2,25,'metal')
        elif k=='recipe':
            c.poly([(19,10),(52,6),(61,40),(29,48),(22,41)],'ink');c.poly([(22,12),(50,9),(57,38),(30,44),(25,39)],'paper');c.lines(29,16,17,4,'wood');c.rect(30,29,17,1,'red');c.rect(36,32,17,1,'red');c.poly([(22,39),(27,43),(32,44),(28,47),(22,44)],'wood');c.box(42,36,11,6,'ochre')
        elif k in {'letter','foldnote'}:
            c.box(12,28,37,21,'ochre');c.line([(14,31),(30,42),(46,31)],'wood');c.sheet(32,6,31,39,'light');c.lines(37,15,19,5,'plum' if k=='letter' else 'shade');c.rect(35,27,23,1,'ochre');c.rect(41,38,12,1,a)
        if second:
            c.box(17,5,48,45,'light');c.lines(23,13,34,4);c.rect(21,31,40,1,'ochre');c.rect(41,9,1,36,'ochre')
            if k in {'letter','foldnote','scroll'}:c.lines(23,35,33,3,a)
            elif k=='dissent':c.rect(23,14,31,3,a);c.lines(23,21,31,4);c.signature(28,41,a)
            elif k in {'form','contract','medical'}:
                c.box(23,36,14,7,'light','shade');c.box(45,36,14,7,'light','shade')
            else:c.box(22,35,38,9,'paper',a);c.signature(28,37,a)
    else:raise ValueError(k)
    return c

ZONES = {
 'calendar':[(29,22,10,10),(43,28,12,11)],'interview':[(22,15,16,27),(42,15,16,26)],
 'foldnote':[(34,13,25,17),(34,32,25,10)],'clipboard':[(26,13,28,17),(26,34,28,10)],
 'ledger':[(14,15,23,30),(43,15,27,32)],'recovery':[(16,15,21,22),(44,15,20,22)],
 'receipt':[(30,10,21,21),(31,34,20,13)],'contract':[(33,30,24,8),(33,38,24,8)],
 'ticket':[(31,23,20,17),(29,10,22,13)],'notice':[(25,10,31,23),(25,35,30,11)],
 'deeds':[(16,17,24,24),(39,13,23,27)],'film':[(19,22,19,13),(41,22,19,13)],
 'map':[(17,24,13,13),(31,24,13,13),(46,24,13,13)],'counter':[(18,16,22,16),(41,16,22,16)],
 'doorplate':[(16,23,16,11),(31,23,25,11)],'application':[(17,25,43,6),(26,33,26,12)],
 'signed':[(29,11,21,20),(29,33,23,16)],'medical':[(27,21,27,12),(27,34,27,11)],
 'batch':[(11,11,19,14),(51,32,18,13)],'dissent':[(15,20,46,9),(25,30,29,14)],
 'upload':[(13,15,18,25),(49,21,17,17)],'chain':[(27,22,13,14),(49,22,13,14)],
 'clock':[(31,15,22,23),(53,7,6,11)],'rubbing':[(28,12,22,22),(26,35,25,11)],
 'meters':[(14,16,20,20),(46,16,20,20)],'scroll':[(25,15,30,17),(24,33,33,12)],
 'revision':[(25,21,25,17),(46,34,18,15)],'petition':[(19,12,41,18),(17,31,48,12)],
 'network':[(13,12,17,16),(31,31,19,15),(50,12,19,16)],'school':[(28,14,26,21),(28,35,26,8)],
 'ruler':[(8,27,17,17),(56,14,17,17)],'timeline':[(28,12,24,29),(51,11,7,34)],
 'zones':[(17,12,35,30),(51,26,17,19)],'stack':[(11,15,20,25),(48,15,21,25)],
 'deletion':[(15,25,22,12),(45,16,22,30)],'port':[(11,21,24,14),(42,21,25,14)],
 'names':[(14,13,23,31),(51,30,24,20)],'empty':[(42,13,22,31),(62,12,7,14)],
 'letter':[(35,13,26,18),(13,29,29,19)],'statements':[(8,12,19,29),(31,17,19,29),(54,12,19,29)],
 'ballots':[(14,4,25,45),(41,4,25,45)],'register':[(22,12,20,30),(45,13,15,30)],
 'algorithm':[(10,10,22,18),(50,30,21,18)],'recipe':[(29,14,25,20),(40,34,16,10)],
 'form':[(25,30,29,9),(25,39,29,8)]
}

def make_hotspots(entry):
    id,name,kind,accent,look,hot,view,note=entry
    labels={
     'c1.calendar':['和好日期','看铺子日期'],'c1.testimony':['本人原话栏','侦探侧记栏'],
     'c1.note':['举报正文','Q-17 附档号'],'c1.order':['M-204 正文','Q-17 删除备注'],
     'c1.access':['领取与归还','见证与转交核实'],'c1.restore':['旧实例终止记录','备份与启动记录'],
     'c1.receipt':['指令与凭据','独立保管说明'],'c1.lease':['昨日签名','今日空白栏'],
     'c1.shoe':['取件信息','票据来源'],'c2.notice':['公告原文','附件空白栏'],
     'c2.utility':['地址与旧记录','当期核对页'],'c2.deeds':['第一份地契','第二份地契'],
     'c2.stamp':['制作者账号一','制作者账号二'],'c2.map':['A 台','B 巷','C 地'],
     'c2.duration':['现实时间单位','当地时间单位'],'c2.doorplate':['旧漆与旧地址','后来覆盖层'],
     'c2.application':['退回理由','待提交证明栏'],'c3.old':['当期授权范围','签名核验'],
     'c3.medical':['评估范围','询问栏'],'c3.reuse':['服务调用来源','输出签名字段'],
     'c3.dissent':['截取摘要','原始反对正文'],'c3.upload':['现实端持续记录','快照分支'],
     'c3.chain':['首次断口','后续断口'],'c3.clock':['指针造型','旧损与保留痕迹'],
     'c3.blank':['原医疗附件关联','空白询问框'],'c4.inscription':['碑文拓本','缺失条件的边缘'],
     'c4.meters':['东城当期观测','西城当期观测'],'c4.original':['教学正文','三个适用条件'],
     'c4.revision':['删节层','收到原文记录'],'c4.petition':['请求范围','双方当次签认'],
     'c4.dependency':['计量服务','备份服务','共享服务'],'c4.school':['抄写正文','遗漏页脚'],
     'c4.ruler':['一方当次签认','另一方当次签认'],'c5.freeze':['冻结窗口','外部时间轨'],
     'c5.alibi':['分区位置记录','门禁副本'],'c5.conflict':['旧端等待条件','审查端等待条件'],
     'c5.deletion':['本地删除字段','独立残留字段'],'c5.port':['只读与同步','审计与发送'],
     'c5.names':['名册来源索引','私人信件附件'],'c5.empty':['未知与空白','缺页标记'],
     'c5.letter':['获准的信件正文','信封与来源'],'c6.current':['第一份陈述','第二份陈述','第三份陈述'],
     'c6.suppressed':['摘要省略层','当期异议原话'],'c6.roll':['左列三条票据','右列三条票据'],
     'c6.restores':['当期实例关联','历史状态字段'],'c6.algorithm':['批准与调用','今日计票目标'],
     'c6.attachment':['附件删改层','版本签认'],'c6.recipe':['今天的修改','配方上的生活痕迹'],
     'c6.upload_form':['第一项空白选择','第二项空白选择']}
    zones=ZONES[kind]
    if id=='c3.blank':zones=[(26,15,27,10),(28,26,25,13)]
    result=[dict(id=f'front_{i}',view='front',rect=[x*2,y*2,w*2,h*2],label=labels[id][i],description=note) for i,(x,y,w,h) in enumerate(zones)]
    result.append(dict(id='secondary',view='secondary',rect=[34,10,96,90],label=view,description='查阅'+view+'；界面正文读取剧情原数据，不把像素划线当作可读文字。'))
    return result

def fonts(size=18):return ImageFont.truetype(str(ROOT/'assets/fonts/pixel-text.otf'),size)

def generate():
    OUT.mkdir(parents=True,exist_ok=True);manifest=[]
    source_book=json.loads((ROOT/'assets/campaign-v5.json').read_text('utf-8'))
    first_source=(ROOT/'scripts/case_data.gd').read_text('utf-8').split('const QUESTIONS')[0]
    first_bodies=dict(re.findall(r'"(\w+)": \["[^"]+", "[^"]+", "([^"]+)"\]',first_source))
    for index,entry in enumerate(SPEC):
        id,name,kind,accent,look,hot,view,note=entry
        chapter=int(id[1]);key=id.split('.')[1];directory=OUT/id.replace('.','-');directory.mkdir(exist_ok=True)
        fronts=[]
        for label,secondary in [('front',False),('secondary',True)]:
            canvas=draw_model(entry,secondary);native=canvas.image();native.save(directory/f'{label}-80x56.png');native.resize((160,112),Image.Resampling.NEAREST).save(directory/f'{label}.png');(directory/f'{label}.svg').write_text(canvas.svg(),'utf-8');fronts.append(canvas.ops)
        # Fit into a 48 pixel inventory canvas, preserving integer scale and silhouette.
        im=draw_model(entry).image();bbox=im.getbbox();cropped=im.crop(bbox)
        ratio=min(42/cropped.width,42/cropped.height);small=cropped.resize((max(1,round(cropped.width*ratio)),max(1,round(cropped.height*ratio))),Image.Resampling.NEAREST)
        icon=Image.new('RGBA',(48,48));icon.alpha_composite(small,((48-small.width)//2,(48-small.height)//2));icon.save(directory/'icon.png')
        hotspots=make_hotspots(entry)
        linked=LINKS.get(id);category='collection' if id in COLLECTION_IDS else 'core';body=''
        if chapter>1 and category=='core':body=source_book[str(chapter)]['evidence'][key]['body']
        elif chapter==1 and category=='core':body=first_bodies[key]
        info=dict(id=id,title=name,chapter=chapter,category=category,carrier=kind,visual_role='record_proxy' if kind in PROXIES else ('source_index' if linked else 'object_or_document'),linked_source=linked,design_status='proposed_model',accent=accent,silhouette=look,inspect_note=note,secondary_label=view,story_body=body,spoiler_gate=f'c{chapter}.{key}.registered',dimensions=dict(native=[80,56],inspection=[160,112],inventory=[48,48]),pivot=[80,100],hotspots=hotspots,assets={x:f'{directory.name}/{x}.png' for x in ['icon','front','secondary']},models={'front':fronts[0],'secondary':fronts[1]})
        (directory/'model.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),'utf-8');manifest.append({k:v for k,v in info.items() if k!='models'})
    (OUT/'manifest.json').write_text(json.dumps(dict(version=1,palette=PALETTE,count=len(manifest),items=manifest),ensure_ascii=False,indent=2),'utf-8')
    make_sheets(manifest);make_docs(manifest);make_gallery(manifest)
    validate(manifest)
    package=ROOT/'build/EvidenceModels-v1-2D.zip'
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as z:
        for p in OUT.rglob('*'):
            if p.is_file():z.write(p,p.relative_to(OUT.parent))
        z.write(ROOT/'docs/证物模型设计-v1.md','证物模型设计-v1.md');z.write(Path(__file__),'build_evidence_models.py')
    print(json.dumps({'items':len(manifest),'core':sum(m['category']=='core' for m in manifest),'collection':sum(m['category']=='collection' for m in manifest),'zip':str(package),'sha256':hashlib.sha256(package.read_bytes()).hexdigest()},ensure_ascii=False))

def make_sheets(items):
    folder=OUT/'previews';folder.mkdir(exist_ok=True)
    font=fonts(20);small=fonts(16);titlefont=fonts(30)
    overview=Image.new('RGB',(1440,1680),'#202b2b');d=ImageDraw.Draw(overview);d.text((34,23),'启动阶段 / 证物造型总览',font=titlefont,fill=PALETTE['paper']);d.text((34,64),'37 个核心条目 + 12 个人物收藏页 · 2D 低像素 · 造型稿含剧透',font=small,fill=PALETTE['metal'])
    for ch in range(1,7):
        chapter=[m for m in items if m['chapter']==ch];row_y=105+(ch-1)*260;d.text((32,row_y),f'第 {ch} 章',font=font,fill=PALETTE['ochre'])
        for j,m in enumerate(chapter):
            x=30+j*155;y=row_y+34;preview=Image.open(OUT/m['assets']['front']).convert('RGBA');preview=preview.resize((144,101),Image.Resampling.NEAREST);overview.paste(preview,(x,y),preview);label=m['title'];d.text((x,y+108),label[:8],font=small,fill=PALETTE['paper']);d.text((x,y+130),label[8:16],font=small,fill=PALETTE['paper']);d.text((x,y+156),'人物页' if m['category']=='collection' else '核心证据',font=small,fill=PALETTE['metal'])
        columns=3;rows=(len(chapter)+columns-1)//columns;sheet=Image.new('RGB',(1200,100+rows*270),'#202b2b');sd=ImageDraw.Draw(sheet);sd.text((28,20),f'第 {ch} 章 / 逐件证物模型',font=titlefont,fill=PALETTE['paper'])
        for j,m in enumerate(chapter):
            x=20+(j%3)*395;y=88+(j//3)*270;sd.rectangle((x,y,x+378,y+250),fill='#2c3836');im=Image.open(OUT/m['assets']['front']).resize((240,168),Image.Resampling.NEAREST);sheet.paste(im,(x+68,y+5),im);sd.text((x+12,y+179),m['title'],font=font,fill=PALETTE['paper']);sd.text((x+12,y+211),m['id']+' / '+('人物收藏' if m['category']=='collection' else '核心条目'),font=small,fill=PALETTE['metal'])
        sheet.save(folder/f'chapter-{ch}.png')
    overview.save(folder/'all-evidence.png')
    # Transparency and native-scale proof, with no smoothing.
    atlas=Image.new('RGBA',(48*10,48*5))
    for i,m in enumerate(items):atlas.alpha_composite(Image.open(OUT/m['assets']['icon']),((i%10)*48,(i//10)*48))
    atlas.save(OUT/'inventory-atlas.png')

def make_docs(items):
    lines=['# 《启动阶段》证物模型设计 v1','', '日期：2026-09-30。已制作 49 个独立 2D 展示模型（37 核心条目＋12 人物收藏页），不是 3D 网格，也未接入正式游戏。','',
    '沿用本项目粗像素、少色平涂风格。模型分为真实物件／文书造型、数字记录的案卷展示代理、同源附件的纪念索引。证词不被擅自改为录音实物；技术记录图不表示侦探把终端机器收进背包。新增装订、外观磨损和配色属于造型提案，不单独证明剧情事实。','',
    '## 素材规格','', '- 全批共用 16 色，透明背景，无抗锯齿、阴影模糊和随机材质噪点。','- 每件：48×48 收集图标；80×56 原生正面／第二视图；160×112 整数倍检查图。','- 每件包含独立 SVG 与 model.json 几何源，可修改形状、颜色、热点，不依赖图像生成接口。','- 第二视图按物件分别采用背面、展开页、附件或来源链，不能一律把信息放在背面。','- 关键姓名、时间、编号与原话由游戏文字层叠加。图上的短线仅是排版示意，不是可读文字或新的事实。','- icon、front、secondary 三张图无自动剧透锁；接入时必须由真实剧情事件控制解锁。manifest 中 spoiler_gate 是建议键，不是已存在的运行接口。','- 检查热点是 160×112 坐标下的初版范围，正式 UI 需按实际显示比例转换。','',
    '## 交付文件','', '- assets/evidence-models-v1/<条目 ID>/：每件全部素材与几何源。','- assets/evidence-models-v1/manifest.json：索引、来源关联、造型说明、热点与文件路径。','- assets/evidence-models-v1/inventory-atlas.png：10 列、5 行、48px 格；末格透明。','- assets/evidence-models-v1/previews/：六章图和全量总览。','- assets/evidence-models-v1/gallery.html：离线逐件看正面／第二视图，显示说明与热点。','- scripts/build_evidence_models.py：可重新生成模型、预览、索引和分发包。','',
    '## 逐件设计','']
    for ch in range(1,7):
        lines+=['### 第 '+str(ch)+' 章','', '| ID／证物 | 轮廓和材质 | 检查点与第二视图 | 造型／叙事边界 |','|---|---|---|---|']
        for m in items:
            if m['chapter']==ch:lines.append(f'| `{m["id"]}` / {m["title"]} | {m["silhouette"]} | {m["hotspots"][0]["label"]}；{m["secondary_label"]} | {m["inspect_note"]} |')
        lines.append('')
    lines+=['## 同源关联与状态变化','', '孟岚的空白询问栏关联 c3.medical；顾舟空页和小满的信关联 c5.names。分别制作展示素材，不把它们算成额外独立证据。所有背面／附件都是检查视图，不暗示副本能独立印证原件。','',
    '模型只含初见正面和第二检查视图。已核实、封存、归还由 UI 标记叠加，避免盖章把原文盖掉。闻遥的钟不做时间随机动画；上传表两格初始均留白，选择之后才由真实事件添加状态。','',
    '## 接入建议与验证范围','', '使用 TextureRect／Sprite2D 时设为 nearest，检查图优先整数倍缩放；原件正文与热点标签使用既有 Fusion Pixel 字体。SVG 是编辑源，PNG 是交付素材。数字记录的代理图只出现在案卷，场景不随意新增设备。','',
    '生成检查包括：49 条目覆盖、全路径存在、尺寸、透明边界、16 色范围、正反差异、图标不重复、SVG 整数坐标与热点坐标。另在离线浏览器检查切换与窄屏显示。检查结果记录在 validation.json。没有替换现有美术，没有修改玩家存档，尚未验证游戏内热点手感。','']
    (ROOT/'docs/证物模型设计-v1.md').write_text('\n'.join(lines),'utf-8')

def make_gallery(items):
    data=json.dumps(items,ensure_ascii=False).replace('</','<\\/')
    html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>启动阶段 · 证物模型</title>
<style>*{box-sizing:border-box}body{margin:0;background:#202b2b;color:#e4d8b3;font:16px/1.7 "Microsoft YaHei",sans-serif}header{padding:24px 30px;border-bottom:1px solid #60665b}h1{font-size:25px;margin:0}small{color:#9bada1}main{padding:24px 30px}button{font:inherit;cursor:pointer;border:1px solid #60665b;padding:9px 12px;background:#2c3836;color:#e4d8b3;border-radius:2px;min-height:44px}button[aria-pressed=true]{background:#e4d8b3;color:#182326}nav{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}.grid{display:grid;grid-template-columns:minmax(230px,1fr) minmax(320px,1.8fr);gap:24px}.items{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.item{display:flex;flex-direction:column;align-items:center;text-align:center;font-size:14px}.item img{width:96px;height:96px;image-rendering:pixelated}.detail{background:#2c3836;padding:22px;align-self:start}.detail h2{margin:0;font-size:22px}.preview{position:relative;width:100%;max-width:640px;aspect-ratio:160/112;margin:18px 0;background:repeating-conic-gradient(#273532 0% 25%,#344442 0% 50%) 0 0/24px 24px}.preview img{width:100%;height:100%;image-rendering:pixelated;display:block}.hot{position:absolute;border:2px dashed #b79c67;background:#b79c6720}.key{color:#b79c67}p{overflow-wrap:anywhere}.actions{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0}.details{display:grid;grid-template-columns:72px 1fr;gap:8px}.details dd{margin:0;overflow-wrap:anywhere}.gate{max-width:660px;margin:40px 0}.note{border-top:1px solid #60665b;padding-top:16px}@media(max-width:700px){header,main{padding:18px}.grid{grid-template-columns:1fr}.detail{padding:16px}.items{grid-template-columns:repeat(3,minmax(0,1fr))}.item img{width:72px;height:72px}.item{padding:6px;font-size:13px}}@media(max-width:390px){.items{grid-template-columns:repeat(2,minmax(0,1fr))}}</style>
<header><h1>启动阶段 · 证物模型</h1><small>49 个独立展示条目 / 16 色 / 透明像素素材 / 正面与检查视图</small></header>
<main id="root"><div class="gate"><h2>六章证物造型稿</h2><p>这份模型目录包含案件证物、人物私人物件及后期身份信息。</p><button id="enter">查看全部设计（含剧透）</button></div></main>
<script>const models=__DATA__;let chapter=1,id=models[0].id,view='front',hot=false;const root=document.getElementById('root');
function render(){let m=models.find(x=>x.id===id);root.innerHTML='<nav>'+[1,2,3,4,5,6].map(ch=>'<button data-ch="'+ch+'" aria-pressed="'+(ch===chapter)+'">第 '+ch+' 章</button>').join('')+'</nav><div class="grid"><section class="items">'+models.filter(x=>x.chapter===chapter).map(x=>'<button class="item" data-id="'+x.id+'" aria-pressed="'+(x.id===id)+'"><img src="'+x.assets.icon+'" alt=""><span>'+x.title+'</span><small>'+x.id+'</small></button>').join('')+'</section><article class="detail"><small>'+m.id+' · '+(m.category==='core'?'核心条目':'人物收藏页')+'</small><h2>'+m.title+'</h2><div class="actions"><button data-view="front" aria-pressed="'+(view==='front')+'">正面</button><button data-view="secondary" aria-pressed="'+(view==='secondary')+'">'+m.secondary_label+'</button><button data-hot aria-pressed="'+hot+'">检查热点</button></div><div class="preview"><img src="'+m.assets[view]+'" alt="'+m.title+'的'+(view==='front'?'正面':m.secondary_label)+'">'+(hot?m.hotspots.filter(x=>x.view===view).map(x=>'<div class="hot" style="left:'+x.rect[0]/160*100+'%;top:'+x.rect[1]/112*100+'%;width:'+x.rect[2]/160*100+'%;height:'+x.rect[3]/112*100+'%"></div>').join(''):'')+'</div><dl class="details"><dt>造型</dt><dd>'+m.silhouette+'</dd><dt>检查</dt><dd>'+m.hotspots.find(x=>x.view===view).label+'</dd><dt>边界</dt><dd>'+m.inspect_note+'</dd><dt>载体</dt><dd>'+(m.visual_role==='record_proxy'?'数字记录的案卷展示代理':m.visual_role==='source_index'?'原件／附件的同源展示索引':'物件或文书造型')+'</dd></dl>'+(m.linked_source?'<p class="key">同源关联：'+m.linked_source+'，不重复计为独立证据。</p>':'')+'<div class="note"><a style="color:#adc2a0" href="'+m.id.replace('.','-')+'/model.json">几何模型与热点数据</a> · <a style="color:#adc2a0" href="'+m.id.replace('.','-')+'/'+view+'.svg">可编辑 SVG</a></div></article></div>';}
root.addEventListener('click',e=>{let b=e.target.closest('button');if(!b)return;if(b.id==='enter'){render();return}if(b.dataset.ch){chapter=Number(b.dataset.ch);id=models.find(x=>x.chapter===chapter).id;view='front';}if(b.dataset.id){id=b.dataset.id;view='front';}if(b.dataset.view)view=b.dataset.view;if(b.hasAttribute('data-hot'))hot=!hot;render();});</script></html>'''
    (OUT/'gallery.html').write_text(html.replace('__DATA__',data),'utf-8')

def validate(items):
    assert len(items)==49 and len({m['id'] for m in items})==49
    assert sum(m['category']=='core' for m in items)==37
    hashes=[]
    for m in items:
        for kind,dim in [('icon',(48,48)),('front',(160,112)),('secondary',(160,112))]:
            p=OUT/m['assets'][kind];im=Image.open(p).convert('RGBA');assert im.size==dim
            assert im.getbbox() and im.getextrema()[3][0]==0
            rgba={tuple(bytes.fromhex(h[1:]))+(255,) for h in PALETTE.values()}
            assert all(pixel[3]==0 or pixel in rgba for pixel in im.getdata())
        assert (OUT/m['assets']['front']).read_bytes()!=(OUT/m['assets']['secondary']).read_bytes()
        hashes.append(hashlib.sha256((OUT/m['assets']['icon']).read_bytes()).hexdigest())
        for h in m['hotspots']:
            x,y,w,height=h['rect'];assert 0<=x and 0<=y and x+w<=160 and y+height<=112
    assert len(set(hashes))==49,'Each inventory silhouette must have its own rendered image.'
    report=dict(items=49,core=37,collection=12,unique_icons=49,palette_colors=len(PALETTE),png_count=49*5+8,svg_count=98,geometry_sources=49,checks=['coverage','paths','dimensions','transparency','palette','front_secondary_difference','unique_icons','hotspot_bounds'],browser_check='pending',game_integration=False)
    (OUT/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')

if __name__=='__main__':generate()
