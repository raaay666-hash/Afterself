using System;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Collections.Generic;
using System.Web.Script.Serialization;

// Exercises the actual compiled installer without touching desktop, HKCU, or player saves.
static class CoreRegression {
    [STAThread] static int Main(string[] args) {
        var exe=Path.GetFullPath(args[0]);var root=Path.GetFullPath(args[1]);Directory.CreateDirectory(root);
        var assembly=Assembly.LoadFile(exe);var core=assembly.GetType("Core");
        var validate=core.GetMethod("Validate",BindingFlags.NonPublic|BindingFlags.Static);
        var install=core.GetMethod("Install",BindingFlags.NonPublic|BindingFlags.Static);
        var checks=new List<object>();bool all=true;
        foreach(var path in new[]{"C:relative-install",@"\relative-root-install",@"C:\Games\folder:stream",@"C:\Games\Afterself. "}) {
            bool rejected=false;try{validate.Invoke(null,new object[]{path,true});}catch(TargetInvocationException){rejected=true;}
            checks.Add(new{test="invalid_path",input=path,passed=rejected});all&=rejected;
        }
        foreach(var phase in new[]{92,98}) {
            var target=Path.Combine(root,"collision-"+phase);string name=phase==92?"Uninstall.exe":"afterself-install.json";
            var sentinel=Path.Combine(target,name);string token="other writer owns this file";bool failed=false;
            Action<int,string> progress=(value,text)=>{if(value==phase)File.WriteAllText(sentinel,token);};
            try{install.Invoke(null,new object[]{target,false,false,true,progress,CancellationToken.None});}catch(TargetInvocationException){failed=true;}
            bool preserved=File.Exists(sentinel)&&File.ReadAllText(sentinel)==token;
            bool payloadCleaned=!File.Exists(Path.Combine(target,"StartupPhase.exe"));
            checks.Add(new{test="concurrent_file_collision",phase=phase,failed_as_expected=failed,sentinel_preserved=preserved,payload_cleaned=payloadCleaned,passed=failed&&preserved&&payloadCleaned});all&=failed&&preserved&&payloadCleaned;
        }
        var lockTarget=Path.Combine(root,"locked-rollback");FileStream held=null;string message="";
        try {
            Action<int,string> progress=(value,text)=>{if(value==92){held=new FileStream(Path.Combine(lockTarget,"Afterself.ico"),FileMode.Open,FileAccess.Read,FileShare.Read);throw new IOException("injected late failure");}};
            try{install.Invoke(null,new object[]{lockTarget,false,false,true,progress,CancellationToken.None});}catch(TargetInvocationException ex){message=ex.InnerException.Message;}
            bool passed=!File.Exists(Path.Combine(lockTarget,"StartupPhase.exe")) && File.Exists(Path.Combine(lockTarget,"Afterself.ico")) && message.Contains("Afterself.ico");
            checks.Add(new{test="locked_file_does_not_abort_remaining_rollback",passed=passed,error_message=message});all&=passed;
        }finally{if(held!=null)held.Dispose();}
        using(var gate=new Mutex(false,"Local\\Afterself.StartupPhase.Setup")) {
            bool acquired=false;try{try{acquired=gate.WaitOne(0);}catch(AbandonedMutexException){acquired=true;}
                if(!acquired)throw new IOException("another installer is already active during QA");
                using(var process=System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(exe,"--test-uninstall"){UseShellExecute=false,CreateNoWindow=true})) {
                    if(!process.WaitForExit(10000)){process.Kill();throw new IOException("concurrent installer did not reject entry");}
                    bool passed=process.ExitCode==1;checks.Add(new{test="concurrent_install_or_uninstall_rejected",passed=passed});all&=passed;
                }
            }finally{if(acquired)gate.ReleaseMutex();}
        }
        var json=new JavaScriptSerializer().Serialize(new{passed=all,executable=exe,checks=checks});File.WriteAllText(Path.Combine(root,"core-results.json"),json);
        Console.WriteLine(json);return all?0:1;
    }
}
