# See the below for the rules around argument escaping
# https://docs.microsoft.com/en-us/previous-versions//17w5ykft(v=vs.85)
# https://blogs.msdn.microsoft.com/twistylittlepassagesallalike/2011/04/23/everyone-quotes-command-line-arguments-the-wrong-way/

Add-Type -TypeDefinition @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Runtime.ConstrainedExecution;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace CreateProcess
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public class SECURITY_ATTRIBUTES
        {
            public UInt32 nLength;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle = false;
            public SECURITY_ATTRIBUTES()
            {
                nLength = (UInt32)Marshal.SizeOf(this);
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public class STARTUPINFOEX
        {
            public StartupInfo StartupInfo;
            public IntPtr lpAttributeList;
            public STARTUPINFOEX(StartupInfo s)
            {
                StartupInfo = s;
                StartupInfo.cb = (UInt32)Marshal.SizeOf(this);
            }
        }
    }

    internal class NativeMethods
    {
        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(
            IntPtr pObject);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool CreatePipe(
            out SafeFileHandle hReadPipe,
            out SafeFileHandle hWritePipe,
            NativeHelpers.SECURITY_ATTRIBUTES lpPipeAttributes,
            UInt32 nSize);

        [DllImport("Kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CreateProcessW(
            [MarshalAs(UnmanagedType.LPWStr)] string lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandles,
            ProcessCreationFlags dwCreationFlags,
            SafeMemoryBuffer lpEnvironment,
            [MarshalAs(UnmanagedType.LPWStr)] string lpCurrentDirectory,
            NativeHelpers.STARTUPINFOEX lpStartupInfo,
            out ProcessInformation lpProcessInformation);

        [DllImport("Kernel32.dll")]
        public static extern void DeleteProcThreadAttributeList(
            IntPtr lpAttributeList);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool GetExitCodeProcess(
            SafeWaitHandle hProcess,
            out UInt32 lpExitCode);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool InitializeProcThreadAttributeList(
            IntPtr lpAttributeList,
            UInt32 dwAttributeCount,
            UInt32 dwFlags,
            ref UIntPtr lpSize);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern SafeNativeHandle OpenProcess(
            ProcessAccessFlags dwDesiredAccess,
            bool bInheritHandle,
            UInt32 dwProcessId);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool SetHandleInformation(
            SafeFileHandle hObject,
            HandleFlags dwMask,
            HandleFlags dwFlags);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool UpdateProcThreadAttribute(
            IntPtr lpAttributeList,
            UInt32 dwFlags,
            IntPtr Attribute,
            IntPtr lpValue,
            IntPtr cbSize,
            IntPtr lpPreviousValue,
            IntPtr lpReturnSize);

        [DllImport("Kernel32.dll")]
        public static extern UInt32 WaitForSingleObject(
            SafeWaitHandle hHandle,
            UInt32 dwMilliseconds);
    }

    internal class SafeMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMemoryBuffer() : base(true) { }
        public SafeMemoryBuffer(int cb) : base(true)
        {
            base.SetHandle(Marshal.AllocHGlobal(cb));
        }
        public SafeMemoryBuffer(IntPtr handle) : base(true)
        {
            base.SetHandle(handle);
        }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            Marshal.FreeHGlobal(handle);
            return true;
        }
    }

    internal class SafeProcThreadAttrList : SafeHandleZeroOrMinusOneIsInvalid
    {
        private bool _initialised = false;
        private List<IntPtr> _attrValues = new List<IntPtr>();

        public SafeProcThreadAttrList(IDictionary attributes) : base(true)
        {
            if (attributes == null)
                attributes = new Hashtable();

            UIntPtr lpSize = UIntPtr.Zero;
            if (NativeMethods.InitializeProcThreadAttributeList(IntPtr.Zero, (UInt32)attributes.Count, 0, ref lpSize))
                throw new Win32Exception("Failed to get ProcThreadAttributeList buffer size");

            handle = Marshal.AllocHGlobal((int)lpSize.ToUInt32());
            try
            {
                if (!NativeMethods.InitializeProcThreadAttributeList(handle, (UInt32)attributes.Count, 0, ref lpSize))
                    throw new Win32Exception("Failed to initialise ProcThreadAttributeList");
                _initialised = true;

                // TODO: Support more than just IntPtr attribute values.
                foreach (DictionaryEntry attr in attributes)
                {
                    IntPtr val = Marshal.AllocHGlobal(IntPtr.Size);
                    _attrValues.Add(val);
                    IntPtr attrKey = new IntPtr((UInt32)attr.Key);

                    Marshal.WriteIntPtr(val, (IntPtr)attr.Value);

                    if (!NativeMethods.UpdateProcThreadAttribute(handle, 0,  attrKey, val,
                        (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                    {
                        throw new Win32Exception("Failed to update ProcThreadAttribute list");
                    }
                }
            }
            catch
            {
                // In case of an issue when initialising the list we need to release anything we created.
                ReleaseHandle();
                throw;
            }
        }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            if (handle == IntPtr.Zero)
                return true;

            if (_initialised)
                NativeMethods.DeleteProcThreadAttributeList(handle);

            foreach (IntPtr val in _attrValues)
                if (val != IntPtr.Zero)
                    Marshal.FreeHGlobal(val);

            Marshal.FreeHGlobal(handle);
            return true;
        }
    }

    public class SafeNativeHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeNativeHandle() : base(true) { }
        public SafeNativeHandle(IntPtr handle) : base(true) { this.handle = handle; }

        public static implicit operator IntPtr(SafeNativeHandle h) { return h.DangerousGetHandle(); }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            return NativeMethods.CloseHandle(handle);
        }
    }

    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _msg;

        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _msg = String.Format("{0}: {1} (Win32 ErrorCode {2} - 0x{2:X8})", message, base.Message, errorCode);
        }

        public override string Message { get { return _msg; } }
        public static explicit operator Win32Exception(string message) { return new Win32Exception(message); }
    }

    [Flags]
    public enum HandleFlags : uint
    {
        None = 0,
        Inherit = 1
    }

    [Flags]
    public enum ProcessAccessFlags : uint
    {
        Terminate = 0x00000001,
        CreateThread = 0x00000002,
        VmOperation = 0x00000008,
        VmRead = 0x00000010,
        VmWrite = 0x00000020,
        DupHandle = 0x00000040,
        CreateProcess = 0x00000080,
        SetQuota = 0x00000100,
        SetInformation = 0x00000200,
        QueryInformation = 0x00000400,
        SuspendResume = 0x00000800,
        QueryLimitedInformation = 0x00001000,
        Delete = 0x00010000,
        ReadControl = 0x00020000,
        WriteDac = 0x00040000,
        WriteOwner = 0x00080000,
        Synchronize = 0x00100000,
    }

    [Flags]
    public enum ProcessCreationFlags : uint
    {
        DebugProcess = 0x00000001,
        DebugOnlyThisProcess = 0x00000002,
        Suspended = 0x00000004,
        DetachedProcess = 0x00000008,
        NewConsole = 0x00000010,
        NormalPriorityClass = 0x00000020,
        IdlePriorityClass = 0x00000040,
        HighPriorityclass = 0x00000080,
        RealtimePriorityClass = 0x00000100,
        NewProcessGroup = 0x00000200,
        UnicodeEnvironment = 0x00000400,
        SeparateWowVdm = 0x00000800,
        SharedWowVdm = 0x00001000,
        ForceDos = 0x00002000,
        BelowNormalPriorityClass = 0x00004000,
        AboveNormalPriorityClass = 0x00008000,
        InheritParentAffinity = 0x00010000,
        InheritCallerPriority = 0x00020000,
        ProtectedProcess = 0x00040000,
        ExtendedStartupInfoPresent = 0x00080000,
        ProcessModeBackgroundBegin = 0x00100000,
        ProcessModeBackgroundEnd = 0x00200000,
        SecureProcess = 0x00400000,
        BreakawayFromJob = 0x01000000,
        PreserveCodeAuthzLevel = 0x02000000,
        DefaultErrorMode = 0x04000000,
        NoWindow = 0x08000000,
        ProfileUser = 0x10000000,
        ProfileKernel = 0x20000000,
        ProfileServer = 0x40000000,
        IgnoreSystemDefault = 0x80000000,
    }

    [Flags]
    public enum ProcessThreadAttribute : uint
    {
        ParentProcess = 0x00020000,
        HandleList = 0x00020002,
        GroupAffinity = 0x00030003,
        PreferredNode = 0x00020004,
        IdealProcessor = 0x00030005,
        UmsThread = 0x00030006,
        MitigationPolicy = 0x00020007,
        SecurityCapabilities = 0x00020009,
        ProtectionLevel = 0x0002000B,
        JobList = 0x0002000D,
        ChildProcessPolicy = 0x0002000E,
        AllApplicationPackagesPolicy = 0x0002000F,
        Win32kFilter = 0x00020010,
        DesktopAppPolicy = 0x00020012,
        PsuedoConsole = 0x00020016,
    }

    [Flags]
    public enum StartupInfoFlags : uint
    {
        UseShowWindow = 0x00000001,
        UseSize = 0x00000002,
        UsePosition = 0x00000004,
        UseCountChars = 0x00000008,
        UseFullAttribute = 0x00000010,
        RunFullScreen = 0x00000020,
        ForeOnFeedback = 0x00000040,
        ForceOffFeedback = 0x00000080,
        UseStdHandles = 0x00000100,
        UseHotkey = 0x00000200,
        TitleIsLinkName = 0x00000800,
        TitleIsAppId = 0x00001000,
        PreventPinning = 0x00002000,
        UntrustedSource = 0x00008000,
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct ProcessInformation
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public int dwProcessId;
        public int dwThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    public class StartupInfo
    {
        public UInt32 cb;
        public IntPtr lpReserved;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpDesktop;
        [MarshalAs(UnmanagedType.LPWStr)] public string lpTitle;
        public UInt32 dwX;
        public UInt32 dwY;
        public UInt32 dwXSize;
        public UInt32 dwYSize;
        public UInt32 dwXCountChars;
        public UInt32 dwYCountChars;
        public UInt32 dwFillAttribute;
        public StartupInfoFlags dwFlags;
        public UInt16 wShowWindow;
        public UInt16 cbReserved2;
        public IntPtr lpReserved2;
        public SafeFileHandle hStdInput;
        public SafeFileHandle hStdOutput;
        public SafeFileHandle hStdError;

        public StartupInfo()
        {
            cb = (UInt32)Marshal.SizeOf(this);
            hStdInput = new SafeFileHandle(IntPtr.Zero, false);
            hStdOutput = new SafeFileHandle(IntPtr.Zero, false);
            hStdError = new SafeFileHandle(IntPtr.Zero, false);
        }
    }

    public class ProcessUtil
    {
        public static void CreatePipe(out SafeFileHandle hReadPipe, out SafeFileHandle hWritePipe, bool bInheritHandle, UInt32 nSize)
        {
            NativeHelpers.SECURITY_ATTRIBUTES pipeSec = new NativeHelpers.SECURITY_ATTRIBUTES();
            pipeSec.bInheritHandle = bInheritHandle;

            if (!NativeMethods.CreatePipe(out hReadPipe, out hWritePipe, pipeSec, nSize))
                throw new Win32Exception("Failed to create anonymous pipe");
        }

        public static ProcessInformation CreateProcess(string lpApplicationName, string lpCommandLine,
            IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles,
            ProcessCreationFlags dwCreationFlags, IDictionary environment, string lpCurrentDirectory,
            StartupInfo lpStartupInfo, IDictionary attributeList)
        {
            if (lpApplicationName == "")
                lpApplicationName = null;

            // CreateProcess can modify the lpCommandLine parameter so we need to use a StringBUilder.
            StringBuilder commandLine = new StringBuilder(lpCommandLine);

            dwCreationFlags |= ProcessCreationFlags.UnicodeEnvironment;
            using (SafeMemoryBuffer lpEnvironment = CreateEnvironmentPointer(environment))
            using (SafeProcThreadAttrList procThreadAttrList = new SafeProcThreadAttrList(attributeList))
            {
                if (lpCurrentDirectory == "")
                    lpCurrentDirectory = null;

                NativeHelpers.STARTUPINFOEX si = new NativeHelpers.STARTUPINFOEX(lpStartupInfo);
                si.lpAttributeList = procThreadAttrList.DangerousGetHandle();
                dwCreationFlags |= ProcessCreationFlags.ExtendedStartupInfoPresent;

                ProcessInformation pi = new ProcessInformation();
                if (!NativeMethods.CreateProcessW(lpApplicationName, commandLine, lpProcessAttributes,
                    lpThreadAttributes, bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, si,
                    out pi))
                {
                    throw new Win32Exception("CreateProcessW() failed");
                }

                return pi;
            }
        }

        public static UInt32 GetExitCodeProcess(IntPtr hProcess)
        {
            SafeWaitHandle waitHandle = new SafeWaitHandle(hProcess, true);
            UInt32 res = NativeMethods.WaitForSingleObject(waitHandle, 0xFFFFFFFF);
            if (res != 0)
                throw new Win32Exception((int)res, "Failed to wait for process completion");

            UInt32 rc = 0;
            if (!NativeMethods.GetExitCodeProcess(waitHandle, out rc))
                throw new Win32Exception("Failed to get process exit code");

            return rc;
        }

        public static void GetProcessOutput(StreamReader stdoutStream, StreamReader stderrStream, out string stdout, out string stderr)
        {
            var sowait = new EventWaitHandle(false, EventResetMode.ManualReset);
            var sewait = new EventWaitHandle(false, EventResetMode.ManualReset);
            string so = null, se = null;
            ThreadPool.QueueUserWorkItem((s) =>
            {
                so = stdoutStream.ReadToEnd();
                sowait.Set();
            });
            ThreadPool.QueueUserWorkItem((s) =>
            {
                se = stderrStream.ReadToEnd();
                sewait.Set();
            });
            foreach (var wh in new WaitHandle[] { sowait, sewait })
                wh.WaitOne();
            stdout = so;
            stderr = se;
        }

        public static SafeNativeHandle OpenProcess(ProcessAccessFlags dwDesiredAccess, bool bInheritHandle, UInt32 dwProcessId)
        {
            SafeNativeHandle pHandle = NativeMethods.OpenProcess(dwDesiredAccess, bInheritHandle, dwProcessId);
            int errCode = Marshal.GetLastWin32Error();

            if (pHandle.IsInvalid)
            {
                throw new Win32Exception(errCode, String.Format("Failed to open process {0}", dwProcessId));
            }

            return pHandle;
        }

        public static void SetHandleInformation(SafeFileHandle hObject, HandleFlags dwMask, HandleFlags dwFlags)
        {
            if (!NativeMethods.SetHandleInformation(hObject, dwMask, dwFlags))
                throw new Win32Exception("Failed to set handle information");
        }

        internal static SafeMemoryBuffer CreateEnvironmentPointer(IDictionary environment)
        {
            IntPtr lpEnvironment = IntPtr.Zero;
            if (environment != null)
            {
                StringBuilder environmentString = new StringBuilder();
                foreach (DictionaryEntry kv in environment)
                    environmentString.AppendFormat("{0}={1}\0", kv.Key, kv.Value);
                environmentString.Append('\0');

                lpEnvironment = Marshal.StringToHGlobalUni(environmentString.ToString());
            }
            return new SafeMemoryBuffer(lpEnvironment);
        }
    }
}
'@
Function Get-Argv {
    Param (
        [System.String]
        $Argument
    )

    # https://ansible-ci-files.s3.amazonaws.com/test/integration/roles/test_win_module_utils/PrintArgv.exe
    $file_path = "C:\temp\PrintArgv.exe"
    $command_line = "$file_path $Argument"

    $stdout_read, $stdout_write = $null
    [CreateProcess.ProcessUtil]::CreatePipe([ref]$stdout_read, [ref]$stdout_write, $true, 0)
    [CreateProcess.ProcessUtil]::SetHandleInformation($stdout_read, 'Inherit', 0)

    $stderr_read, $stderr_write = $null
    [CreateProcess.ProcessUtil]::CreatePipe([ref]$stderr_read, [ref]$stderr_write, $true, 0)
    [CreateProcess.ProcessUtil]::SetHandleInformation($stderr_read, 'Inherit', 0)

    $si = New-Object -TypeName CreateProcess.StartupInfo
    $si.dwFlags = [CreateProcess.StartupInfoFlags]::UseStdHandles
    $si.hStdOutput = $stdout_write
    $si.hStdError = $stderr_write

    $proc = [CreateProcess.ProcessUtil]::CreateProcess(
        $exe,
        $command_line,
        [System.IntPtr]::Zero,
        [System.IntPtr]::Zero,
        $true,
        0,
        $null,
        $null,
        $si,
        $null
    )

    $stdout_write.Close()
    $stderr_write.Close()

    $utf8_encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

    $stdout_fs = New-Object -TypeName System.IO.FileStream -ArgumentList $stdout_read, 'Read', 4096
    $stdout_sr = New-Object -TypeName System.IO.StreamReader -ArgumentList $stdout_fs, $utf8_encoding, $true, 4096

    $stderr_fs = New-Object -TypeName System.IO.FileStream -ArgumentList $stderr_read, 'Read', 4096
    $stderr_sr = New-Object -TypeName System.IO.StreamReader -ArgumentList $stderr_fs, $utf8_encoding, $true, 4096

    $stdout, $stderr = $null
    [CreateProcess.ProcessUtil]::GetProcessOutput($stdout_sr, $stderr_sr, [ref]$stdout, [ref]$stderr)
    [CreateProcess.ProcessUtil]::GetExitCodeProcess($proc.hProcess) > $null

    return ,$stdout.TrimEnd("`r`n") -split "`r`n"
}

Describe 'single argument with no spaces' {
    It 'Passes proper string' {
        $expected = @(
            'arg1'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'multiple arguments with no spaces' {
    It 'Passes proper string' {
        $expected = @(
            'arg1',
            'arg2'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'Tests argument with \' {
    It 'Passes proper string' {
        $expected = @(
            'arg\1',
            'arg\2'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'Tests argument with special chars' {
    It 'Passes proper string' {
        $expected = @(
            'carrot^',
            'and&',
            'single-quote''',
            'exclamation!'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'Arguments with space' {
    It 'Passes proper string' {
        $expected = @(
            'Argument with spaces',
            'Another argument with space'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'Arguments with embeded "' {
    It 'Passes proper string' {
        $expected = @(
            '"Quoted"',
            '"Quoted with space"'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}

Describe 'Arguments with \" and spaces' {
    It 'Passes proper string' {
        $expected = @(
            '{"key": "Value \"quoted\""}'
        )
        $actual = Get-Argv -Argument ''
        $actual | Should -Be $expected
    }
}
