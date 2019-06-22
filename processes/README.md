# PowerShell Starting Processes

This contains some scripts that demonstrate the various ways to start a
new process in PowerShell. Also talks about argument escaping rules.

# Requirements

* PowerShell on Windows
* The [PrintArgv.exe](https://ansible-ci-files.s3.amazonaws.com/test/integration/roles/test_win_module_utils/PrintArgv.exe) application

The PrintArgv.exe application is just a compile .NET program of;

```
using System;

namespace PrintArgv
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine(string.Join(System.Environment.NewLine, args));
        }
    }
}
```

It's designed to print each argument to a new process on a new line to easily
identify the argument parsing rules.


# Ways to start a new process

Each topic is a way to start a new process in PowerShell with its advantages
and disadvantages.

## Direct Calls

Simplest way to call another executable, just call the executable inline or use
the call operator `&` if you need to provider a path with a space or as a
variable. See [call_operator.ps1](call_operator.ps1) for some demos.

### Advantages

* Simple
* Covers most use cases

### Disadvantages

* Return codes that are not 0 are treated as an error
* Stderr is sent to the error stream by default
* Cannot run asynchronously, need to wait until the process has finished


## Start-Process

A PowerShell cmdlet that is designed to start processes. Unless you want to
capture the stdout/stderr in a variable this is the best option to use. It's
quite flexible in the scenarios it supports and even supports the `Verb` syntax
when starting new processes that only the `ShellExecute` COM call supports. See
[Start-Process.ps1](Start-Process.ps1) for some demos.

### Advantages

Offers quite a bit of flexibility can;

* Run processes in the background (default)
* Run processes and wait for it to complete (`-Wait`)
* Redirect stdout/stderr to a file
* Run a process with a verb, e.g. `runas`, `edit`, `print`
* Control window behaviour of the starting process
* Doesn't fail on an error code that is not `0`
* Can run the process as another user

### Disadvantages

* Requires temp files if you wish to capture stdout/stderr as a variable
* Honestly not much else unless you need to use some low level features like custom process creation flags


## System.Diagnostics.Process

This is the .NET [System.Diagnostics.Process](https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.process?view=netframework-4.8)
class that is used by `Start-Process`. See [System.Diagnostics.Process.ps1](System.Diagnostics.Process.ps1)
for some demos.

### Advantages

* Same as `Start-Process` but with some more flexibility to redirect stdout/stderr to a variable

### Disadvantages

* Just more code that you need to write, a lot simpler to just call `Start-Process` instead

## COM - ShellExecute

Uses COM to call the [ShellExecute](https://docs.microsoft.com/en-us/windows/desktop/shell/shell-shellexecute)
to start a new process. I've never had a reason to really use this and I tend
to avoid COM wherever I can. In saying that see [ShellExecute.ps1](ShellExecute.ps1)
for some demos.

### Advantages

* You can run a process with a verb, still `Start-Process` and `System.Diagnostics.Process` can also do this

### Disadvanates

* It's COM
* Doesn't offer many options to control the behaviour of the new process
* It's COM.... again


## Win32_Process Create

Uses the [Create](https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/create-method-in-class-win32-process)
method of the WMI class [Win32_Process](https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/win32-process)
to start a new process. See [Win32_Process.Create.ps1](Win32_Process.Create.ps1)
for some demos.

### Advantages

* Gives you really fine control over the new process and can define
    * The console window size
    * The title of the new console window
    * Specify process creation flags for some low level control
* Because the process is spawned by WMI it can breakaway from the parent process and continue running once the parent has been killed
* Can be invoked over the network without having WinRM setup

### Disadvantages

* You cannot redirect the stdout/stderr streams without using files
* Doesn't offer the flexibility to specify shell verb operations
* Reliant on WMI to up and running


## PInvoke CreateProcess

We are now getting into the low level stuff. I've put the demo for these in the
one file [CreateProcess.ps1](CreateProcess.ps1) as they share common code.

Through PInvoke you can call the following functions:

* [CreateProcess](https://docs.microsoft.com/en-us/windows/desktop/api/processthreadsapi/nf-processthreadsapi-createprocessw) - Standard call to create a new process
* [CreateProcessWithLogon](https://docs.microsoft.com/en-us/windows/desktop/api/winbase/nf-winbase-createprocesswithlogonw) - Create a new process in the security context of another user
* [CreateProcessWithToken](https://docs.microsoft.com/en-us/windows/desktop/api/winbase/nf-winbase-createprocesswithtokenw) - Create a new process in the security context of an access token
* [CreateProcessAsUser](https://docs.microsoft.com/en-us/windows/desktop/api/processthreadsapi/nf-processthreadsapi-createprocessasusera) - Like `CreateProcessWithToken` but requires different privileges

### Advantages

* Base layer in Win32 when creating a new process pretty much full control over how the process that is created
* Can define a custom security descriptor for the new process object
* Can have a [custom process thread attribute list](https://docs.microsoft.com/en-us/windows/desktop/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute) to define even more low level details of the process
* Redirection can be done to wherever you want (file/pipe/var)
* Can run a process as another user, including the `SYSTEM` account

### Disadvantages

* Requires PInvoke definitions
* On top of the above, these functions are quite complex and not easy to implement correctly


## PInvoke NtCreateUserProcess

You thought we were done here? No you can go even further and create a new
process with `NtCreateUserProcess`. This is undocumented and exported by
`ntdll.dll` which contains the Windows Native API and is not dependent on the
Win32 subsystem. There shouldn't be any reason that you would need to use this
unless you were really curious how Windows ticks. I don't have any examples
because this is undocumented and have never had a reason to try it out. It
would require some PInvoke definitions just like the `CreateProcess*` calls
above but would be even more complex.
