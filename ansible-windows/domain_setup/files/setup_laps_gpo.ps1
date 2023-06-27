param($Identity)

$ErrorActionPreference = 'Stop'
$Ansible.Changed = $false

$gpo = Get-Gpo -Name LAPS -ErrorAction SilentlyContinue
if (-not $gpo) {
    $Ansible.Changed = $true
    $gpo = New-GPO -Name LAPS
    $null = $Identity | ForEach-Object {
        $ou = Get-ADOrganizationalUnit -LDAPFilter "(ou=$_)"
        $gpo | New-GPLink -Target $ou.DistinguishedName -LinkEnabled Yes -Enforced Yes
    }
}

$key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\LAPS'
$values = @{
    ADPasswordEncryptionEnabled = 1
    BackupDirectory = 2
    PasswordComplexity = 4
    PasswordLength = 14
    PasswordAgeDays = 30
}
foreach ($reg in $values.GetEnumerator()) {
    $existing = $gpo | Get-GPRegistryValue -Key $key -ValueName $reg.Key -ErrorAction SilentlyContinue
    if (-not $existing -or $existing.Value -ne $reg.Value) {
        $null = $gpo | Set-GPRegistryValue -Key $key -ValueName $reg.Key -Value $reg.Value -Type DWord
        $Ansible.Changed = $true
    }
}
