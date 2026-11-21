using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Web.Script.Serialization;
using Microsoft.Win32;

[assembly: AssemblyTitle("AFTERSELF · 启动阶段")]
[assembly: AssemblyVersion("0.10.0.0")]
[assembly: AssemblyFileVersion("0.10.0.0")]

public class ReleaseFile { public string name; public long bytes; public string sha256; }
public class Release { public string id; public string version; public long installed_bytes; public ReleaseFile[] files; }
public class Receipt { public string id; public string version; public bool test; public bool registry; public string[] shortcuts; public ReleaseFile[] files; }
public class Installed { public string target; public long bytes; public string[] shortcuts; }

static class Core {
    internal const string Id="Afterself.StartupPhase", ReceiptName="afterself-install.json";
    internal const string RegistryPath=@"Software\Microsoft\Windows\CurrentVersion\Uninstall\Afterself.StartupPhase";
    internal static readonly JavaScriptSerializer Json=new JavaScriptSerializer();
    internal static readonly Release Release=Json.Deserialize<Release>(Text("release.json"));
    internal static Stream Resource(string name) { return Assembly.GetExecutingAssembly().GetManifestResourceStream(name); }
    internal static string Text(string name) { using(var s=Resource(name)) using(var r=new StreamReader(s,Encoding.UTF8)) return r.ReadToEnd(); }
    internal static Image Art(string name) { using(var s=Resource(name)) using(var i=Image.FromStream(s)) return new Bitmap(i); }
    internal static string Hash(string path) { using(var s=File.OpenRead(path)) using(var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(s)).Replace("-", "").ToLowerInvariant(); }
    internal static void Validate(string path, bool empty) {
        if(String.IsNullOrWhiteSpace(path) || !System.Text.RegularExpressions.Regex.IsMatch(path,@"^[A-Za-z]:\\") || path.Substring(2).Contains(":") || path.Length>180) throw new IOException("请选择本机磁盘中的完整安装路径，例如 C:\\Games\\Afterself，长度不超过 180 个字符。");
        foreach(var part in path.Substring(3).Split('\\')) {
            if((part!="." && part!=".." && (part.EndsWith(".") || part.EndsWith(" "))) || System.Text.RegularExpressions.Regex.IsMatch(part,@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)",System.Text.RegularExpressions.RegexOptions.IgnoreCase)) throw new IOException("路径中包含 Windows 保留名称或末尾的点／空格。");
        }
        var full=Path.GetFullPath(path).TrimEnd(Path.DirectorySeparatorChar);
        if(full.Length<=3 || full.IndexOfAny(new[]{'<','>','\"','|','?','*'})>=0) throw new IOException("不能安装到磁盘根目录或包含无效字符的路径。");
        var win=Environment.GetFolderPath(Environment.SpecialFolder.Windows).TrimEnd('\\');
        if(full.Equals(win,StringComparison.OrdinalIgnoreCase) || full.StartsWith(win+"\\",StringComparison.OrdinalIgnoreCase)) throw new IOException("不能安装到 Windows 系统目录。");
        foreach(var part in full.Substring(3).Split('\\')) {
            if(part.EndsWith(".") || part.EndsWith(" ") || System.Text.RegularExpressions.Regex.IsMatch(part,@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)",System.Text.RegularExpressions.RegexOptions.IgnoreCase)) throw new IOException("路径中包含 Windows 保留名称。");
        }
        if(File.Exists(full) || (empty && Directory.Exists(full) && Directory.EnumerateFileSystemEntries(full).Any())) throw new IOException("这个目录已有文件。请选择一个空目录；已有版本请先卸载，存档会保留。");
    }
    internal static string ShortcutRoot(string target,bool test,bool desktop) {
        return test ? Path.Combine(Path.GetDirectoryName(target),desktop?"test-desktop":"test-menu") : Environment.GetFolderPath(desktop?Environment.SpecialFolder.DesktopDirectory:Environment.SpecialFolder.Programs);
    }
    internal static string Shortcut(string target,bool test,bool desktop) { return Path.Combine(ShortcutRoot(target,test,desktop),"AFTERSELF · 启动阶段.lnk"); }
    internal static void MakeShortcut(string link,string target) {
        Directory.CreateDirectory(Path.GetDirectoryName(link));
        Type type=Type.GetTypeFromProgID("WScript.Shell"); object shell=Activator.CreateInstance(type); object item=null;
        try {
            item=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{link});
            var t=item.GetType();
            t.InvokeMember("TargetPath",BindingFlags.SetProperty,null,item,new object[]{Path.Combine(target,"StartupPhase.exe")});
            t.InvokeMember("WorkingDirectory",BindingFlags.SetProperty,null,item,new object[]{target});
            t.InvokeMember("IconLocation",BindingFlags.SetProperty,null,item,new object[]{Path.Combine(target,"Afterself.ico")+",0"});
            t.InvokeMember("Description",BindingFlags.SetProperty,null,item,new object[]{"AFTERSELF · 启动阶段 — 六章一周目"});
            t.InvokeMember("Save",BindingFlags.InvokeMethod,null,item,null);
        } finally { if(item!=null) Marshal.FinalReleaseComObject(item); Marshal.FinalReleaseComObject(shell); }
    }
    internal static bool IsOurShortcut(string link,string target) {
        if(!File.Exists(link)) return false;
        Type type=Type.GetTypeFromProgID("WScript.Shell");object shell=Activator.CreateInstance(type), item=null;
        try { item=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{link});return String.Equals((string)item.GetType().InvokeMember("TargetPath",BindingFlags.GetProperty,null,item,null),Path.Combine(target,"StartupPhase.exe"),StringComparison.OrdinalIgnoreCase); }
        finally { if(item!=null) Marshal.FinalReleaseComObject(item);Marshal.FinalReleaseComObject(shell); }
    }
    internal static Installed Install(string target,bool desktop,bool menu,bool test,Action<int,string> progress,CancellationToken cancel) {
        Validate(target,true); target=Path.GetFullPath(target).TrimEnd('\\');
        long space=new DriveInfo(Path.GetPathRoot(target)).AvailableFreeSpace;
        if(space<Release.installed_bytes+16*1024*1024) throw new IOException("目标磁盘的可用空间不足。");
        var written=new List<string>();var links=new List<string>();bool created=!Directory.Exists(target); bool registered=false;
        Directory.CreateDirectory(target);
        try {
            long total=Release.files.Sum(f=>f.bytes), done=0;
            using(var stream=Resource("payload.zip")) using(var zip=new ZipArchive(stream,ZipArchiveMode.Read)) {
                if(zip.Entries.Count!=Release.files.Length) throw new IOException("安装包文件数量不匹配。");
                foreach(var file in Release.files) {
                    cancel.ThrowIfCancellationRequested();
                    if(Path.GetFileName(file.name)!=file.name) throw new IOException("安装包路径无效。");
                    var entry=zip.GetEntry(file.name);if(entry==null || entry.Length!=file.bytes) throw new IOException("安装包缺少文件："+file.name);
                    var path=Path.Combine(target,file.name);
                    using(var input=entry.Open()) using(var output=new FileStream(path,FileMode.CreateNew,FileAccess.Write,FileShare.None)) using(var sha=SHA256.Create()) {
                        written.Add(path);
                        byte[] buffer=new byte[1024*1024];int n;long bytes=0;
                        while((n=input.Read(buffer,0,buffer.Length))>0) { cancel.ThrowIfCancellationRequested();output.Write(buffer,0,n);sha.TransformBlock(buffer,0,n,null,0);done+=n;bytes+=n;progress((int)(done*90/total),"写入并校验："+file.name); }
                        sha.TransformFinalBlock(new byte[0],0,0);
                        var hash=BitConverter.ToString(sha.Hash).Replace("-", "").ToLowerInvariant();
                        if(bytes!=file.bytes || hash!=file.sha256) throw new IOException("文件校验失败："+file.name);
                    }
                }
            }
            cancel.ThrowIfCancellationRequested(); progress(92,"写入卸载程序");
            var uninstaller=Path.Combine(target,"Uninstall.exe");
            using(var source=Resource("uninstaller.exe")) using(var output=new FileStream(uninstaller,FileMode.CreateNew)) {written.Add(uninstaller);source.CopyTo(output);}
            var managed=Release.files.ToList();managed.Add(new ReleaseFile{name="Uninstall.exe",bytes=new FileInfo(uninstaller).Length,sha256=Hash(uninstaller)});
            if(desktop || menu) { progress(95,"创建快捷方式");foreach(var d in new[]{true,false}) if(d?desktop:menu) {
                var link=Shortcut(target,test,d); if(File.Exists(link)) throw new IOException("同名快捷方式已存在，请取消相应选项后重试。");
                links.Add(link);MakeShortcut(link,target);
            }}
            cancel.ThrowIfCancellationRequested();progress(98,"登记安装信息");
            if(!test) {
                using(var previous=Registry.CurrentUser.OpenSubKey(RegistryPath)) if(previous!=null) throw new IOException("已有 AFTERSELF 安装登记，请先卸载已有版本。");
                using(var key=Registry.CurrentUser.CreateSubKey(RegistryPath)) {
                    registered=true; key.SetValue("DisplayName","AFTERSELF · 启动阶段"); key.SetValue("DisplayVersion",Release.version);
                    key.SetValue("InstallLocation",target);key.SetValue("UninstallString","\""+uninstaller+"\"");key.SetValue("DisplayIcon",Path.Combine(target,"Afterself.ico"));
                    key.SetValue("EstimatedSize",(int)((Release.installed_bytes+1023)/1024),RegistryValueKind.DWord);key.SetValue("NoModify",1,RegistryValueKind.DWord);key.SetValue("NoRepair",1,RegistryValueKind.DWord);
                }
            }
            var receipt=new Receipt{id=Id,version=Release.version,test=test,registry=registered,shortcuts=links.ToArray(),files=managed.ToArray()};
            var receiptPath=Path.Combine(target,ReceiptName);
            using(var output=new FileStream(receiptPath,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {written.Add(receiptPath);using(var writer=new StreamWriter(output,new UTF8Encoding(false))) writer.Write(Json.Serialize(receipt));}
            progress(100,"安装完成");return new Installed{target=target,bytes=written.Sum(f=>new FileInfo(f).Length),shortcuts=links.ToArray()};
        } catch(Exception original) {
            var cleanupErrors=new List<string>();
            Action<Action,string> attempt=(action,name)=>{try{action();}catch(Exception failure){cleanupErrors.Add(name+"："+failure.Message);}};
            foreach(var link in links) attempt(()=>{if(IsOurShortcut(link,target))File.Delete(link);},link);
            if(registered) attempt(()=>Registry.CurrentUser.DeleteSubKeyTree(RegistryPath,false),"卸载登记");
            foreach(var path in written.AsEnumerable().Reverse()) attempt(()=>{if(File.Exists(path))File.Delete(path);},path);
            attempt(()=>{if(created && Directory.Exists(target) && !Directory.EnumerateFileSystemEntries(target).Any())Directory.Delete(target);},target);
            if(cleanupErrors.Count>0) throw new IOException((original is OperationCanceledException?"安装已取消。":original.Message)+"\n部分本次安装文件被占用，未完全清理：\n"+String.Join("\n",cleanupErrors),original);
            throw;
        }
    }
    internal static string[] Uninstall(bool test) {
        var own=Assembly.GetExecutingAssembly().Location;var target=Path.GetDirectoryName(own);Validate(target,false);
        var receiptPath=Path.Combine(target,ReceiptName);
        var receipt=Json.Deserialize<Receipt>(File.ReadAllText(receiptPath,Encoding.UTF8));
        if(receipt==null || receipt.files==null || receipt.shortcuts==null || receipt.files.Any(f=>f==null) || receipt.id!=Id || receipt.test!=test) throw new IOException("安装记录与当前卸载模式不匹配。");
        var allowed=Release.files.Select(f=>f.name).Concat(new[]{"Uninstall.exe"}).ToArray();
        if(receipt.files.Length!=allowed.Length || receipt.files.Select(f=>f.name).Distinct().Count()!=allowed.Length || receipt.files.Any(f=>!allowed.Contains(f.name)) || Core.Release.files.Any(f=>!receipt.files.Any(r=>r.name==f.name && r.sha256==f.sha256 && r.bytes==f.bytes))) throw new IOException("安装文件清单无效，未删除任何文件。");
        foreach(var process in System.Diagnostics.Process.GetProcessesByName("StartupPhase")) { using(process) { try { if(String.Equals(process.MainModule.FileName,Path.Combine(target,"StartupPhase.exe"),StringComparison.OrdinalIgnoreCase)) throw new IOException("请先退出游戏，再卸载。"); } catch(System.ComponentModel.Win32Exception) { throw new IOException("无法确认游戏是否已退出，请关闭游戏后重试。"); } } }
        var preserved=new List<string>();
        foreach(var file in receipt.files) {
            if(file.name=="Uninstall.exe") continue;
            var path=Path.Combine(target,file.name);
            if(!File.Exists(path)) continue;
            if(Hash(path)!=file.sha256) { preserved.Add(file.name);continue; }
            File.Delete(path);
        }
        foreach(var d in new[]{true,false}) { var link=Shortcut(target,test,d);if(receipt.shortcuts.Contains(link) && IsOurShortcut(link,target)) File.Delete(link); }
        if(receipt.registry && !test) { using(var key=Registry.CurrentUser.OpenSubKey(RegistryPath)) if(key!=null && String.Equals((string)key.GetValue("InstallLocation"),target,StringComparison.OrdinalIgnoreCase)) Registry.CurrentUser.DeleteSubKeyTree(RegistryPath,false); }
        File.Delete(receiptPath);
        // Exact owned executable only; never recursively remove an installation directory.
        string script="Wait-Process -Id "+System.Diagnostics.Process.GetCurrentProcess().Id+" -ErrorAction SilentlyContinue; Remove-Item -LiteralPath '"+own.Replace("'","''")+"' -Force; if ((Test-Path -LiteralPath '"+target.Replace("'","''")+"') -and -not (Get-ChildItem -LiteralPath '"+target.Replace("'","''")+"' -Force)) { Remove-Item -LiteralPath '"+target.Replace("'","''")+"' }";
        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("powershell.exe","-NoProfile -NonInteractive -EncodedCommand "+Convert.ToBase64String(Encoding.Unicode.GetBytes(script))) {UseShellExecute=false,CreateNoWindow=true,WindowStyle=System.Diagnostics.ProcessWindowStyle.Hidden});
        return preserved.ToArray();
    }
}

class PixelProgress : Control {
    int value;
    internal int Value { get{return value;} set{this.value=value;Invalidate();} }
    internal PixelProgress(){DoubleBuffered=true;}
    protected override void OnPaint(PaintEventArgs e) {
        using(var b=new SolidBrush(ColorTranslator.FromHtml("#101722")))e.Graphics.FillRectangle(b,ClientRectangle);
        int filled=(Width-12)*value/100;
        using(var b=new SolidBrush(ColorTranslator.FromHtml("#8dc8b4")))e.Graphics.FillRectangle(b,6,6,filled,Height-12);
        using(var b=new SolidBrush(ColorTranslator.FromHtml("#659d8d")))for(int x=18;x<6+filled;x+=14)e.Graphics.FillRectangle(b,x,6,2,Height-12);
        using(var p=new Pen(ColorTranslator.FromHtml("#9a9a94"),2))e.Graphics.DrawRectangle(p,1,1,Width-2,Height-2);
    }
}

class SetupWindow : Form {
    readonly Color paper=ColorTranslator.FromHtml("#efe6cf"), teal=ColorTranslator.FromHtml("#8dc8b4"), panel=ColorTranslator.FromHtml("#1b2230");
    readonly Image scene=Core.Art("archive.png"), character=Core.Art("characters.png");
    readonly Panel content=new Panel();
    CheckBox desktop,menu,launch;TextBox path;Button start;PixelProgress bar;Label task,percent;
    string target=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","Afterself");
    bool desktopOpt=true,menuOpt=true,launchOpt=true,busy=false,finished=false;CancellationTokenSource cancellation;
    readonly string qa;bool progressCaptured=false;
    internal SetupWindow(string qaPath) {
        qa=qaPath;Text="AFTERSELF · 启动阶段安装程序";ClientSize=new Size(960,640);FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;
        AutoScaleMode=AutoScaleMode.None;DoubleBuffered=true;BackColor=panel;ForeColor=paper;Font=new Font("Microsoft YaHei UI",12,FontStyle.Regular,GraphicsUnit.Pixel);
        using(var s=Core.Resource("icon.ico")) Icon=new Icon(s);
        content.SetBounds(88,245,784,318);content.BackColor=panel;Controls.Add(content);
        FormClosing+=(s,e)=> { if(busy) { e.Cancel=true;if(MessageBox.Show(this,"取消安装并清理本次写入的文件？","先合上这份案卷？",MessageBoxButtons.YesNo,MessageBoxIcon.Question)==DialogResult.Yes) cancellation.Cancel(); }};
        Welcome();if(qa!=null) Shown+=async(s,e)=>await TestRun();
    }
    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);var g=e.Graphics;g.InterpolationMode=InterpolationMode.NearestNeighbor;g.PixelOffsetMode=PixelOffsetMode.Half;
        using(var low=new Bitmap(320,180)) { using(var lg=Graphics.FromImage(low)) {lg.InterpolationMode=InterpolationMode.NearestNeighbor;lg.DrawImage(scene,0,0,320,180);}g.DrawImage(low,new Rectangle(0,0,960,640)); }
        using(var brush=new SolidBrush(Color.FromArgb(160,14,20,32)))g.FillRectangle(brush,0,0,960,640);
        using(var brush=new SolidBrush(panel))g.FillRectangle(brush,52,183,856,417);
        using(var pen=new Pen(ColorTranslator.FromHtml("#9a9a94"),4))g.DrawRectangle(pen,52,183,856,417);
        using(var pen=new Pen(ColorTranslator.FromHtml("#3c4656")))g.DrawRectangle(pen,60,191,840,401);
        TextRenderer.DrawText(g,"第七码头 · 档案室",Font,new Point(56,45),ColorTranslator.FromHtml("#a4a9b6"));
        using(var font=new Font("Consolas",17,FontStyle.Regular,GraphicsUnit.Pixel))TextRenderer.DrawText(g,"AFTERSELF",font,new Point(760,45),teal);
        TextRenderer.DrawText(g,"第一章 / 睡过头的人",Font,new Point(236,204),teal);
        using(var font=new Font("Consolas",12,FontStyle.Regular,GraphicsUnit.Pixel))TextRenderer.DrawText(g,"FIRST BUILD   0.10.0",font,new Point(718,204),paper);
        using(var art=new Bitmap(48,52)) {
            using(var a=Graphics.FromImage(art)) {a.InterpolationMode=InterpolationMode.NearestNeighbor;a.PixelOffsetMode=PixelOffsetMode.Half;
                using(var body=new Bitmap(20,40)) {using(var b=Graphics.FromImage(body)){b.InterpolationMode=InterpolationMode.NearestNeighbor;b.DrawImage(character,new Rectangle(0,0,20,40),new Rectangle(79,125,250,564),GraphicsUnit.Pixel);}
                    var palette=new[]{"171f27","2b383e","405958","69817b","e9dbb2","d9a56c","efc58d","a67650","4e3749","775568","6b704b","324360","506581","70532c","ab843e","623638","985442","37333c","555057","959085"}.Select(c=>ColorTranslator.FromHtml("#"+c)).ToArray();
                    for(int y=0;y<40;y++)for(int x=0;x<20;x++){var p=body.GetPixel(x,y);body.SetPixel(x,y,palette.OrderBy(c=>(c.R-p.R)*(c.R-p.R)+(c.G-p.G)*(c.G-p.G)+(c.B-p.B)*(c.B-p.B)).First());}a.DrawImageUnscaled(body,14,0);
                }
                Fill(a,9,24,7,13,"2b383e");Fill(a,9,32,9,6,"405958");Fill(a,8,36,11,3,"e9dbb2");Fill(a,9,39,10,4,"efc58d");
                Fill(a,32,25,8,13,"405958");Fill(a,32,36,11,3,"e9dbb2");Fill(a,33,39,10,4,"efc58d");
                if(busy || finished){Fill(a,26,28,12,17,"171f27");Fill(a,27,29,10,15,"ab843e");Fill(a,30,32,6,1,"e9dbb2");Fill(a,33,38,9,4,"efc58d");}
            }g.DrawImage(art,new Rectangle(78,82,144,156));
        }
        TextRenderer.DrawText(g,busy?"先别替记录下结论。":finished?"笔记本带上了。":"先听当事人怎么说。",Font,new Point(226,137),paper);
        using(var font=new Font("Consolas",12,FontStyle.Regular,GraphicsUnit.Pixel))TextRenderer.DrawText(g,"WINDOWS x64   /   OFFLINE",font,new Point(56,615),ColorTranslator.FromHtml("#a4a9b6"));
    }
    void Fill(Graphics g,int x,int y,int w,int h,string hex){using(var b=new SolidBrush(ColorTranslator.FromHtml("#"+hex)))g.FillRectangle(b,x,y,w,h);}
    Label Label(string text,int x,int y,int w,int h,float size) {var c=new Label{Text=text,ForeColor=paper,Font=new Font("Microsoft YaHei UI",size*1.25f,FontStyle.Regular,GraphicsUnit.Pixel),BackColor=panel,AutoEllipsis=true};c.SetBounds(x,y,w,h);content.Controls.Add(c);return c;}
    Button Button(string text,int x,int y,int w,Action click,bool primary=false) {var c=new Button{Text=text,FlatStyle=FlatStyle.Flat,BackColor=primary?teal:ColorTranslator.FromHtml("#273141"),ForeColor=primary?panel:paper,Cursor=Cursors.Hand};c.FlatAppearance.BorderColor=ColorTranslator.FromHtml("#9a9a94");c.SetBounds(x,y,w,44);c.Click+=(s,e)=>click();content.Controls.Add(c);return c;}
    CheckBox Check(string text,int x,int y,int w,bool value){var c=new CheckBox{Text=text,Checked=value,ForeColor=paper,BackColor=panel};c.SetBounds(x,y,w,28);content.Controls.Add(c);return c;}
    void ShowNotice() {
        using(var dialog=new Form{Text="AFTERSELF · 试玩说明与第三方许可",ClientSize=new Size(760,550),StartPosition=FormStartPosition.CenterParent,BackColor=panel,ForeColor=paper,Font=Font,MinimizeBox=false,MaximizeBox=false}) {
            var tabs=new TabControl{Dock=DockStyle.Fill};
            var labels=new[]{"试玩说明","Godot 许可","Godot 第三方","字体许可"};var resources=new[]{"notice.txt","GODOT-LICENSE.txt","GODOT-THIRD-PARTY.txt","FONT-LICENSES.txt"};
            for(int i=0;i<labels.Length;i++) {var page=new TabPage(labels[i]);page.Controls.Add(new TextBox{Text=Core.Text(resources[i]).Replace("\r\n","\n").Replace("\n","\r\n"),ReadOnly=true,Multiline=true,ScrollBars=ScrollBars.Vertical,Dock=DockStyle.Fill,BackColor=panel,ForeColor=paper,Font=new Font("Microsoft YaHei UI",14,FontStyle.Regular,GraphicsUnit.Pixel)});tabs.TabPages.Add(page);}
            var close=new Button{Text="关闭",Dock=DockStyle.Bottom,Height=40};close.Click+=(s,e)=>dialog.Close();dialog.Controls.Add(tabs);dialog.Controls.Add(close);
            if(qa!=null)dialog.Shown+=(s,e)=>dialog.BeginInvoke((Action)(()=>{dialog.Update();using(var image=new Bitmap(dialog.Width,dialog.Height)){dialog.DrawToBitmap(image,new Rectangle(0,0,dialog.Width,dialog.Height));image.Save(Path.Combine(qa,"05-notice.png"));}dialog.Close();}));
            dialog.ShowDialog(this);
        }
    }
    void Clear(){foreach(Control c in content.Controls.Cast<Control>().ToArray())c.Dispose();content.Controls.Clear();}
    void Welcome() {
        Clear();finished=false;Invalidate();Label("AFTERSELF · 启动阶段",0,0,700,42,22);
        Label("清晨，一位居民来报案。\n她的丈夫睡过了三天，却坚称自己只睡了一晚。",0,51,770,60,12);
        Label("从眼前的人查起，把原话记下来。\n六章一周目 · 49 件证物 · 现场操作与人物档案",0,125,740,50,10);
        Label("Windows x64    版本 "+Core.Release.version+"    游戏文件 "+(Core.Release.installed_bytes/1048576.0).ToString("F1")+" MiB",0,191,760,24,9);
        Label("安装目录："+target,0,220,776,35,9);
        var consent=Check("已阅读试玩说明及第三方许可",0,274,320,false);
        Button("查看说明",333,266,103,ShowNotice);
        Button("高级选项",454,266,124,Advanced);
        start=Button("开始安装  →",604,266,176,()=>{var ignored=StartInstall(false);},true);start.Enabled=false;consent.CheckedChanged+=(s,e)=>start.Enabled=consent.Checked;
    }
    void Advanced() {
        Clear();Label("把调查工具放在哪里？",0,0,760,42,20);Label("请选择空目录。无需管理员权限，存档单独保存。",0,53,760,28,10);
        path=new TextBox{Text=target,BackColor=ColorTranslator.FromHtml("#101722"),ForeColor=paper,BorderStyle=BorderStyle.FixedSingle};path.SetBounds(0,94,620,32);content.Controls.Add(path);
        Button("浏览…",639,87,140,()=>{using(var d=new FolderBrowserDialog{Description="选择安装目录（可创建新文件夹）",SelectedPath=target})if(d.ShowDialog(this)==DialogResult.OK)path.Text=d.SelectedPath;});
        desktop=Check("创建桌面快捷方式",0,151,370,desktopOpt);menu=Check("创建开始菜单快捷方式",0,187,370,menuOpt);launch=Check("完成后启动游戏",0,223,370,launchOpt);
        Button("返回",454,266,124,Welcome);Button("保存选项",604,266,176,()=>{try{Core.Validate(path.Text,true);target=Path.GetFullPath(path.Text).TrimEnd('\\');desktopOpt=desktop.Checked;menuOpt=menu.Checked;launchOpt=launch.Checked;Welcome();}catch(Exception ex){MessageBox.Show(this,ex.Message,"检查安装路径");}},true);
    }
    async Task<Installed> StartInstall(bool test) {
        busy=true;cancellation=new CancellationTokenSource();Clear();Invalidate();Label("准备这一次调查",0,0,760,42,22);
        task=Label("检查安装目录",0,62,640,28,11);percent=Label("0%",687,55,90,40,20);
        bar=new PixelProgress();bar.SetBounds(0,111,779,28);content.Controls.Add(bar);
        Label("进度按实际写入字节更新；每个文件核对 SHA-256。",0,163,760,26,9);Label("安装目录："+target,0,217,779,35,9);
        Button("取消安装",604,266,176,()=>cancellation.Cancel());
        try {
            var installed=await Task.Run(()=>Core.Install(target,desktopOpt,menuOpt,test,(value,text)=>{
                if(cancellation.IsCancellationRequested) return;
                BeginInvoke((Action)(()=>{if(!busy || bar==null || bar.IsDisposed)return;bar.Value=value;percent.Text=value+"%";task.Text=text;if(test && value>=10 && !progressCaptured){progressCaptured=true;CapturePreview("03-installing.png");}}));
            },cancellation.Token));
            busy=false;finished=true;Finish(installed);return installed;
        } catch(Exception ex) {busy=false;if(!test)MessageBox.Show(this,ex is OperationCanceledException?"已取消，清理了本次安装写入的文件。":ex.Message,"安装未完成");Welcome();if(test)throw;return null;}
    }
    void Finish(Installed installed) {
        Clear();Invalidate();Label("笔记本带上了。",0,0,760,42,22);Label("现场已经准备好。\n从眼前的人查起，把原话记下来。",0,53,760,61,12);
        Label("已安装 "+(installed.bytes/1048576.0).ToString("F1")+" MiB · 文件校验全部通过\n"+(desktopOpt?"也可以稍后从桌面快捷方式打开游戏。":"也可以稍后从安装目录打开游戏。"),0,137,760,60,10);
        Label("安装目录："+target,0,215,779,36,9);var auto=Check("关闭安装器时启动游戏",0,271,318,launchOpt);
        Button("打开目录",454,266,124,()=>System.Diagnostics.Process.Start("explorer.exe",target));
        Button("完成  →",604,266,176,()=>{try{if(auto.Checked)System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(Path.Combine(target,"StartupPhase.exe")){WorkingDirectory=target});Close();}catch(Exception ex){MessageBox.Show(this,"安装已经完成，但游戏未能启动：\n"+ex.Message+"\n可以稍后从安装目录打开游戏。","游戏未启动");}},true);
    }
    void CapturePreview(string name){if(qa==null)return;Update();using(var b=new Bitmap(Width,Height)){DrawToBitmap(b,new Rectangle(0,0,Width,Height));b.Save(Path.Combine(qa,name));}}
    async Task TestRun() {
        var checks=new List<string>();try {
            Directory.CreateDirectory(qa);target=Path.Combine(qa,"installed");launchOpt=false;Welcome();CapturePreview("01-welcome.png");Advanced();CapturePreview("02-advanced.png");Welcome();
            if(start.Enabled)throw new Exception("install button enabled before reading acknowledgement");
            var consent=content.Controls.OfType<CheckBox>().Single();consent.Checked=true;if(!start.Enabled)throw new Exception("install button not enabled by acknowledgement");consent.Checked=false;checks.Add("reading acknowledgement gates install button");
            foreach(var resource in new[]{"GODOT-LICENSE.txt","GODOT-THIRD-PARTY.txt","FONT-LICENSES.txt"})if(Core.Text(resource).Length<100)throw new Exception("missing pre-install license text");checks.Add("all third-party licenses readable before install");
            ShowNotice();
            var existing=Path.Combine(qa,"existing");Directory.CreateDirectory(existing);File.WriteAllText(Path.Combine(existing,"keep.txt"),"keep");
            try{Core.Validate(existing,true);throw new Exception("non-empty target unexpectedly accepted");}catch(IOException){checks.Add("non-empty directory rejected");}
            try{Core.Validate(Path.GetPathRoot(qa),true);throw new Exception("drive root unexpectedly accepted");}catch(IOException){checks.Add("drive root rejected");}
            var cancelTarget=Path.Combine(qa,"cancelled");var cts=new CancellationTokenSource();bool cancelled=false;
            try{await Task.Run(()=>Core.Install(cancelTarget,false,false,true,(p,t)=>{if(p>=10)cts.Cancel();},cts.Token));}catch(OperationCanceledException){cancelled=true;}
            if(!cancelled || Directory.Exists(cancelTarget))throw new Exception("cancelled installation not rolled back");checks.Add("cancellation removes only newly written files");
            var result=await StartInstall(true);CapturePreview("04-finish.png");
            foreach(var f in Core.Release.files)if(Core.Hash(Path.Combine(target,f.name))!=f.sha256)throw new Exception("installed hash mismatch "+f.name);
            checks.Add("all installed payload hashes match");
            if(result.shortcuts.Length!=2 || result.shortcuts.Any(p=>!Core.IsOurShortcut(p,target)))throw new Exception("shortcut target mismatch");checks.Add("desktop and start menu shortcut target verified in isolated folders");
            // A changed receipt must be rejected before deleting any payload.
            var receiptPath=Path.Combine(target,Core.ReceiptName);var receiptText=File.ReadAllText(receiptPath,Encoding.UTF8);
            var damaged=Core.Json.Deserialize<Receipt>(receiptText);damaged.files[0].sha256=new string('0',64);File.WriteAllText(receiptPath,Core.Json.Serialize(damaged),Encoding.UTF8);
            using(var process=System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(Path.Combine(target,"Uninstall.exe"),"--test-uninstall"){UseShellExecute=false,CreateNoWindow=true})){await Task.Run(()=>process.WaitForExit());if(process.ExitCode!=1 || Core.Hash(Path.Combine(target,"StartupPhase.exe"))!=Core.Release.files[0].sha256)throw new Exception("tampered receipt deleted payload");}
            File.WriteAllText(receiptPath,receiptText,new UTF8Encoding(false));checks.Add("tampered uninstall receipt rejected before deletion");
            File.WriteAllText(Path.Combine(target,"player-note.txt"),"must survive uninstall");
            // Changed managed files must also survive uninstall.
            File.AppendAllText(Path.Combine(target,"开始前请读.txt"),"\nQA modified file");
            using(var process=System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(Path.Combine(target,"Uninstall.exe"),"--test-uninstall"){UseShellExecute=false,CreateNoWindow=true})) {await Task.Run(()=>process.WaitForExit());if(process.ExitCode!=0)throw new Exception("uninstall failed");}
            await Task.Delay(3500);
            if(File.Exists(Path.Combine(target,"StartupPhase.exe")) || result.shortcuts.Any(File.Exists) || File.Exists(Path.Combine(target,"Uninstall.exe")))throw new Exception("uninstall left owned files");
            if(!File.Exists(Path.Combine(target,"player-note.txt")) || !File.ReadAllText(Path.Combine(target,"开始前请读.txt")).Contains("QA modified file") || File.ReadAllText(Path.Combine(existing,"keep.txt"))!="keep")throw new Exception("uninstall lost preserved data");checks.Add("uninstall removes owned files and retains modified and unrelated files");
            File.WriteAllText(Path.Combine(qa,"installer-results.json"),Core.Json.Serialize(new{passed=true,checks=checks,installed_bytes=result.bytes,installer_sha256=Core.Hash(Assembly.GetExecutingAssembly().Location),registry_live_tested=false}),Encoding.UTF8);Environment.ExitCode=0;
        }catch(Exception ex){File.WriteAllText(Path.Combine(qa,"installer-results.json"),Core.Json.Serialize(new{passed=false,error=ex.ToString(),checks=checks}),Encoding.UTF8);Environment.ExitCode=1;}Close();
    }
}

