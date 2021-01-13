# Auto Assign SLA Domain by Nutanix Prism Categories

This repository contains a PowerShell script designed to automatically assign Nutanix AHV VMs to Rubrik SLA Domains based off of their category memberships within Prism.

## :blue_book: Documentation

Here are some resources to get you started! If you find any challenges from this project are not properly documented or are unclear, please [raise an issue](https://github.com/rubrikinc/use-cases/issues/new/choose) and let us know! *Be sure to specify the issue is related to the Auto Assign SLA Domain by Nutanix Prism Category usecase* as their are multiple use-cases hosted from this repository.  This is a fun, safe environment - don't worry if you're a GitHub newbie! :heart:

* Quick Start Guide - Coming Soon
* Getting Started Video - Coming Soon

## :white_check_mark: Prerequisites

There are a few services you'll need in order to get this project off the ground:

* Nutanix Prism - Nutanix Prism is the management application which allows you to assign AHV VMs to categories
* PowerShell - The script itself is written in PowerShell
* The Rubrik PowerShell SDK - The cmdlets to retrieve and configure AHV VMs within Rubrik.
* Rubrik CDM 4.0+ - the platform that protects provisioned workloads

## :hammer: Installation

This folder can be dropped anywhere on your workstation that has network connectivity to a Rubrik cluster and a Nutanix Prism instance.

### Configuration

The script relies upon one main point of configuration: A configuration JSON file.

#### Config JSON File

The config JSON file (here-on referred to as config.json) can be placed anywhere within the filesystem and is passed to the script through the `ConfigFile` parameter similar to below:

``` powershell
prism-category-to-sla.ps1 -ConfigFile "c:\path_to_config_file"
```

A sample config.json can be found [here](config.json) and looks as as follows:

```json
{
    "Nutanix": {
        "PrismAddress": "192.168.10.170",
        "PrismCredentials": "c:\\nutanix\\creds\\NutanixCreds.xml",
        "PrismCategory": "SLADomain",
        "AutoUpdate": "True"
    },
    "Rubrik": {
        "RubrikAddress": "192.168.150.131",
        "RubrikCredentials": "c:\\nutanix\\creds\\RubrikCreds.xml"
    }
}
```

As shown, the configuration file is split into two main sections:

* Nutanix
  * *PrismAddress* - refers to the IP or FQDN of the Prism instance
  * *PrismCredentials* - path to credential object with appropriate access to Prism, encrypted with the Microsoft Common Language Infrastructure (CLIXML)
  * *PrismCategory* - refers to the category name within Prism which will hold the values which match the SLA Domains configured within Rubrik
  * *AutoUpdate* - If set to true, this will allow the script to automatically create the Prism category and associated values based off of the `PrismCategory` value
* Rubrik
  * *RubrikAddress* - refers to the IP or FQDN of the Rubrik Cluster hosting the SLA Domains
  * *RubrikCredentials* - path to credential object with appropriate access to Rubrik CDM, encrypted with the Microsoft Common Language Infrastructure (CLIXML)

The configuration file must adhere to JSON standards. The file can be created manually or automatically by executing the script with no parameters `prism-category-to-sla.ps1` and following the prompts.

If creating the file manually, you must also provide encrypted credential files to connect to both Prism and Rubrik. These can be generated with the following syntax:

```powershell
Get-Credential | Export-CLIXML c:\path_to_rubrik_creds
Get-Credential | Export-CLIXML c:\path_to_prism_creds
```

### Usage

Once the configuration file has been created the script can be executed as follows:

```powershell
./prism-category-to-sla.ps1 -ConfigFile c:\path_to_config_file
```

The script will then ensure that any AHV VM belonging to the *PrismCategory* will be assigned to the SLA Domain matching the respective category value.

## :muscle: How You Can Help

We glady welcome contributions from the community. From updating the documentation to creating enhancements and fixing bux, all ideas are welcome. Thank you in advance for all of your issues, pull requests, and comments! :star:

* [Contributing Guide](CONTRIBUTING.md)
* [Code of Conduct](CODE_OF_CONDUCT.md)

## :pushpin: License

* [MIT License](LICENSE)

## :point_right: About Rubrik Build

We encourage all contributors to become members. We aim to grow an active, healthy community of contributors, reviewers, and code owners. Learn more in our [Welcome to the Rubrik Build Community](https://github.com/rubrikinc/welcome-to-rubrik-build) page.

We'd love to hear from you! Email us: build@rubrik.com :love_letter:
