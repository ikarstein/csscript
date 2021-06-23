$script = $args[0]

$params = $args | select -Skip 1


$csscriptPath = Split-Path $MyInvocation.MyCommand.Path

$script="c:\source2\csscript\test\test\program.cs" 
#$script="c:\source2\csscript\ikfbatool\Program.cs" 
$debug=$true

$script = (new-object System.IO.FileInfo($script)).FullName

cls

if( !(Test-Path $script -PathType Leaf) ) {
	Write-Host "SCRIPT NOT FOUND!"
	exit -1
}

$referenceFiles = @();
$referenceNames = @();

$scriptContent = Get-Content $script


$xml = "";
foreach($l in $scriptContent) {
	if( !([string]::IsNullOrEmpty($l.Trim())) -and $l -notlike "//*" ) { break }
	
	if( $l -notlike "////*") {
		if( !([string]::IsNullOrEmpty($l.Trim())) ) {
			$xml += $l.remove(0,2)
		}
	}
}

$config = $null
try {
	$config = [xml]$xml
} catch {
	$config = $null
}

if( $config -eq $null ) {
	Write-Host "CONFIG XML AT THE BEGINNING OF THE C# FILE IS INVALID OR MISSING!"
	exit -1
}

$referenceAssembies = @()
$referenceAssembies+="System.dll";

$config.csscript.references.reference | % {
	$p = $_
	$n = $null
	try {
		$n = [System.Reflection.AssemblyName]::GetAssemblyName($p)
	} catch {
		$n = $null
	}
	
	if( $n -eq $null ) {
		if( $p -notlike "*.dll") {
			$p += ".dll"
		}
	} else {
		$p = $n.ToString()
	}
	
	if( ($referenceAssembies | ? { $_ -eq $p} ) -eq $null ) {
		$referenceAssembies += $p
	}
}

if( $config.csscript.frameworkversion -ne $null ) {
	$runtime = $config.csscript.frameworkversion
}

if( [string]::IsNullOrEmpty($runtime) ) {
	$runtime = "3.5"
}

$platform = "anycpu"
if( $config.csscript.targetplatform -ne $null ) {
	$platform = $config.csscript.targetplatform
	if( $platform -ne "anycpu" -and $platform -ne "x86" -and $platform -ne "x64" ) {
		Write-Host "UNKNOWN ""PLATFORM"" IN CONFIG XML INSIDE C# FILE."
		exit -1
	}
}

if( [string]::IsNullOrEmpty($platform)  ) { $platform = "anycpu" }

$noconsole = $false
if( $config.csscript.mode -ne $null) {
	$n = $config.csscript.mode
	if( $n -ne "exe" -and $n -ne "winexe" ) {
		Write-Host "UNKNOWN ""MODE"" IN CONFIG XML INSIDE C# FILE."
	}
	$noconsole = $n -eq "winexe"
}

$debug = ( $config.csscript.debug -ne $null) 

$type = ('System.Collections.Generic.Dictionary`2') -as "Type"
$type = $type.MakeGenericType( @( ("System.String" -as "Type"), ("system.string" -as "Type") ) )
$o = [Activator]::CreateInstance($type)

if( $runtime -notlike "v*") { $runtime = "v$($runtime)" }
$o.Add("CompilerVersion", $runtime)

$cop = (new-object Microsoft.CSharp.CSharpCodeProvider($o))
$cp = New-Object System.CodeDom.Compiler.CompilerParameters($referenceAssembies, $outputFile)
$cp.GenerateInMemory = $true
$cp.GenerateExecutable = $false
$cp.CompilerOptions = "/platform:$($platform) /target:$( if($noConsole){'winexe'}else{'exe'})"
$cp.IncludeDebugInformation = $debug

if( $debug ) {
	#$cp.TempFiles.TempDir = (split-path $inputFile)
	$cp.TempFiles.KeepFiles = $true
}	

$files = @()
$files += [string]::Join("`n", $scriptContent)

try {
	Push-Location
	
	Set-Location (Split-Path $script)
	[System.Environment]::CurrentDirectory = Get-Location
	
	if( $config.csscript.files.file -ne $null ) {
		$config.csscript.files.file | % {
			$p = $_
			$p = (new-object System.IO.FileInfo($p)).FullName

			if( Test-Path $p -PathType Leaf ) {
				$files += [System.IO.File]::ReadAllText($p)
			}
		}
	}
} finally {
	Pop-Location
	[System.Environment]::CurrentDirectory = Get-Location
}


$cr = $cop.CompileAssemblyFromSource($cp, [String[]]$files)
if( $cr.Errors.Count -gt 0 ) {
	$cr.Errors
	exit -1
}

