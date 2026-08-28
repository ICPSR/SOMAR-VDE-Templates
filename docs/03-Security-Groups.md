# Security Groups

## Table of Contents
- [Security Group Rules and Definitions](#security-group-rules-and-definitions)
- [Security Group Attachments](#security-group-attachments)

## Security Group Rules and Definitions

1. EC2 VPC Interface Endpoint Security Group **(EC2 Endpoint SG)**: 
   
   The EC2 Endpoint security group in Table 1 uses a self-referencing rule, the group allows inbound HTTPs traffic only from other resources that also have this same security group attached. And the EC2 Endpoint security group is attached to the bastion instances, allowing the bastions to talk to the EC2 endpoint securely over port 443 to call EC2 APIs such as start/stop instances.

<div align="center">
Table 1 EC2 Endpoint Security Group

|  |  |  |  |
| --- | --- | --- | --- |
| **Source** | **Type** | **Port Range** | **Protocol** |
| EC2 Endpoint SG | HTTPS | 443 | TCP |
| **Destination** | **Type** | **Port Range** | **Protocol** |
| 0.0.0.0/0 | All | All | All traffic |
</div>

2. Bastion Security Group:
   
   The bastion security group in Table 2 allows inbound RDP access from on-premises CIDR range/client VPN security group. This ensures end-users and administrators can connect to the bastion host securely using remote desktop.

<div align="center">
Table 2 Bastion Security Group

|  |  |  |  |
| --- | --- | --- | --- |
| **Source** | **Type** | **Port Range** | **Protocol** |
| on-prem network CIDR/client VPN Security Group | RDP | 3389 | TCP |
| **Destination** | **Type** | **Port Range** | **Protocol** |
| 0.0.0.0/0 | All | All | All traffic |
</div>

3. Proxy Security Group (Note: The 3128 Port is optional and is for Internet connection to Bastion Host to perform Domain Join, Host Configuration, etc):

   The proxy’s security group in Table 3 uses self-referencing on ports 3128 and 3129. The outbound rule is open to allow internet access, but external access is still controlled by the Squid Proxy’s allowlist.

<div align="center">
Table 3 Squid Proxy Security Group

|  |  |  |  |
| --- | --- | --- | --- |
| **Source** | **Type** | **Port Range** | **Protocol** |
| Proxy SG | Custom TCP | 3128 | TCP |
| Proxy SG | Custom TCP | 3129 | TCP |
| **Destination** | **Type** | **Port Range** | **Protocol** |
| 0.0.0.0/0 | All | All | All traffic |
</div>

4. Node Security Group:

   The compute nodes use a security group that only allows RDP access from the bastion’s security group. This enforces end-users to go through the bastion first to access their compute instances.

<div align="center">
Table 4 Compute Node Security Group

|  |  |  |  |
| --- | --- | --- | --- |
| **Source** | **Type** | **Port Range** | **Protocol** |
| Bastion SG | RDP | 3389 | TCP |
| **Destination** | **Type** | **Port Range** | **Protocol** |
| 0.0.0.0/0 | All | All | All traffic |
</div>

## Security Group Attachments

Each of the Bastion instances are attached to the following 3 security groups

* EC2EndpointSecurityGroup
* Bastion SG
* Proxy SG

<p align="center">
  <img src="images/Security Groups attached to each of the Bastion Instance.png" alt="Security Groups attached to each of the Bastion Instance">
  <br>
  <em>Security Groups attached to each of the Bastion Instance</em>
</p>


Each of the compute node instances have 2 security groups attached.

* Proxy SG
* Node SG

<p align="center">
  <img src="images/Security Groups attached to each of the Compute Instance.png" alt="Security Groups attached to each of the Compute Instance">
  <br>
  <em>Security Groups attached to each of the Compute Instance</em>
</p>

The EC2 Interface Endpoint has 1 security group attached:

* EC2 Endpoint SG

The Proxy Instance has 1 security group attached.

* Proxy SG

<p align="center">
  <img src="images/Security Group attached to the Squid Proxy Instance.png" alt="Security Group attached to the Squid Proxy Instance">
  <br>
  <em>Security Group attached to the Squid Proxy Instance</em>
</p>