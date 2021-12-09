# Rubrik Sandbox Use-Case
This repository contains a PowerShell script designed to create isolated networks fronted by a vyOS router. Virtual machines are then live mounted into the isolated networks and various restore validation tests can be be performed against them such as ping, looking for certain running services, and checking for open or closed TCP ports.

The isolated networks contain point in time copies of production services and can be accessed through a specified masquerade network, allowing IT professionals to further perform various activities within the isolated networks such as:
* Patch and Upgrade testing.
* Penetration and Security testing
* Triage or root-cause analysis

## :blue_book: Documentation

Here are some resources to get you started! If you find any challenges from this project are not properly documented or are unclear, please [raise an issue](https://github.com/rubrikinc/use-cases/issues/new/choose) and let us know! *Be sure to specify the issue is related to the Rubrik Sandbox use-case* as their are multiple use-cases hosted from this repository.  This is a fun, safe environment - don't worry if you're a GitHub newbie! :heart:

* [Quick Start Guide](docs/quickstart.md)
* Getting Started Video - Coming Soon

## :white_check_mark: Prerequisites

In order to successfully run the Rubrik Sandbox use-case there are a few services and prerequisites you will need:
- [VMware vSphere](https://www.vmware.com) - As it stands, this use-case is currently only supported on VMware vSphere
- [PowerShell](https://github.com/PowerShell/PowerShell) - This script itself is written in PowerShell
- [The Rubrik Powershell SDK](https://build.rubrik.com/sdks/powershell/) - This provides the cmdlets to retrieve and configure the Live Mounts within Rubrik
- [VMware PowerCLI](https://www.vmware.com/support/developer/PowerCLI/) - This provides the cmdlets to configure and retrieve various pieces of infrastructure within VMware vSphere
- [Rubrik CDM 4.0+](https://www.rubrik.com/) - The platform that protects provisioned workloads
- [Microsoft Windows](https://www.microsoft.com) - As it stands, this use-case is only supported when executing from a Microsoft Windows machine with network access to the networks which will be isolated.

## :hammer: Installation

This folder can be dropped anywhere on your workstation that has network connectivity to a Rubrik cluster and the VMware vCenter.

### Configuration

The script relies upon three main points of configuration: 

#### Router Configuration (router.config)

The router configurations holds all of the information required to deploy and configure the vyOS router at the edge of the isolated network. A sample router.config file can be found [here](config-samples/router.config) and looks as follows:
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
- ManagementNetworkSubnet - The associated subnet mask of the management network ip address
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

#### Credential Configuration (credentials.config)

The `creds.config` file contains pointers to encrypted files containing all of the credentials needed to connect to Rubrik, VMware, and the various Guest Operating System credentials. A sample credential configuration can be found [here](config-samples/creds.config) and looks as follows:
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
  - Credentials - The path to an encrypted file containing the desired credentials. Creation of these credentials can be handled by running `Get-Credential | Export-CLIXML <path_to_credential_file>`

#### Application Configuration (apps.config)

The `apps.config` file contains all of the information around which virtual machines will be processed by the script, along with the respective tests that will be ran against them. A sample application configuration can be found [here](config-samples/apps.config) and looks as follows:
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
- reportPath - A path to where you would like to store the outputted report
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

***Note: The file can be created manually or automatically by executing the included `confighelper.ps1` script and following the prompts.***

### Usage

Once the configuration file has been created the script can be executed as follows:

```powershell
./Validate.ps1 -routerconfig <path_to_router_config> -credentialconfig <path_to_credential_config> -applicationconfig <path_to_application_config>
```
Upon execution the following will occur:
1. The configuration files are ran through a check for validity
2. The specified vCenter is scanned to see if a router with the specified name has previously been deployed.
   1. If no router has been deployed a new one will be provisioned with a default configuration
3. The routers configuration is compared to the passed router configuration
   1. If changes are detected the old router will be decommissioned and a new one deployed in its' place
   2. The script will then configure the router based off the values provided within the router configuration file.
4. The isolated networks are created within vCenter
5. Rubrik Live Mounts will be performed based off of the information provided within the application configuration
6. The specified tests are ran against the virtual machines specified in the application configuration
7. If specified, a report is generated displaying the test results
8. If specified, the Rubrik Live Mounts are deleted

## :muscle: How You Can Help

We glady welcome contributions from the community. From updating the documentation to creating enhancements and fixing bux, all ideas are welcome. Thank you in advance for all of your issues, pull requests, and comments! :star:

* [Contributing Guide](../CONTRIBUTING.md)
* [Code of Conduct](../CODE_OF_CONDUCT.md)

## :pushpin: License

* [MIT License](../LICENSE)

## :point_right: About Rubrik Build

We encourage all contributors to become members. We aim to grow an active, healthy community of contributors, reviewers, and code owners. Learn more in our [Welcome to the Rubrik Build Community](https://github.com/rubrikinc/welcome-to-rubrik-build) page.

We'd love to hear from you! Email us: build@rubrik.com :love_letter: