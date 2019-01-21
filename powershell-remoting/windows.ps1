Function New-JEAConfiguration {
    [CmdletBinding()]
    Param (
        [string]$Name,
        [string]$Role
    )

    $module_path = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsPowerShell\Modules\$Name"
    if (-not (Test-Path -Path $module_path)) {
        New-Item -Path $module_path -ItemType Directory
    }

    $functions_path = Join-Path -Path $module_path -ChildPath "$($Name)Functions.psm1"
    if (-not (Test-Path -Path $functions_path)) {
        New-Item -Path $functions_path -ItemType File
    }

    $manifest_path = Join-Path -Path $module_path -ChildPath "$($Name).psd1"
    if (-not (Test-Path -Path $manifest_path)) {
        New-ModuleManifest -Path $manifest_path -RootModule "$($Name)Functions.psm1"
    }

    $role_path = Join-Path -Path $module_path -ChildPath "RoleCapabilities"
    if (-not (Test-Path -Path $role_path)) {
        New-Item -Path $role_path -ItemType Directory
    }

    $jea_role_path = Join-Path -Path $role_path -ChildPath "$($Name).psrc"
    Set-Content -Path $jea_role_path -Value $Role
}

$ErrorActionPreference = "Stop"

# Setup up WinRM Client to allow connecting to linux
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Set-Item -Path WSMan:\localhost\Client\AllowUnencrypted -Value True

# Setup standrd local user
$sec_pass = ConvertTo-SecureString -String "Password01" -AsPlainText -Force
$user = New-LocalUser -Name standard `
    -Password $sec_pass `
    -Description "Standard account for JEA" `
    -AccountNeverExpires `
    -PasswordNeverExpires
Add-LocalGroupMember -Group Users -Member $user
Add-LocalGroupMember -Group "Remote Management Users" -Member $user

# Install PSCore
choco.exe install -y powershell-core --install-arguments="ENABLEPSREMOTING=1" --no-progress
Set-Location -Path "$env:ProgramFiles\PowerShell\6"
&.\pwsh.exe -File Install-PowerShellRemoting.ps1 -PowerShellHome .
Pop-Location

# Setup PSCore SSH subsystem
cmd.exe /c mklink /D C:\pwsh "$env:ProgramFiles\PowerShell\6"
$sshd_config_path = "$env:ProgramData\ssh\sshd_config"
$sshd_config = Get-Content -Path $sshd_config_path | Where-Object {
    # Remove wacky shared SSH key for admins config, WTF MS
    $_ -notmatch "Match Group administrators" -and
    $_ -notmatch "AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
}
$sshd_config += "Subsystem    powershell    C:\pwsh\pwsh.exe -sshs -NoLogo -NoProfile"
Set-Content -Path $sshd_config_path -Value $sshd_config

# Setup local .ssh folder
$ssh_folder = Join-Path -Path $env:HOMEPATH -ChildPath ".ssh"
if (-not (Test-Path -Path $ssh_folder)) {
    New-Item -Path $ssh_folder -ItemType Directory > $null
}
Move-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath id_rsa) -Destination $ssh_folder
Move-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath id_rsa.pub) `
    -Destination (Join-Path -Path $ssh_folder -ChildPath "authorized_keys")

# Register 2 JEA roles
$jea_role1 = @'
@{
    GUID = '5396a896-531a-487c-b743-899a20780e57'
    Author = 'Jordan Borean'
    CompanyName = 'N/A'
    Copyright = '(c) 2019 Jordan Borean. All rights reserved.'
    VisibleExternalCommands = 'C:\Windows\System32\whoami.exe'
}
'@
$jea_settings1 = @'
@{
    SchemaVersion = '2.0.0.0'
    GUID = 'b9ec66f3-0068-401e-9cbb-031158af4fa8'
    Author = 'Jordan Borean'
    SessionType = 'RestrictedRemoteServer'
    RunAsVirtualAccount = $true
    RoleDefinitions = @{
        'BUILTIN\Administrators' = @{ RoleCapabilities = 'JEARole1' }
    }
}
'@
$jea_settings1_path = [System.IO.Path]::GetTempFileName()
$jea_settings1_path = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName() + ".pssc")
try {
    Set-Content -Path $jea_settings1_path -Value $jea_settings1
    New-JEAConfiguration -Name JEARole1 -Role $jea_role1 > $null
    Register-PSSessionConfiguration -Path $jea_settings1_path -Name JEARole1 -Force
} finally {
    Remove-Item -Path $jea_settings1_path -Force
}

$jea_role2 = @'
@{
    GUID = '5396a896-531a-487c-b743-899a20780e58'
    Author = 'Jordan Borean'
    CompanyName = 'N/A'
    Copyright = '(c) 2019 Jordan Borean. All rights reserved.'
    VisibleExternalCommands = 'C:\Windows\System32\whoami.exe'
}
'@
$jea_settings2 = @'
@{
    SchemaVersion = '2.0.0.0'
    GUID = '8927811f-6f5a-4b64-a420-cf237c861559'
    Author = 'Jordan Borean'
    SessionType = 'RestrictedRemoteServer'
    RoleDefinitions = @{
        'BUILTIN\Administrators' = @{ RoleCapabilities = 'JEARole2' }
    }
}
'@
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList "standard", $sec_pass
$jea_settings2_path = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName() + ".pssc")
try {
    Set-Content -Path $jea_settings2_path -Value $jea_settings2
    New-JEAConfiguration -Name JEARole2 -Role $jea_role2 > $null
    Register-PSSessionConfiguration -Path $jea_settings2_path -Name JEARole2 -Force -RunAsCredential $cred
} finally {
    Remove-Item -Path $jea_settings2_path -Force
}

Restart-Service -Name sshd
