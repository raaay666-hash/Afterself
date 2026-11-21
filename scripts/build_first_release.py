"""Build the first integrated native installer and a clean portable release."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/first-installer'
STAGE = OUT / 'stage'
CSC = Path('C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe')
VERSION = '0.10.0'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def run(args, log):
    result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True)
    log.write_bytes(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(log.read_text('utf-8', errors='replace'))

def main():
    global OUT, STAGE
    parser = argparse.ArgumentParser()
    parser.add_argument('--reuse-export', action='store_true')
    parser.add_argument('--out', type=Path, default=OUT)
    args = parser.parse_args()
    OUT = args.out.resolve()
    STAGE = OUT / 'stage'
    STAGE.mkdir(parents=True, exist_ok=True)
    artwork = ROOT / 'assets/branding/afterself-approved-installer-art.png'
    assert digest(artwork) == '4ca77157e44a3c3af9a3d891f586626e1f78ae4c2f2046370fa871434f38441b'
    icon = artwork.with_suffix('.ico')
    if not args.reuse_export:
        run([ROOT / '.tools/godot/Godot_v4.5.1-stable_win64_console.exe', '--headless', '--path', ROOT,
             '--log-file', OUT / 'export-godot.log', '--export-release', 'Windows Desktop',
             STAGE / 'StartupPhase.exe'], OUT / 'export-process.log')
    assert (STAGE / 'StartupPhase.exe').stat().st_size > 90_000_000
    for name in ['GODOT-LICENSE.txt', 'GODOT-THIRD-PARTY.txt', 'FONT-LICENSES.txt']:
        shutil.copy2(ROOT / 'build/v10/windows' / name, STAGE / name)
    shutil.copy2(icon, STAGE / 'Afterself.ico')
    notice = '''AFTERSELF · 启动阶段 — 第一版整合试玩包
内部版本 0.10.0 / Windows x64 / 2026-10-02

游戏内容：六章一周目、12 名人物、49 件证物、12 段主线现场操作、
6 段可选小谜题，公共方案及个人选择共同形成六种结尾组合。
已有像素场景、人物骨骼动作、中文像素字体、七类程序合成声音均已整合。
离线运行，无需安装 Godot。免安装包解压后双击 StartupPhase.exe。

鼠标点选调查；J 案卷；H 热点；空格继续对白；Esc 暂停或关闭面板；
M 静音；F11 全屏。现场操作有分级提示，证物不会因操作失败而消耗。

安装器：默认安装到当前用户的 LocalAppData\\Programs\\Afterself。
可以选择本机空目录、桌面与开始菜单快捷方式、安装完成后启动。
文件写入时逐个核对 SHA-256。取消或失败会清理本次写入的文件。
不覆盖非空目录；更换版本请先卸载旧版。卸载器为 Uninstall.exe，
也可从 Windows“已安装的应用”卸载。存档、已修改文件与自行添加文件保留。

存档：%APPDATA%\\StartupPhase\\chapter1-v10.json 与 campaign-v10.json。
可首次接续 v9、v6、v5；首章另兼容 v4，旧文件不覆盖。
安装测试和自动通关均使用隔离文件，不会改动玩家存档。

试玩说明：一周目已贯通，二周目尚未制作。三小时只是设计目标，
没有经过陌生玩家时长、其他电脑兼容性或主观听感验收。没有配音。
程序未签名。本包没有增设商业许可或要求接受虚构的游戏协议。
Godot 与字体的第三方许可全文见同目录的三个 LICENSE / THIRD-PARTY 文件。
本次包含的美术与生成方式见制作来源.txt，文件哈希见 release-manifest.json。
'''
    (STAGE / '开始前请读.txt').write_text(notice, 'utf-8')
    (OUT / 'notice.txt').write_text(notice, 'utf-8')
    (STAGE / '制作来源.txt').write_text('''AFTERSELF · 启动阶段 — 资源整合记录

当前可运行内容以 project.godot、main.tscn、scripts/campaign.gd 为入口。
六章剧本源：docs/原始六章剧本.md、scripts/build_campaign_data.py。
运行数据：campaign-v5.json、investigation-v6.json、evidence-runtime-v9.json、fieldwork-v10.json。
角色：首章已确认素材与后七人的程序绘制少色上身，共用骨骼动作。
场景：9 张像素环境底图；部分背景由内置 imagegen 生成并按 320×180 采样。
证物：采用最终版 evidence-models-v2 少色模型，共49件，排除v1及图库预览。
近景：scripts/puzzle_art.gd 绘制；12段主线及6段可选现场操作。
音频：七类程序合成音效／环境声，无配音。
字体：项目既有 Fusion Pixel 中文字体；全部上游许可随包提供。
安装界面：复用 installer-prototype 的档案室、林砚、配色与欢迎／安装／完成流程，
以原生 Windows 程序实现真实解包、校验、快捷方式和卸载。
图标：用户已选 afterself-approved-installer-art.png，母版 SHA-256：
4ca77157e44a3c3af9a3d891f586626e1f78ae4c2f2046370fa871434f38441b
仅按最近邻采样转换为16/24/32/48/64/128/256尺寸的Windows ICO。
游戏内部名称及 StartupPhase 存档目录保持已有规则。
''', 'utf-8')
    names = ['StartupPhase.exe','Afterself.ico','开始前请读.txt','制作来源.txt',
             'GODOT-LICENSE.txt','GODOT-THIRD-PARTY.txt','FONT-LICENSES.txt']
    release = dict(id='Afterself.StartupPhase', version=VERSION, installed_bytes=sum((STAGE/n).stat().st_size for n in names),
                   files=[dict(name=n, bytes=(STAGE/n).stat().st_size, sha256=digest(STAGE/n)) for n in names])
    (OUT / 'release.json').write_text(json.dumps(release, ensure_ascii=False, indent=2), 'utf-8')
    shutil.copy2(OUT / 'release.json', STAGE / 'release-manifest.json')
    # The manifest describes all other payload files, and is itself independently hashed in the embedded installer metadata.
    names.append('release-manifest.json')
    release['files'].append(dict(name=names[-1], bytes=(STAGE/names[-1]).stat().st_size, sha256=digest(STAGE/names[-1])))
    release['installed_bytes'] += release['files'][-1]['bytes']
    (OUT / 'release.json').write_text(json.dumps(release, ensure_ascii=False, indent=2), 'utf-8')
    payload = OUT / 'payload.zip'
    with ZipFile(payload, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        for name in names:
            archive.write(STAGE / name, name)
    refs = ['System.dll','System.Core.dll','System.Drawing.dll','System.Windows.Forms.dll',
            'System.Web.Extensions.dll','System.IO.Compression.dll','System.IO.Compression.FileSystem.dll']
    resources = [(OUT / 'release.json','release.json'), (OUT / 'notice.txt','notice.txt'),
                 (icon,'icon.ico'), (ROOT / 'installer-prototype/art/archive.png','archive.png'),
                 (ROOT / 'installer-prototype/art/characters.png','characters.png')]
    resources += [(STAGE / name, name) for name in ['GODOT-LICENSE.txt','GODOT-THIRD-PARTY.txt','FONT-LICENSES.txt']]
    base = [CSC, '/nologo','/target:winexe','/platform:x64','/optimize+','/codepage:65001',
            '/win32icon:'+str(icon), '/win32manifest:'+str(ROOT / 'installer/app.manifest')]
    base += ['/reference:'+name for name in refs]
    base += ['/resource:'+str(path)+','+name for path,name in resources]
    source = ROOT / 'installer/AfterselfSetup.cs'
    uninstall = OUT / 'Uninstall.exe'
    run(base+['/out:'+str(uninstall),source], OUT / 'compile-uninstall.log')
    setup = OUT / ('Afterself-FirstBuild-'+VERSION+'-Setup.exe')
    run(base+['/resource:'+str(uninstall)+',uninstaller.exe', '/resource:'+str(payload)+',payload.zip', '/out:'+str(setup),source], OUT / 'compile-setup.log')
    portable = OUT / ('Afterself-FirstBuild-'+VERSION+'-Windows-x64.zip')
    with ZipFile(portable, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        for name in names:
            archive.write(STAGE / name, 'Afterself-'+VERSION+'/'+name)
    for package, prefix in [(payload,''),(portable,'Afterself-'+VERSION+'/')]:
        with ZipFile(package) as archive:
            assert archive.testzip() is None
            assert len(archive.namelist()) == len(names)
            for file in release['files']:
                assert hashlib.sha256(archive.read(prefix+file['name'])).hexdigest() == file['sha256']
    artifacts=[dict(name=p.name,bytes=p.stat().st_size,sha256=digest(p)) for p in [setup,portable,STAGE/'StartupPhase.exe',uninstall]]
    report=dict(version=VERSION,artifacts=artifacts,zip_crc_verified=True,all_payload_hashes_verified=True,
                approved_artwork_verified=True,compiled_from='installer/AfterselfSetup.cs')
    (OUT / 'package-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    (OUT / 'SHA256SUMS.txt').write_text('\n'.join(x['sha256']+'  '+x['name'] for x in artifacts)+'\n','utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__ == '__main__':
    main()
