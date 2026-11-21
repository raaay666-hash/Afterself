"""Publish a ZIP containing the self-contained setup, instructions, and checks."""
import hashlib
import json
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/installer-distribution'
DELIVERY = OUT / 'delivery'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def read(path):
    return json.loads(path.read_text('utf-8-sig'))

def main():
    package = read(OUT/'package-verification.json')
    logic = read(OUT/'qa-game/logic-results.json')
    window = read(OUT/'qa-game/window-results.json')
    install = read(OUT/'qa-install/installer-results.json')
    core = read(OUT/'qa-core/core-results.json')
    resource = read(OUT/'resource-verification.json')
    assert all(r['passed'] for r in [logic, window, install, core])
    items = {item['name']:item for item in package['artifacts']}
    source = OUT/'Afterself-FirstBuild-0.10.0-Setup.exe'
    setup_hash = digest(source)
    game_hash = digest(OUT/'stage/StartupPhase.exe')
    assert setup_hash == install['installer_sha256'] == items[source.name]['sha256']
    assert game_hash == logic['sha256'] == window['sha256'] == resource['sha256']
    assert len(core['checks']) == 8 and all(c['passed'] for c in core['checks'])
    DELIVERY.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,DELIVERY/'Afterself-Setup.exe')
    (DELIVERY/'安装说明.txt').write_text('''AFTERSELF · 启动阶段 — Windows x64 独立安装包
游戏版本 0.10.0 / 安装包修订 2 / 2026-10-02

1. 请先把整个压缩包解压到本机文件夹。
2. 双击 Afterself-Setup.exe，查看试玩说明和第三方许可后勾选阅读确认。
3. 可在高级选项中选择空的安装目录，设置桌面／开始菜单快捷方式和完成后启动。
4. 点击开始安装。安装程序已经包含完整游戏，无需联网下载或安装 Godot。
5. 安装后可从快捷方式或安装目录内 StartupPhase.exe 打开游戏。

默认目录：%LOCALAPPDATA%\\Programs\\Afterself。
更换版本时先卸载旧安装，不覆盖非空目录。
卸载：安装目录内 Uninstall.exe；普通安装也登记到 Windows 已安装的应用。
存档：%APPDATA%\\StartupPhase，卸载保留存档、修改过的文件及自行添加文件。

适用目标为 Windows 10/11 x64；安装器使用系统 .NET Framework。
本包包含六章一周目、人物、证物、解谜、字体及音效。
文件未签名，其他电脑兼容性和 Windows 应用列表入口尚未实际验收。
本次复查结果见 检查结果.txt，解压后文件的 SHA-256 见 SHA256SUMS.txt。
''','utf-8-sig')
    fixes = [
        '修复相对路径和末尾点／空格被接受的问题，只允许完整的本机磁盘路径。',
        '修复安装期间发生文件名冲突时，回滚可能误删另一方文件的问题。',
        '修复安装回执可能覆盖后来出现的同名文件的问题，现仅创建新文件。',
        '修复回滚遇到被占用文件后中断清理的问题，继续清理其余文件并报告未清理项。',
        '安装和卸载互斥，避免同时操作；完成后启动失败会给出提示。',
    ]
    summary = dict(date='2026-10-02',game_version='0.10.0',installer_revision=2,passed=True,
                   setup_sha256=setup_hash,game_sha256=game_hash,
                   fixes=fixes,game_checks=[dict(test=x['test'],passed=x['passed']) for x in logic['results']+window['results']],
                   installer_checks=install['checks'],edge_case_checks=core['checks'],
                   resource_checks={k:v for k,v in resource.items() if k!='executable'},
                   limitations=['其他电脑兼容性未实测','Windows应用列表入口未操作验收','未验证真人时长或主观听感','程序未签名'])
    (OUT/'recheck-verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),'utf-8')
    check_text = '''2026-10-02 复查结果 — 安装包修订 2

本轮复现并修复：
'''+ '\n'.join('- '+fix for fix in fixes) + '''

最终验收：
- 5组游戏逻辑回归通过：首章、后五章与六种结尾、复盘、证物、现场解谜。
- 4组游戏窗口／音频检查通过：29步现场操作、证物窗口、六章加速通关、7类音频加载。
- 9项隔离安装／卸载检查通过，包括取消回滚、快捷方式、清单篡改与用户文件保留。
- 8项新增异常检查通过，包括相对路径、非法路径、同名文件冲突、被占用文件及并发入口。
- 最终游戏内嵌资源逐项校验通过：49件证物、147张证物图、9张背景与六章数据完整。
- 安装器测试哈希与本压缩包中的 Afterself-Setup.exe 一致。

本轮未发现阻断通关的问题。检查通过不能证明不存在任何潜在bug。
隔离测试不写用户桌面、Windows正式卸载登记或玩家存档。
其他电脑兼容性、Windows应用列表入口及陌生玩家体验仍待验收；程序未签名。

安装程序 SHA-256：
'''+setup_hash+'\n\n游戏 EXE SHA-256：\n'+game_hash+'\n'
    (DELIVERY/'检查结果.txt').write_text(check_text,'utf-8-sig')
    names=['Afterself-Setup.exe','安装说明.txt','检查结果.txt']
    sums='\n'.join(digest(DELIVERY/name)+'  '+name for name in names)+'\n'
    (DELIVERY/'SHA256SUMS.txt').write_text(sums,'utf-8')
    names.append('SHA256SUMS.txt')
    manifest=dict(game_version='0.10.0',installer_revision=2,files=[dict(name=n,bytes=(DELIVERY/n).stat().st_size,sha256=digest(DELIVERY/n)) for n in names])
    (DELIVERY/'package-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),'utf-8')
    names.append('package-manifest.json')
    zip_path=OUT/'Afterself-0.10.0-Windows-x64-Installer.zip'
    prefix='Afterself-Installer/'
    with ZipFile(zip_path,'w',ZIP_DEFLATED,compresslevel=6) as archive:
        for name in names:
            archive.write(DELIVERY/name,prefix+name)
    with ZipFile(zip_path) as archive:
        assert archive.testzip() is None
        assert archive.namelist()==[prefix+n for n in names]
        for name in names:
            assert hashlib.sha256(archive.read(prefix+name)).hexdigest()==digest(DELIVERY/name)
        # Run subsequent installation QA on an executable extracted from the final ZIP.
        extracted=OUT/'qa-delivered-setup'
        extracted.mkdir(exist_ok=True)
        (extracted/'Afterself-Setup.exe').write_bytes(archive.read(prefix+'Afterself-Setup.exe'))
    report=dict(name=zip_path.name,bytes=zip_path.stat().st_size,sha256=digest(zip_path),
                setup_sha256=setup_hash,member_count=len(names),crc_verified=True,all_member_hashes_verified=True)
    (OUT/'installer-zip-verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf-8')
    (OUT/(zip_path.name+'.sha256')).write_text(report['sha256']+'  '+zip_path.name+'\n','utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
