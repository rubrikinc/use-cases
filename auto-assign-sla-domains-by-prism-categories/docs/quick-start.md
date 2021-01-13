# Auto Assign SLA Domain by Nutanix Prism Categories Quick Start Guide

## Introduction to the Auto Assign SLA Domain by Nutanix Prism Categories Use-Case

Categories are an efficient way to define groups of entities within Nutanix Prism, allowing policies and enforcements to be applied to groups of objects rather than having to treat each individual object. Categories are often used to define things like environments or application tiers, however, they can also be used in conjunction with Rubrik CDM to define protection levels, or SLA Domain assignments.

In order to successfully execute this script, a Prism category containing values that match that of configured SLA Domains within Rubrik must first be created. From there, AHV VMs are assigned to these category values. This script will then read the assigned categories of the VMs and ensure that the VMs are assigned to the matching Rubrik SLA Domain.

## Installation

## Configuration

## Usage
