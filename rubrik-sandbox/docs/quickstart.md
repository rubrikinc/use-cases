# Rubrik Sandbox Quick Start Guide
## Introduction to the Rubrik Sandbox
The Rubrik Sandbox use-case provides the ability to automate the creation of an isolated network within VMware vSphere. A script is then ran to perform various validation tests against point-in-time copies of virtual machines which are restored via a Rubrik Live Mount into the isolated network.

Isolation is provided via a created vSphere Standard Switch and isolated portgroup. A vyOS router is deployed and configured to allow access into the isolated network via a specified masquerade network.

## Prerequisites

In order to successfully run the Rubrik Sandbox use-case there are a few services and prerequisisites you will need:
- [VMware vSphere](https://www.vmware.com) - As it stands, this use-case is currently only supported on VMware vSphere
- [PowerShell](https://github.com/PowerShell/PowerShell) - This script itself is written in PowerShell
- [The Rubrik Powershell SDK](https://build.rubrik.com/sdks/powershell/) - This provides the cmdlets to retrieve and configure the Live Mounts within Rubrik
- [VMware PowerCLI](https://www.vmware.com/support/developer/PowerCLI/) - This provides the cmdlets to configure and retrieve various pieces of infrastructure within VMware vSphere
- [Rubrik CDM 4.0+](https://www.rubrik.com/) - The platform that protects provisioned workloads
- [Microsoft Windows](https://www.microsoft.com) - As it stands, this use-case is only supported when executing from a Microsoft Windows machine with network access to the networks which will be isolated.

## Installation

Clone the `rubrik-sandbox` folder from the `use-cases` repository. Since this use-case resides in a global repository with other use-cases, you will need to create the git structure to only pull down this specified folder.
```bash
mkdir /folder_to_store_script && cd /folder_to_store_script
git init
git remote add -f origin https://github.com/rubrikinc/use-cases
git config core.sparseCheckout true
echo 'rubrik-sandbox' >> .git/info/sparse-checkout
git pull origin master
```

## Configuration

The Rubrik Sandbox use-case relies upon three external JSON formatted configuration files in order to provide the information needed to execute. These configuration files (router.config, creds.config, and apps.config) are explained below:
- router.config - The `router.config` file contains all of the information required in order to deploy and configure a vyOS router at the edge of the isolated network
- creds.config - The `creds.config` file contains pointers to encrypted files containing all of the credentials needed to connect to Rubrik, VMware, and the various Guest Operating System credentials.
- apps.config - The `apps.config` file contains all of the information around which virtual machines will be processed by the script, along with the respective tests that will be ran against them.

Configurations files may be created manually or by using a provided `confighelper.ps1` script.

### Creating the configurations manually

If creating the configurations manually, three files will need to be created (router.config, creds.config, apps.config)

#### Creating the Router Configuration (router.config)

The router configurations holds all of the information required to deploy and configure the vyOS router at the edge of the isolated network. A sample router.config file can be found [here](../config-samples/router.config) and looks as follows:
```json
{
    "RouterName": "rbk-route",
    "RouterPassword": "SuperSecret123!",
    "RouterAPIKey": "rbkapikeysecret",
    "VMwareHost": "esxi31.rubrik.us",
    "VMwareDatastore": "Gold",
    "ManagementNetwork": "Management",
    "ManagementNetworkIP": "10.8.96.151",
    "ManagementNetworkSubnet": "255.255.255.0",
    "ManagementNetworkGateway": "10.8.96.1",
    "IsolatedNetworks": [
      {
        "ProductionNetworkName": "VM_NETWORK",
        "IsolatedPortGroup": "VM_NETWORK_isolated",
        "InterfaceAddress": "10.8.112.1",
        "InterfaceSubnet": "255.255.252.0",
        "MasqueradeNetwork": "192.168.112.0",
        "DHCPEnabled": true,
        "DHCPScopeStart": "10.8.113.1",
        "DHCPScopeEnd": "10.8.113.200",
        "DHCPNameserver": "10.8.112.30",
      }
    ]
}
```
Let's explore each attribute within the `router.config` file:
- RouterName - This will be the name of the deployed virtual machine hosting the vyOS router within your vSphere environment
- RouterPassword - This will be the password assigned to the `vyos` user on the virtual router
- RouterAPIKey - This will be the vyOS router API key utilized to make API requests to the vyOS router
- VMwareHost - The name of the ESXi host within vSphere to both deploy the vyOS router and to host the isolated networks.  ***At the moment only a single ESXi host is supported***
- VMwareDatastore - The name of the vSphere datastore to host the storage for the vyOS router
- ManagementNetwork - The name of the management network to attach the router to
- ManagementNetworkIP - An IP address within the management network to assign to the router
- ManagementNetworkSubnet - The assoiciated subnet mask of the management network ip address
- MangementNetworkGateway - The default gateway within the management network
- IsolatedNetworks - This contains an array of networks which you would like to create isolated networks. You will need to include information here for each network that the virtual machines specified in `apps.config` are connected to. ***Note: At the moment, the ability to isolate the ManagementNetwork you specify above is not supported - you can only isolate networks which the router is not attached to***
  - ProductionNetworkName - The name of the production network to isolate
  - IsolatedPortGroup - The name to give to the isolated portgroup matching the production network
  - InterfaceAddress - The ip address of the router interface attached to the created isolated network. This should be the same as the default gateway of the production network you are looking to isolate in order to provide inter-vm communication within the isolated network without the need to reconfigure guest operating systems.
  - InterfaceSubnet - The associated subnet mask of the isolated network
  - MasqueradeNetwork - A subnet to use to provide masqueraded access into the isolated network. This subnet should not be used anywhere within your production environment. The associated subnet mask will be automatically created based on the information provided for the `InterfaceSubnet`.
  - DHCPEnabled - A boolean value specifying whether or not to enable DHCP within the isolated network.
  - DHCPScopeStart - The start IP of the DCHP scope
  - DHCPScopeEnd - The end IP of the DHCP scope
  - DHCPNameserver - The nameserver to pass through DHCP to virtual machines running within the isolated network

#### Creating the Credential configuration (creds.config) manually

The `creds.config` file contains pointers to encrypted files containing all of the credentials needed to connect to Rubrik, VMware, and the various Guest Operating System credentials. A sample credential configuration can be found [here](../config-samples/creds.config) and looks as follows:
```json
{
    "VMware": {
        "vCenterServer": "vcsa.rubrik.us",
        "Credentials": "C:\\creds\\vsphere.creds"
    },
    "Rubrik": {
        "RubrikCluster": "cluster-b.rubrik.us",
        "APIAuthToken": "c:\\creds\\rubrik.token"
    },
    "GuestCredentials": [
        {
            "CredentialName": "LocalAdministrator",
            "Credentials": "C:\\creds\\localadmin.creds"
        },
        {
            "CredentialName": "DomainAdministrator",
            "Credentials": "C:\\creds\\domainadmin.creds"
        }
    ]
}
```
Let's explore each attribute within the `creds.config` file:
- VMware - hosts VMware related authentication information
  - vCenterServer - The FQDN or IP Address of the vCenter Server
  - Credentials - The path to an encrypted file containing credentials with access to log into vCenter. Creation of the credentials can be handled by running `Get-Credential | Export-CLIXML <path_to_store_creds>`
- Rubrik - hosts Rubrik related authentication information
  - RubrikCluster - The FQDN or IP Address of the Rubrik Cluster to connect to
  - APIAuthToken - A path to an encrypted file containing the API Authentication Token for the specified Rubrik Cluster. Creation of the encrypted file can be handled by running `"<rubrik_api_token>" | Export-CLIXML <path_to_store_token>`
- GuestCredentials - An array of various credentials used to connect to the guest operating systems being tested. There is no limit on the amount of credentials you can configure
  - CredentialName - A unique name to assign to the credential (IE DomainAdministrator)
  - Credentials - The path to an encrypted file contiaining the desired credentials. Creation of these credentials can be handled by running `Get-Credential | Export-CLIXML <path_to_credential_file>`

#### Creating the Application Configuration (apps.config) manually

The `apps.config` file contains all of the information around which virtual machines will be processed by the script, along with the respective tests that will be ran against them. A sample application configuration can be found [here](../config-samples/apps.config) and looks as follows:
```json
{
    "settings": {
        "generateReport": true,
        "reportPath": "C:\\Users\\Administrator\\BackupValidiationLab\\report.html",
        "leaveLabRunning": false,
        "emailReport": true
    },
    "virtualMachines": [
        {
            "name": "MPRESTON-WIN",
            "mountName": "MPRESTON-WIN-MOUNT",
            "credentials": "LocalAdministrator",
            "skipPingTest": false,
            "skipToolsTest": false,
            "tasks": [
               {
                   "Name": "PortStatus",
                   "Port": "80",
                   "SuccessIf": "Closed"
               },
               {
                    "Name": "PortStatus",
                    "Port": "3389",
                    "SuccessIf": "Open"
               },
               {
                   "Name": "WindowsService",
                   "ServiceName": "MSSQLSERVER"
               },
               {
                   "Name": "WindowsService",
                   "ServiceName": "W32Time"
               }
            ]
        },
        {
            "name": "MPRESTON-SQL",
            "credentials":"LocalAdministrator",
            "mountName":"MPRESTON-SQL-MOUNT",
            "skipPingTest": false,
            "skipToolsTest": false,
            "tasks": [
                {
                    "Name": "WindowsService",
                    "ServiceName": "W32Time"
                },
                {
                    "Name": "PortStatus",
                    "Port": "3389",
                    "SuccessIf": "Open"
                }
            ]
        }
    ]
}
```
Let's explore each attribute within the `apps.config` file:
- generateReport - Specifies whether or not you would like to generate an HTML report summarizing the results of all tasks ran.
- reportPath - A path to where you would like to store the outputed report
- leaveLabRunning - Whether or not to leave the sandbox environment running once completed.
- emailReport - Not yet implemented
- virtualMachines - an array of virtual machines to process
  - name - The name of the virtual machine you would like to test
  - mountName - The name to give the point-in-time copy (the Rubrik Live Mount)
  - credentials - Credentials with access to log into the virtual machine. This value must match have a respective `CredentialName` within the GuestCredentials section of the `creds.config` file.
  - skipPingTest - Whether or not to skip the test which performs a ping to the Live Mounted virtual machine
  - skipToolsTest - Whether or not to skip the test which checks the status of VMware Tools on the live mounted virtual machine
  - tasks - specifies what additional tasks/tests to run against the virtual machine (explained below)

Within the tasks section, you can specify additional testing to run against the live mounted virtual machine. Currently there are two additional tests which can be performed:

**PortStatus**

This will utilize the `Test-Connection` cmdlet to check whether or not ports are open or closed on the live mounted copy of the virtual machine. In order to execute a PortStatus test, add the following attributes to the `tasks` configuration of the `apps.config` file on the desired virtual machine:
- Name - This will be set to "PortStatus"
- Port - Specify the port you would like to test
- SuccessIf - Specify whether the test should pass if the port is `Open` or `Closed`

**WindowsService**

This test will utilize the `Invoke-VMScript` cmdlet to check whether a service is running on a point in time copy of a Windows virtual machine. If `skipToolsTest` is set to true, or if VMware Tools cannot be detected on the virtual machine this test will automatically be skipped. If the specified service is detected as running, the test will result in a pass. If not, a fail is recorded. In order to execute a WindowsService test, add the following attributes to the `tasks` configuration of the `apps.config` file for the desired virtual machine:
- Name - This must be set to "WindowsService"
- ServiceName - The name of the service to check (IE MSSQLServer)

### Using the `confighelper.ps1` script to create the configurations automatically

If manually creating and modifying JSON isn't your thing you can use the included `confighelper.ps1` script in order to create the required configuration files for you.

To get started, simply run
```powershell
./confighelper.ps1
```

The script will then prompt for all of the information and credentials required to run the rubrik sandbox. Upon completion, you will be left with three files (a router configuration, a credential configuration, and a application configuration)

## Usage

Once configurations files have been successfully generated the use-case can be executed by running the following command:

```powershell
./Validate.ps1 -routerconfig <path_to_router_config> -credentialconfig <path_to_credential_config> -applicationconfig <path_to_application_config>
```

### To use the sandbox script for restore validation

This use-case can be utilized to perform various restore validations against Live Mounted virtual machines. To do so, ensure the router configuration, credential configuration, and application configuration files are fully populated and pass to the script.

Upon execution the following will occur:
1. The configuration files are ran through a check for validity
2. The specified vCenter is scanned to see if a router with the specified name has previously been deployed.
   1. If no router has been deployed a new one will be provisioned with a default configuration
3. The routers configuration is compared to the passed router configuration
   1. If changes are detected the old router will be decommisioned and a new one deployed in its' place
   2. The script will then configure the router based off the values provided within the router configuration file.
4. The isolated networks are created within vCenter
5. Rubrik Live Mounts will be performed based off of the information provided within the application configuration
6. The specified tests are ran against the virtual machines specified in the application configuration
7. If specified, a report is generated displaying the test results
8. If specified, the Rubrik Live Mounts are deleted

### To use the script to only create isolated sandbox labs

This use-case can also be used to just create the isolated sandbox environments. This is useful if you wish to do manual work after the Rubrik Live Mounts have completed. Since the networks are completely isolated and router interfaces match that of production gateways, virtual machines within the isolated labs are unaware that they reside within an isolated network and function just as they would if they were in production. Network communication between the VMs is also possible, meaning complete environments can be tested within the isolated environments. For example, customers can Live Mount Active Directory, SQL Server, Web Servers, and Application Servers and still maintain network connectivity amongst them all. This opens up doors for many different manual testing scenarious such as:
* Further manual testing of the restore points
* Penetration testing against point in time copies of their production workloads
* Upgrade and patch testing of multi-tier applications
* Triage or root-cause analysis of issues with a virtual machine
* Manually mounting and testing additional virtual machines and services into the isolated networks

To allow the sandbox to remain after the script, ensure the `LeaveLabRunning` attribute within the application config file is set to `true`

### Access to the virtual machines within the isolated environment

Access to the virtual machines within the isolated environment is handled through the specified masquerade network. 

For example, if a virtual machine contained a static IP address of 10.8.112.130 and the specified masquerade network is 192.168.112.0, the virtual machine can be accessed by it's masquerade IP, in this case, 192.168.112.130

If a virtual machine is set to DHCP, the router will then hand out a DHCP address to the VM. This address is then setup for access for the masquerade network. For instance, if the address leased is 10.8.113.100, the masquerade IP will be 192.168.113.100.  The leased address can be found either by accessing the live mounted virtual machine within VMware or by looking at the generated HTML report.

***The router is configured in such a way that the only access into the isolated environment is through the masquerade network. Inbound access is allowed, while all outbound access is denied***

By default, the only client that can access the masquerade network is the machine running this use-case. During the course of execution, a temporary route is created, routing all traffic to the masquerade network to the routers management IP address.

If you wish to allow other machines access into the isolated environment, appropriate static routes will need to be generated. For instance, if your routers IP address is 10.8.96.151 and your masquerade network is 192.168.112.0/22, a static route can be created on a machine to allow access by running the following:

```bash
route add 192.168.112.0 MASK 255.255.252.0 10.8.96.151
```
