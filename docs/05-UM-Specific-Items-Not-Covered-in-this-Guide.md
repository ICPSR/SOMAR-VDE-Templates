# UM-Specific Items Not Covered in this Guide

The following components are specific to the University of Michigan (UM) environment and are not included in this guide. The system can generally function without these components; however, they were implemented in the UM deployment environment to meet institutional infrastructure, security, and compliance requirements.

* Domain Join, Host Configuration and Group Policy:
  Bastion and compute nodes are domain joined and configured using UM-specific policies. Group Policy is configured to:

  + Disable Clipboard, local drive and printer redirection on Windows bastion hosts, to reduce the risk of authorized data transfer between local workstations and the VDE.
  + Prevent users from shutting down the bastion node.

* UM VPN and AWS Network Configuration:
  + UM VPN setup.
  + AWS Site to Site VPN.
  + AWS Customer Gateway.
  + AWS Virtual Private Gateway.
* Security hardening procedures for bastion and compute node images, customized for UM’s compliance and security standards.
* Configuration for redirecting audio from compute node instances to the bastion node.