$ts = $cr.CompiledAssembly.GetTypes()
$m = $ts | % { 
	$t = $_
	$ms = $t.GetMethods("Nonpublic, Static, InvokeMethod, Public, IgnoreCase")
	$ms | ? { $_.Name -eq "Main" } | % {
		$mx = $_	
		if ($mx.ReturnType.Name -eq "Void" -or $mx.ReturnType.Name -like "System.Int*" ) {
			$p = $mx.GetParameters()
			if( $p.Count -eq 1 -and $p.Get(0).ParameterType.Name -like "*String[[]]" ) {
				$mx
			}
			if( $p -eq $null -or $p.Count -eq 0 ) {
				$mx
			}
		}
	}
}

$p = @($null)

$sb = New-Object System.Text.StringBuilder
$w = new-object System.IO.StringWriter($sb)

[System.Console]::SetOut($w)


#$job = Start-Job -ScriptBlock {
#	param( [System.Text.StringBuilder] $sb, [System.IO.StringWriter]$w, [System.Reflection.MethodInfo]$m, [Object[]]$p ) 
#	
#	[System.Console]::SetOut($w)
#
#	$m.Invoke($null, [Object[]]$p)
#} -ArgumentList $sb, $w, $m, $p


$name1 = "mem$([Guid]::NewGuid().ToString("n"))"
$name2 = "cls$([Guid]::NewGuid().ToString("n"))"

$referenceAssembies = @("System.dll", "$($Host.GetType().Assembly.Location)")
$cp2 = New-Object System.CodeDom.Compiler.CompilerParameters($referenceAssembies, $outputFile)
$cp2.GenerateInMemory = $true
$cp2.GenerateExecutable = $false
$cp2.IncludeDebugInformation = $debug
$cp2.TempFiles.KeepFiles = $true

Remove-Variable "crErrOut" -Force -Confirm:$false -ErrorAction 0

