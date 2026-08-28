# SOMAR-VDE-Replication
This repository contains the resources, AWS CloudFormation templates, scripts, and documentation required to replicate the SOMAR Virtual Data Enclave (VDE) environment on AWS.

# Documentation

Detailed documentation is located in the [`docs/`](docs/) directory.
1. [SOMAR VDE Replication Overview](docs/01-SOMAR-VDE-Replication-Overview.md)
2. [VDE Deployment Guide](docs/02-VDE-Deployment-Guide.md)
3. [Security Groups](docs/03-Security-Groups.md)
4. [End-User Testing](docs/04-End-User-Testing.md)
5. [Items not covered](docs/05-UM-Specific-Items-Not-Covered-in-this-Guide.md)

# Project Structure
- `ARC-EC2-Powerstate` - Contains PowerShell scripts and AWS modules used inside the Windows Bastion to control the state of the compute nodes and to initiaize connection via RDP to the compute node.
- `AWS-Replication-Templates` - Contains generalized AWS CloudFormation templates to provision a base Virtual Data Enclave (VDE) on AWS. Refer to the [VDE Deployment Guide](docs/02-VDE-Deployment-Guide.md) for deployment instructions.
- `Squid-Proxy` - Contains Squid Proxy configurations and allowlist used to control the outbound traffic from the bastion and compute node.
- `ec2-powerstate.zip` - Contains the compressed contents of the `ARC-EC2-Powerstate` folder.
