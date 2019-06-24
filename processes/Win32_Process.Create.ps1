# https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/win32-processstartup
$psi_props = @{
    Title = 'My Title'
}
$psi = New-CimInstance -ClassName Win32_ProcessStartup -Property $psi_props -Local

# https://docs.microsoft.com/en-us/windows/desktop/CIMWin32Prov/create-method-in-class-win32-process
$proc_args = @{
    CommandLine = 'powershell.exe'
    # CurrentDirectory = ''
    ProcessStartupInformation = $psi
}
$proc = Invoke-CimMethod -ClassName Win32_Process -Name Create -Arguments $proc_args

if ($proc.ReturnValue -ne 0) {
    $error_msg = switch($rc) {
        2 { "Access denied" }
        3 { "Insufficient privilege" }
        8 { "Unknown failure" }
        9 { "Path not found" }
        21 { "Invalid parameter" }
        default { "Other" }
    }
    throw "Failed to start async process: $rc ($error_msg)"
}

# No way of getting output, just the PID. If you wish to redirect the stdout/stderr then you need to use a shell to do
# this for you.
$proc.ProcessId
