# Start a process in the background
Start-Process -FilePath cmd.exe

# Show that output is not capture automaticlaly
Start-Process -FilePath whoami.exe

# Start a process in the current console window
Start-Process -FilePath whoami.exe -NoNewWindow

# Show that even though the process is run in the current window we cannot capture output
$out = Start-Process -FilePath whoami.exe -NoNewWindow
$null -eq $out

# Start a process as another user
$cred = Get-Credential
Start-Process -FilePath powershell.exe -ArgumentList 'whoami.exe; Start-Sleep -Second 5' -Credential $cred

# Start a process and wait for it to finish
Start-Process -FilePath powershell.exe -ArgumentList 'Start-Sleep -Seconds 5' -Wait

# Start a process and redirect stdout/stderr to a file
$temp_path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.IO.Path]::GetRandomFileName())
New-Item -Path $temp_path -ItemType Directory > $null
try {
    $stdout_file = Join-Path -Path $temp_path -ChildPath 'stdout'
    $stderr_file = Join-Path -Path $temp_path -ChildPath 'stderr'
    $proc_args = '$host.UI.WriteLine(''stdout''); $host.UI.WriteErrorLine(''stderr'')'
    Start-Process -FilePath powershell.exe -ArgumentList $proc_args -RedirectStandardError $stderr_file -RedirectStandardOutput $stdout_file
    $stdout = Get-Content -LiteralPath $stdout_file
    $stderr = Get-Content -LiteralPath $stderr_file
} finally {
    Remove-Item -LiteralPath $temp_path -Force -Recurse
}

# Get exit code
$res = Start-Process -FilePath powershell.exe -ArgumentList 'exit 1' -PassThru -Wait
$res.ExitCode

# Start the current process as an admin by using the Runas verb
Start-Process -FilePath ([System.Diagnostics.Process]::GetCurrentProcess().Path) -Verb Runas
