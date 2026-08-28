# SOMAR Virtual Data Enclave Replication Overview

The SOMAR Virtual Data Enclave (VDE) is a secure, cloud-based research environment operated by the Social Media Archive at ICPSR (SOMAR). It enables researchers to analyze restricted data in a controlled remote desktop workspace while enforcing strict data security policies.

Researchers access assigned virtual machines through a secure VPN connection and perform all analysis inside the enclave. Data cannot be transferred into or out of the environment without review and approval from data custodians, and external internet access is tightly restricted. The VDE has several features designed to ensure data security, including:

* No external internet access.
* No copying and pasting from outside the VDE environment.
* Researchers cannot upload their own external files or export files from the VDE environment.

## Table of Contents
- [Enclave Operational Roles and Responsibilities](#enclave-operational-roles-and-responsibilities)
- [Enclave Architecture](#enclave-architecture)

## Enclave Operational Roles and Responsibilities

**Operator (Cloud/Infrastructure Owner)**

Primary Focus: AWS infrastructure lifecycle management

Responsibilities:

* Deploy and manage infrastructure using AWS CloudFormation.
* Handle stack updates, rollbacks, and disaster recovery.
* Manage IAM roles and instance profiles.
* Monitor AWS resource health and costs.
* Maintain networking, security groups, and cloud level access controls.
* Ensure compliance with organizational cloud security policies.

Scope Boundary:

* Does not manage OS-level user accounts inside the instances.
* Does not review, access or approve research data.

**System Administrator**

Primary Focus: Operating system and enclave machine management

Responsibilities:

* Configure users and groups on Bastion and Node instances.
* Maintain and update custom AMIs via EC2 Image Builder in coordination with the Operator.
* Monitor system health inside instances.
* Troubleshoot OS-level issues.
* Enforce enclave security policies (e.g., disable copy/paste, manage website allowlists).
* Apply OS patches and maintain installed research software.

Scope Boundary:

* Does not manage AWS infrastructure.
* Does not review, access or approve research data.

**Data Custodians**

Primary Focus: Data governance and controlled data movement. Decision maker for what data arrives and leaves the enclave.

Responsibilities:

* Manage research group S3 buckets:
  + Read-only bucket for data import.
  + Write-only bucket for data export staging.
* Review files uploaded by end users for export.
* Approve or reject export requests.
* Move approved files to external distribution locations.
* Ensure compliance with data use agreements.

Scope Boundary: Does not manage cloud infrastructure or OS configuration.

**Data Assistant**

Primary Focus: User onboarding and first line support

Responsibilities:

* Review and process user access applications.
* Provide onboarding instructions and enclave usage guidance to end users.
* Serve as first point of contact for user support questions.
* Perform initial troubleshooting and escalate technical issues to the System Administrator or Operator as appropriate.

**End Users**

Primary Focus: Conduct research on restricted datasets within the controlled enclave environment

Responsibilities:

* Access Node instances through Bastion host.
* Download approved datasets from group read-only S3 bucket.
* Perform analysis using installed tools (R, Jupyter, etc.).
* Upload export-request files to write-only S3 bucket.
* Follow enclave usage and compliance policies.

## Enclave Architecture

This guide provides operational and testing instructions for the CloudFormation templates used to provision AWS resources for the VDE test environment. The following architecture diagram provides an overall of the infrastructure components and their relationships.

<p align="center">
  <img src="images/AWS Architecture Diagram for the VDE Test Environment.png" alt="AWS Architecture Diagram for the VDE Test Environment">
  <br>
  <em>AWS Architecture Diagram for the VDE Test Environment</em>
</p>

The networking architecture consists of the following major components:

* 1 **Virtual Private Cloud (VPC)**
* 3 **Subnets**
  + **Public Subnet**
    - Hosts the squid proxy.
  + **Private Bastion Subnet**
    - Single secure entry point.
    - Accessible only via VPN.
  + **Private Node Subnet**
    - Hosts research group compute nodes.

Security groups are configured with strict access controls to enforce network segmentation and limit traffic between components.

Two VPC endpoints are configured:

* **EC2 Interface Endpoint**
  + Configured to the bastion subnet. Users logged into the bastion host can use this endpoint to make EC2 service API calls to start or stop their associated research group node instances.
* **S3 Gateway Endpoint**
  + Configured for the node subnet’s route table. Users who access the node from the bastion host can use this endpoint to:
    - Download data from their research group’s **read-only** S3 bucket.
    - Upload data to their research group’s **write-only** S3 bucket for export.

Uploaded files are reviewed by data custodians, who either approve or reject them. Approved files are then moved to external locations.

The Squid proxy runs in a Docker container on an Ubuntu instance within the public subnet. Administrators can manage and control outbound website access by updating the shared [`Squid-Proxy/sites.allowlist.txt`](../Squid-Proxy/sites.allowlist.txt) file. Network traffic from the **compute node** instances is routed to the Squid proxy over **port 3128**. If required, the security group associated with the bastion hosts can be modified to allow ingress traffic to the Squid proxy over **port 3129**, enabling operations such as domain join and host configuration.

The following diagramn illustrates the current production architecture used at SOMAR. In the production environment, network access follows an on premises managed VPN model combined with an **AWS Site to Site VPN** to provide secure, controlled access to private AWS resources. End users must first connect to the organization’s **corporate VPN**. Once connected, traffic is routed through an **AWS Site to Site VPN**, consisting of a **Customer Gateway** on the organization side and a **Virtual Private Gateway** attached to the AWS VPC. This design enforces centralized network controls and integrates with corporate security policies, and it often requires coordination between IT, networking and security teams.

As an alternative for local testing and non-production environments, **AWS Client VPN** is used to provide secure access without overhead of managing on-premises VPN infrastructure. In this model, all required components are provisioned and managed in the cloud. This approach mirrors production access patterns and improves security by introducing certificate-based authentication. It is important to note that the VPN architecture used in production environments differs from this approach.

Procedures for integrating instances with Active Directory are not included in this documentation, as these steps are institution specific.

<p align="center">
  <img src="images/AWS Architecture Diagram for the Production Environment at SOMAR.png" alt="AWS Architecture Diagram for the Production Environment at SOMAR">
  <br>
  <em>AWS Architecture Diagram for the Production Environment at SOMAR</em>
</p>
