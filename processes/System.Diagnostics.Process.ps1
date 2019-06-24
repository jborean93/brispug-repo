# Run a process and capture stdout/stderr to car
$psi = New-Object -TypeName System.Diagnostics.ProcessStartInfo
$psi.UseShellExecute = $false  # Must be set to $false or else we cannot redirect stdout/stderr
$psi.RedirectStandardError = $true
$psi.RedirectStandardOutput = $true
$psi.FileName = 'powershell.exe'
$psi.Arguments = '$host.UI.WriteLine(''stdout''); $host.UI.WriteErrorLine(''stderr'')'

$stdout_sb = New-Object -TypeName System.Text.StringBuilder
$stderr_sb = New-Object -TypeName System.Text.StringBuilder

$proc = New-Object -TypeName System.Diagnostics.Process
$proc.StartInfo = $psi

# Register a delegate that is subscribed to the *DataReceived events and will add the output to our StringBuilders
$read_output = {
    if (-not [System.String]::IsNullOrEmpty($EventArgs.Data)) {
        $Event.MessageData.AppendLine($EventArgs.Data)
    }
}
$stdout_event = Register-ObjectEvent -InputObject $proc -Action $read_output -EventName 'OutputDataReceived' -MessageData $stdout_sb
$stderr_event = Register-ObjectEvent -InputObject $proc -Action $read_output -EventName 'ErrorDataReceived' -MessageData $stderr_sb

$proc.Start() > $null
$proc.BeginOutputReadLine()
$proc.BeginErrorReadLine()
$proc.WaitForExit()

Unregister-Event -SourceIdentifier $stdout_event.Name
Unregister-Event -SourceIdentifier $stderr_event.Name

$stdout = $stdout_sb.ToString()
$stderr = $stderr_sb.ToString()
