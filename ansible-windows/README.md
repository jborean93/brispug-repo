# Ansible Windows + AD Example

This is a demo for using Ansible to build an Active Directory environment and how to interact with it.
It is designed to run on Windows so uses Vagrant + Hyper-V to build the VMs needed for Ansible.
To build the environment run:

```bash
vagrant.exe up
vagrant.exe ssh LINUX01
```

This will enter an interactive session on the Linux host built by Vagrant which has Ansible installed.
To setup the domain environment run:

```bash
cd ~/domain_setup
ansible-playbook main.yml -v
```

_Note: The LAPS stuff requires a new Windows image to be functional, either update it manually before kicking off or remove the tasks to configure it._

Once complete a new domain environment has been made and Ansible can then configure it how it pleases.
The demo for this will show you how to use the [microsoft.ad.ldap](https://docs.ansible.com/ansible/latest/collections/microsoft/ad/ldap_inventory.html) inventory plugin to build the Ansible inventory from Active Directory and will use that inventory to setup a MS SQL Server instance.

```bash
cd ~/demo

# Get the kerberos ticket for the domain user
kinit vagrant-domain@BRISPUG.TEST

# Show the hosts found by the inventory
ansible-inventory -i microsoft.ad.ldap.yml --list --yaml

# Install SQL Server and SQL Management Studio
ansible-playbook main.yml -v
```