static class Program {
    [STAThread] static int Main(string[] args) {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        // QA installs deliberately spawn their own isolated uninstaller.
        if(args.Length==2 && args[0]=="--test-install")return Run(args);
        using(var gate=new Mutex(false,"Local\\Afterself.StartupPhase.Setup")) {
            bool acquired=false;try {try{acquired=gate.WaitOne(0);}catch(AbandonedMutexException){acquired=true;}
                if(!acquired){if(!args.Contains("--test-uninstall"))MessageBox.Show("另一份 AFTERSELF 安装或卸载程序正在运行，请先关闭它。","程序已在运行");return 1;}
                return Run(args);
            }finally{if(acquired)gate.ReleaseMutex();}
        }
    }
    static int Run(string[] args) {
        bool uninstall=String.Equals(Path.GetFileName(Assembly.GetExecutingAssembly().Location),"Uninstall.exe",StringComparison.OrdinalIgnoreCase);
        if(uninstall) {bool test=args.Contains("--test-uninstall");try {
            if(!test && MessageBox.Show("卸载 AFTERSELF · 启动阶段？\n存档保留；已修改的文件和自行添加的文件也保留。","卸载",MessageBoxButtons.YesNo,MessageBoxIcon.Question)!=DialogResult.Yes)return 0;
            var preserved=Core.Uninstall(test);if(!test)MessageBox.Show("卸载完成。存档仍在 %APPDATA%\\StartupPhase。"+(preserved.Length>0?"\n保留了已修改的文件："+String.Join("、",preserved):""),"AFTERSELF");return 0;
        }catch(Exception ex){if(!test)MessageBox.Show(ex.Message,"卸载未完成");return 1;}}
        string qa=args.Length==2 && args[0]=="--test-install"?Path.GetFullPath(args[1]):null;
        Application.Run(new SetupWindow(qa));return Environment.ExitCode;
    }
}