try {
Add-Type -CompilerParameters $cp2 -Language CSharp -ErrorAction SilentlyContinue -ErrorVariable "crErrOut" -TypeDefinition @"
	using System;
	using System.Threading;
	using System.Text;
	using System.Management.Automation.Runspaces;
	
	public class $name2
	{
		public System.Reflection.MethodInfo method;
		public string[] prms;
		public ManualResetEvent mre = null;
		public Thread thread = null;
		public System.Management.Automation.Runspaces.Runspace runspace = null;
		
		public void Start(System.Reflection.MethodInfo method, string[] prms, System.Management.Automation.Runspaces.Runspace r) 
		{   
			$(if($debug) {"System.Diagnostics.Debugger.Launch();System.Diagnostics.Debugger.Break();"})
			this.method = method;
			this.prms = (prms == null ? new string[]{} : prms);
			this.runspace = r;
			
			mre = new ManualResetEvent(false);
			
			this.thread = new Thread($name2.DoWork);
			thread.Start(this);
		}
		
		public static void DoWork(object data)
	    {
	        $name2 obj = ($name2)data;

			System.Management.Automation.Runspaces.Runspace.DefaultRunspace = obj.runspace;
			
			obj.method.Invoke(null, new System.Object[]{ obj.prms});
			obj.mre.Set();
	    }
		
		public void Stop() 
		{
			if(thread != null ) {
				thread.Abort();
				mre.Set();
				thread = null;
			}
		}
	}	
	
	public class $($name2)ConsoleInput : System.IO.TextReader 
	{
	    public event EventHandler<ConsoleInputEventArgs> ReadOneCharEvent;
        public event EventHandler<ConsoleInputEventArgs> ReadBlockEvent;
        public event EventHandler<ConsoleInputEventArgs> ReadLineEvent;
        public event EventHandler<ConsoleInputEventArgs> ReadToEndEvent;
		
		public class ConsoleInputEventArgs : EventArgs
	    {
	        public int ReadInt { get; set; }
			public string ReadString { get; set; }
			
			public int ReadCount {get; private set;}
			
	        public ConsoleInputEventArgs()
	        {
				this.ReadCount = -1;
				this.ReadString = null;
				this.ReadInt = -1;
	        }

			public ConsoleInputEventArgs(int readCount)
	        {
				this.ReadInt = -1;
				this.ReadCount = readCount;
				this.ReadString = null;
	        }
		}
		
		public override int Read()
		{
			if (ReadOneCharEvent != null) 
			{
				ConsoleInputEventArgs evt = new ConsoleInputEventArgs();
				ReadOneCharEvent(this, evt);
				return evt.ReadInt;
			}
			
			return -1;
		}

		public override int Read(char[] buffer, int index, int count)
		{
			if (buffer == null)
			{
				throw new ArgumentNullException("buffer", "Argument 'buffer' is null.");
			}
			if (index < 0)
			{
				throw new ArgumentOutOfRangeException("index", "Argument 'index' is negative.");
			}
			if (count < 0)
			{
				throw new ArgumentOutOfRangeException("count", "Argument 'count' is negative.");
			}
			if (buffer.Length - index < count)
			{
				throw new ArgumentException("'buffer' too small.");
			}
			
			if (ReadBlockEvent != null) 
			{
				ConsoleInputEventArgs evt = new ConsoleInputEventArgs(count);
				
				ReadBlockEvent(this, evt);
				
				if( evt.ReadString == null )
					return -1;
				
				string s = evt.ReadString;
				int num = 0;
				do
				{
					char chr = s[0];
					buffer[index + num++] = chr;
				}
				while (num < s.Length);
				
				return num;
			}
			
			return -1;
		}
		
		public override string ReadToEnd()
		{
			if (ReadToEndEvent != null) 
			{
				ConsoleInputEventArgs evt = new ConsoleInputEventArgs(int.MaxValue);
				
				ReadToEndEvent(this, evt);
				
				return evt.ReadString;
			}

			return null;
		}
		
		
		public override int ReadBlock(char[] buffer, int index, int count)
		{
			int num = 0;
			int num2;
			do
			{
				num += (num2 = this.Read(buffer, index + num, count - num));
			}
			while (num2 > 0 && num < count);
			return num;
		}
		
		
		public override string ReadLine()
		{
			if (ReadLineEvent != null) 
			{
				ConsoleInputEventArgs evt = new ConsoleInputEventArgs(int.MaxValue);
				
				ReadLineEvent(this, evt);
				
				return evt.ReadString;
			}

			return null;
		}
	}
	
	
	public class $($name2)ConsoleOutput : System.IO.TextWriter 
	{
		public bool IsErrorReceiver = false;

        public event EventHandler<ConsoleOutputEventArgs> WriteEvent;
        public event EventHandler<ConsoleOutputEventArgs> WriteLineEvent;
		
		//public delegate void WriteEvent(string value, bool isError);
		//public delegate void WriteLineEvent(bool isError);
		
		//public WriteEvent InternalWriteDelegate {get; set;}
		//public WriteLineEvent InternalWriteLineDelegate {get; set;}

		//http://stackoverflow.com/questions/11911660/redirect-console-writeline-from-windows-application-to-a-string
		public class ConsoleOutputEventArgs : EventArgs
	    {
	        public string Value { get; private set; }
			public bool IsError { get; private set; }
			
	        public ConsoleOutputEventArgs(string value, bool isError)
	        {
	            Value = value;
				IsError = isError;
	        }
	    }

        public override System.Text.Encoding Encoding { get { return System.Text.Encoding.UTF8; } }
		
		public void InternalWrite(string value)
		{
            if (WriteEvent != null) WriteEvent(this, new ConsoleOutputEventArgs(value, IsErrorReceiver));
			//if( InternalWriteDelegate != null ) InternalWriteDelegate(value, IsErrorReceiver);
		}
		
		public void InternalWriteLine()
		{
            if (WriteLineEvent != null) WriteLineEvent(this, new ConsoleOutputEventArgs("", IsErrorReceiver));
			//if( InternalWriteLineDelegate != null ) InternalWriteLineDelegate(IsErrorReceiver);
		}

        public override void Write(char value)
		{
            string s = String.Empty;
            s += value;   
			InternalWrite(s);
			//base.Write(value);
		}
		
		public override void Write(char[] buffer)
		{
            StringBuilder sb = new StringBuilder(buffer.Length);
            sb.Append(buffer);
			InternalWrite(sb.ToString());
			//base.Write(value);
		}

		public override void Write(char[] buffer, int index, int count)
		{
            StringBuilder sb = new StringBuilder(count);
            sb.Append(buffer, index, count);
			InternalWrite(sb.ToString());
			//base.Write(value);
		}

		public override void Write(bool value)
		{
			InternalWrite(value ? "True" : "False");
			//base.Write(value);
		}

		public override void Write(int value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(uint value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(long value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(ulong value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(float value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(double value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(decimal value)
		{
			InternalWrite(value.ToString(this.FormatProvider));
			//base.Write(value);
		}

		public override void Write(string value)
		{
			InternalWrite(value);
			//base.Write(value);
		}

		public override void Write(object value)
		{
			if (value != null)
			{
				IFormattable formattable = value as IFormattable;
				if (formattable != null)
				{
					this.InternalWrite(formattable.ToString(null, this.FormatProvider));
					//base.Write(value);
					return;
				}
				this.InternalWrite(value.ToString());
			}
			//base.Write(value);
		}

		public override void Write(string format, object arg0)
		{
			this.InternalWrite(string.Format(this.FormatProvider, format, new object[]
			{
				arg0
			}));
			//base.Write(format,arg0);
		}

		public override void Write(string format, object arg0, object arg1)
		{
			this.InternalWrite(string.Format(this.FormatProvider, format, new object[]
			{
				arg0,
				arg1
			}));
			//base.Write(format, arg0, arg1);
		}

		public override void Write(string format, object arg0, object arg1, object arg2)
		{
			this.InternalWrite(string.Format(this.FormatProvider, format, new object[]
			{
				arg0,
				arg1,
				arg2
			}));
			//base.Write(format, arg0, arg1, arg2);
		}

		public override void Write(string format, params object[] arg)
		{
			this.Write(string.Format(this.FormatProvider, format, arg));
			//base.Write(format, arg);
		}

		public override void WriteLine()
		{
			InternalWriteLine();
			//base.WriteLine();
		}

		public override void WriteLine(char value)
		{
			this.Write(value);
			InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(char[] buffer)
		{
			this.Write(buffer);
			InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(char[] buffer, int index, int count)
		{
			this.Write(buffer, index, count);
			InternalWriteLine();
			//base.WriteLine(buffer, index, count);
		}

		public override void WriteLine(bool value)
		{
			this.Write(value);
			InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(int value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(uint value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(long value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(ulong value)
		{
			this.Write(value);
			InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(float value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(double value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(decimal value)
		{
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(string value)
		{
			if (value == null)
			{
                InternalWriteLine();
				//base.WriteLine(value);
				return;
			}
			
			this.Write(value);
            InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(object value)
		{
			if (value == null)
			{
				InternalWriteLine();
				//base.WriteLine(value);
				return;
			}
			
			this.Write(value);
			InternalWriteLine();
			//base.WriteLine(value);
		}

		public override void WriteLine(string format, object arg0)
		{
			this.WriteLine(string.Format(this.FormatProvider, format, new object[]
			{
				arg0
			}));
		}

		public override void WriteLine(string format, object arg0, object arg1)
		{
			this.WriteLine(string.Format(this.FormatProvider, format, new object[]
			{
				arg0,
				arg1
			}));
		}

		public override void WriteLine(string format, object arg0, object arg1, object arg2)
		{
			this.WriteLine(string.Format(this.FormatProvider, format, new object[]
			{
				arg0,
				arg1,
				arg2
			}));
		}

		public override void WriteLine(string format, params object[] arg)
		{
			this.WriteLine(string.Format(this.FormatProvider, format, arg));
		}
	}		
"@
} catch {}

#stop if compilation of helper class failed
if( $crErrOut -ne $null  ){
	Write-Host "CANNOT COMPILE HELPER CLASS."
	exit -1
}



#helper object for worker thread
$o = Invoke-Expression "new-object ""$name2"""

#console input/output objects 
$stdOut = Invoke-Expression "new-object ""$($name2)ConsoleOutput"""

$errOut = Invoke-Expression "new-object ""$($name2)ConsoleOutput"""
$errOut.IsErrorReceiver = $true

$stdIn = Invoke-Expression "new-object ""$($name2)ConsoleInput"""

#register console input/output objects
[System.Console]::SetOut($stdOut)
[System.Console]::SetError($errOut)
[System.Console]::SetIn($stdIn)

# event handler for console input and output
$stdOut.add_WriteEvent( {
	param($sender, $parameter)

	write-host "$($parameter.Value)" -NoNewline 
});

$stdOut.add_WriteLineEvent( {
	param($sender, $parameter)
	write-host ""
});

$errOut.add_WriteEvent( {
	param($sender, $parameter)

	Write-Error "$($parameter.Value)"
});

$errOut.add_WriteLineEvent( { 
	param($sender, $parameter)
});

$stdIn.add_ReadBlockEvent( {
	param($sender, $parameter)
})

$stdIn.add_ReadLineEvent( {
	param($sender, $parameter)
	
	$parameter.ReadString = (Get-Date -Format "yyyy.MM.dd")
})

$stdIn.add_ReadOneCharEvent( {
	param($sender, $parameter)
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	$parameter.ReadInt = [int]($x)
	Write-Host [int]$x
})

$stdIn.add_ReadToEndEvent( {
	param($sender, $parameter)
})

try {
	$o.Start($m, [Object[]]$params, $host.Runspace)

	while( !($o.mre.WaitOne(100)) ) {
		#just wait...
	}
} finally {
	$o.Stop()
}