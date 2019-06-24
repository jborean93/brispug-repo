$shell = New-Object -ComObject Shell.Application
try {
    # https://docs.microsoft.com/en-us/windows/desktop/shell/shell-shellexecute
    # Executable
    # Arguments
    # WorkingDirectory
    # Verb
    # Windows Style
    $shell.ShellExecute("C:\Windows\system.ini", "", "", "print", 1)
} finally {
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
}
