# Call process normally
whoami.exe

# Call process and save output
$out = whoami.exe
"Output: $out"

# Call process with call operator
&whoami.exe

# Call process with arguments
whoami.exe /priv

# Call arguments based on variables
$exe = "whoami.exe"
$arguments = @("/priv")
&$exe $arguments

# Call executable with a space in the path
$folder_with_space = Join-Path `
    -Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath('.') `
    -ChildPath 'folder space'

if (-not (Test-Path -LiteralPath $folder_with_space)) {
    New-Item -Path $folder_with_space -ItemType Directory > $null
}
try {
    $exe_path = Join-Path -Path $folder_with_space -ChildPath whoami.exe
    Copy-Item -Path "C:\Windows\System32\whoami.exe" -Destination $exe_path

    # No need to quote but you need to use the call operator
    &$exe_path
} finally {
    Remove-Item -LiteralPath $folder_with_space -Force -Recurse
}

# Call executable in current path with space in argument
.\PrintArgv.exe arg1 "arg 2"

# Call execute with space in argument using array literal
.\PrintArgv.exe @("arg1", "arg 2")

# Call executable that returns rc of 1
cmd.exe /c exit 1
"RC: $LASTEXITCODE"

# Echo to stderr - is automatically sent to the current console's stderr pipe
powershell.exe '$host.UI.WriteErrorLine(''stderr'')'
