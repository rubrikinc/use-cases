# Auto Assign SLA Domain by Nutanix Prism Categories Quick Start Guide

## Introduction to the Auto Assign SLA Domain by Nutanix Prism Categories Use-Case

Categories are an efficient way to define groups of entities within Nutanix Prism, allowing policies and enforcements to be applied to groups of objects rather than having to process each individual object. Categories are often used to define items like environments or application tiers, however, they can also be used in conjunction with Rubrik CDM to define protection levels, or SLA Domain assignments.

In order to successfully execute this script, a Prism category containing values that match that of configured SLA Domains within Rubrik must first be created. From there, AHV VMs are assigned to these category values. This script will then read the assigned categories of the VMs and ensure that the VMs are assigned to the matching Rubrik SLA Domain.

***Note: The script can create and manage the Nutanix Prism category for you by setting the `AutoUpdateFlag` to `True` within the configuration file***

## Prerequisites

There are a few services you'll need in order to get this project off the ground:

* Nutanix Prism - Nutanix Prism is the management application which allows you to assign AHV VMs to categories
* PowerShell - The script itself is written in PowerShell
* The Rubrik PowerShell SDK - The cmdlets to retrieve and configure AHV VMs within Rubrik.
* Rubrik CDM 4.0+ - the platform that protects provisioned workloads

## Installation

Clone the `auto-assign-sla-domains-by-prism-categories` folder from the `use-cases` repository. Since this use-case resides in a global repository with other use-cases, you will need to create the git structure to only pull down this one.
```bash

mkdir /folder_to_store_script && cd /folder_to_store_script
git init
git remote add -f origin https://github.com/rubrikinc/use-cases
git config core.sparseCheckout true
echo 'auto-assign-sla-domains-by-prism-categories' >> .git/info/sparse-checkout
git pull origin master
```

## Configuration

## Usage
