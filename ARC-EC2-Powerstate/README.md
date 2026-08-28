# ARC-EC2-PowerState

This repository contains custom UM code and modified AWS PowerShell modules which allow power state management of EC2 instances.

**CLI Script:** [_ec2-powerstate_cli.ps1_ ](/ARC-EC2-Powerstate/ec2-powerstate_cli.ps1) 

**GUI Script:** [_ec2-powerstate_gui.ps1_ ](/ARC-EC2-Powerstate/ec2-powerstate_cli.ps1)

**Modified AWS modules:** [_AWS_Modules.zip_](AWS_Modules.zip)

Assumptions:
- These scripts (cli, gui versions) will be launched from a specially prepared Windows Bastion station within the Precision Health secure enclave
- The bastion host and target EC2 worker nodes exist in the same AWS region
- If the bastion host is utilizing the enclave web proxy server, the web proxy and local Windows proxy settings are configured as needed, including bypassing the proxy for the local machine's EC2 meta-data URLs so it can be read directly from the bastion host

The script takes zero or one argument:
- No args: Query and filter EC2 instances in the same region as the calling EC2 instance
- One arg: Override the default behavior of querying for EC2 inventory with the same "**_mcomm_**" tag as the calling host, and search for matches on that tag instead
  - Argument should be in the form of "**_tag:value_**"

GUI script additional features:
- Event logging to the Windows Application log as source  "EC2 PowerState Script"; includes day/time stamp, power action status, user, action, targeted instance
- Ability to suspend EC2 state auto-refresh via a checkbox
- Ability to exempt from the list otherwise eligible mcomm tag matching EC2 instances if those instances are tagged with "**_power_protect:true_**"
- Launch an RDC client session for selected instances if the host is runnning

<details><summary>Click to expand sample screen shots</summary>
EC2_PowerState_GUI

![ALT](/ARC-EC2-Powerstate/screenshot_gui.png)

EC2_PowerState_CLI

![ALT](/ARC-EC2-Powerstate/screenshot_cli.png)
</details>



# Preparing the Environment
AWS Requirements:
- A VPC endpoint for **_ec2.us-east-1.amazonaws.com_** is established and applied to the Bastion host's subnet
  - ec2.us-east-1.amazonaws.com should resolve to an address local to the bastion host's subnet (for example, _10.236.164.*_)
    - this service:ip mapping can be done via a local hosts file or private DNS publishing for the endpoint service
  - _OR_ if using the enclave's web proxy, the web proxy needs access to the public IP EC2 service address (this may require _NOT_ publishing the private DNS of the VPC, as that replaces the standard DNS resolution for the entire VPC including the proxy network -- and will prevent the proxy from reaching the public service enpoint). 
- The _**BastionRole-precision-health-enclave**_ IAM role has been applied to the Bastion host.
  - This IAM role allows EC2 service permissions:
    - Describeintstances (all)
    - Startinstances (mcomm tag: _precision-health-enclave_)
    - Stopinstances (mcomm tag: _precision-health-enclave_)
- EC2 instances to have power state controlled by this script must be tagged with a key **_mcomm_** and a value of **_precision-health-enclave_**
  - This default key:value tag set may be overridden at script invocation time by supplying an alternate key:value set as an argument

Runtime Requirements:
- Download or install these specific AWS PowerShell modules from the [PowerShell Gallery](https://www.powershellgallery.com/packages?q=AWS.Tools) for the standard PowerShell environment:
  - aws.tools.common
  - aws.tools.ec2

[Document for configuring AWS PowerShell modules](Configuring_AWS_PowerShell_Modules.md)
