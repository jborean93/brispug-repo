# Ansible Demo

This demo will create a Windows virtual machine based on user input and it also has an example playbook of setting up an IIS website.

## Setup

To run this you need to do the following

* Install ansible `pip install ansible`
* Install pypsrp `pip install pypsrp`
* Install azure deps `pip install -r azure-requirements.txt`
* Install azure collection (Ansible 2.10+) `ansible-galaxy collection install -r requirements.yml`

Once this is installed you need to set up an Azure credentials file at `~/.azure/credentials` with the following contents

```
[default]
subscription_id=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
client_id=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
secret=xxxxxxxxxxxxxxxxx
tenant=xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

You can also use the following env vars if you don't want to create this file

* AZURE_SUBSCRIPTION_ID
* AZURE_CLIENT_ID
* AZURE_SECRET
* AZURE_TENANT

## Demo

Once the Azure and Ansible deps are set up there are 2 playbooks to run

* `provision.yml` - Provisions a new Azure VM
- `main.yml` - Installs IIS with a static website

When running `ansible-playbook provision.yml -v` it will prompt you for the following:

* The name of the resource group to create/use
* The name of the storage account to create/use
* The name of the virtual network to create/use
* The name of the virtual machine to create
* The username for the VM admin user
* The password for the VM admin user

The script will append the host details to the `inventory.ini` file under the `windows` group

From there to setup the IIS host run `ansible-playbook main.yml -v`.
