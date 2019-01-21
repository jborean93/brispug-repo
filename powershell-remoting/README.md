# PowerShell Remoting Demo

This contains some scripts and info used for the PowerShell remoting demo.
There may be issues with this demo as it's just designed as a basic guideline.


## Requirements

* Vagrant
* VirtualBox or Hyper-V
* Internet connection


## How to Setup

Once you have satisfied the setup above you first need to generate an SSH
keypair that will be copied across to both machines. This can be done by
running `ssh-keygen -t rsa -b 4096 -f ./id_rsa`.

Once this is setup, create the 2 hosts by running `vagrant up`. This will
setup the Windows and linux box as well as copy each script and keypair across.
The linux host will be set up as part of the Vagrant initialisation but the
Windows host requires manual setup due to it's actions bringing down WinRM.
This can simply be done by running;

```
# Password is 'vagrant'
vagrant ssh windows
cd Documents
powershell.exe -File windows.ps1
exit
```

Now that the hosts are setup you can try out the demos below.


## Demos

### Linux to Windows over WinRM

This shows you how to connect to a Windows host from a Linux host over WinRM.
It requires explicit credentials to be set but the PSSession acts just like
normal. This supports Basic, NTLM, and Kerberos auth but Basic requires a HTTPS
endpoint to have an encrypted session.

```
pwsh
$cred = Get-Credential

# Connects to the Microsoft.PowerShell (PowerShell Desktop v5) configuration session
Enter-PSSession -ComputerName 192.168.56.50 -Credential $cred -Authentication Negotiate

# Connects to the PowerShell.5 (PowerShell Core v6) configuration session
Enter-PSSession -ComputerName 192.168.56.50 -Credential $cred -Authentication Negotiate -ConfigurationName PowerShell.6
```

### Linux to Windows over SSH

This shows you how to connect to a Windows host from a Linux host over SSH.
This will only be able to connect to a PowerShell Core instance on the remote
side and supports key authentication which has been set up already on both
hosts.

```
pwsh
Enter-PSSession -HostName vagrant@192.168.56.50
```

### Windows to Linux over WinRM

This isn't current working, need to investigate more, use SSH anyway.

```
# TODO: Fix this scenario
```

### Windows to Linux over SSH

You can connect to the linux host over SSH just like Linux -> Windows over SSH.

```
pwsh
Enter-PSSession -HostName vagrant@192.168.56.51
```

### JEA Example

This shows you how to connect to a JEA configured endpoint. Each endpoint only
allows you to run `whoami.exe` which shows how JEARole1 runs through a virtual
account and JEARole2 is run through the standard user account.

```
Enter-PSSession -ComputerName 192.168.56.50 -Credential $cred -ConfigurationName JEARole1 -Authentication Negotiate

Enter-PSSession -ComputerName 192.168.56.50 -Credential $cred -ConfigurationName JEARole2 -Authentication Negotiate
```
