# End-User Testing

The end-user testing guide covers testing done from an end-user and data custodian’s view.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Connect to the Bastion Instance via AWS Client VPN](#connect-to-the-bastion-instance-via-aws-client-vpn)
  - [Connect to the AWS Client VPN Endpoint](#connect-to-the-aws-client-vpn-endpoint)
  - [Connect to the Bastion Host Using Remote Desktop](#connect-to-the-bastion-host-using-remote-desktop)
- [Connect to the Bastion Instance via EC2 Instance Endpoint (Alternative)](#connect-to-the-bastion-instance-via-ec2-instance-endpoint-alternative)
- [Test the Bastion Instance Functionality](#test-the-bastion-instance-functionality)
  - [Control the State of the Node Instance from Bastion](#control-the-state-of-the-node-instance-from-bastion)
  - [Connect to the Node from the Bastion](#connect-to-the-node-from-the-bastion)
- [Test the Node Instance Functionality](#test-the-node-instance-functionality)

## Prerequisites

This guide assumes:

* The operator has completed all required steps outlined in the [VDE Deployment Guide](02-VDE-Deployment-Guide.md).
* The operator has access to the Windows bastion local Administrator password, which can be retrieved from the Amazon EC2 Console using the EC2 key pair specified when the bastion instance was launched, as shown in the following screenshot.
* For the compute node instance, the operator configures a default Ubuntu user password specified as a NoEcho parameter during the [enclave-lab.yaml](../AWS-Replication-Templates/enclave-lab.yaml) CloudFormation Template stack creation.

<p align="center">
  <img src="images/Retrieve AWS EC2 Windows Password.png" alt="Retrieve AWS EC2 Windows Password">
  <br>
  <em>Retrieve AWS EC2 Windows Password</em>
</p>

While end users may initially log in using these administrative credentials, it is strongly recommended that system administrators or operators create individual user accounts or user groups and grant appropriate permissions for individual/group access, and to avoid sharing administrative credentials.

## Connect to the Bastion Instance via AWS Client VPN

### Connect to the AWS Client VPN Endpoint

Download and install the AWS Client VPN Desktop application for your operating system from the following link: <https://aws.amazon.com/vpn/client-vpn-download/>

If this is your first time using AWS Client VPN, open the Client VPN application and add profile by adding the .opvn configuration file provided by the operator or VPN administrators as shown in the following screenshot. Once the profile is added, click `Connect` to establish the VPN connection.

<p align="center">
  <img src="images/AWS VPN Client Application.png" alt="AWS VPN Client Application">
  <br>
  <em>AWS VPN Client Application</em>
</p>

### Connect to the Bastion Host Using Remote Desktop

After successfully connecting to the VPN, request the private IPv4 address of the bastion instance from the operator. This information can be found in the EC2 Console, as shown in the following example.

<p align="center">
  <img src="images/Bastion Instance IPv4 Address.png" alt="Bastion Instance IPv4 Address">
  <br>
  <em>Bastion Instance IPv4 Address</em>
</p>

Open the Windows App and enter the bastion’s private IPv4 address as the PC name as shown below. When prompted, log in using the **administrator** or **end-user** credentials provided/created by the system administrator.

<p align="center">
  <img src="images/Configure PC in Windows Remote Desktop App.png" alt="Configure PC in Windows Remote Desktop App" width="60%">
  <br>
  <em>Configure PC in Windows Remote Desktop App</em>
</p>

## Connect to the Bastion Instance via EC2 Instance Endpoint (Alternative)

If a tester needs to connect to the bastion instance without using the VPN, the operator may deploy the `ec2-endpoint.yaml` CloudFormation Template to provision an EC2 Instance Connect Endpoint. This enables testers to initiate a Remote Desktop Protocol (RDP) connection from their local desktop to the bastion instance without exposing the instance to the public internet.

To use this access method, the tester must have AWS permission to run AWS CLI commands and must be granted the IAM permission `ec2-instance-connect:OpenTunnel` on their user or role.

To open a tunnel via EC2 instance connect endpoint, the following command in the screenshot is used, where the instance-id is the instance id of the bastion instance. More information can be found in this AWS user guide: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-using-eice.html#eic-connect-using-rdp>

<p align="center">
  <img src="images/AWS EC2 Instance Connect CLI Command.png" alt="AWS EC2 Instance Connect CLI Command">
  <br>
  <em>AWS EC2 Instance Connect CLI Command</em>
</p>

Once the tunnel is open, the tester can connect to the bastion instance by opening the **Windows App** and entering `localhost:5555` in the **Edit PC** window when using macOS, where 5555 is the local port specified in the AWS CLI command, as shown in the screenshot above. The tester must also provide the **administrator credentials** to complete the Remote Desktop login, as part of the Prerequisite. The following screenshots illustrate the connection stepsusing the Windows App.

<p align="center">
  <img src="images/Windows Desktop Add Credentials.png" alt="Windows Desktop Add Credentials">
  <br>
  <em>Windows Desktop Add Credentials</em>
</p>

<p align="center">
  <img src="images/Windows Desktop initialize RDP Connection.png" alt="Windows Desktop initialize RDP Connection">
  <br>
  <em>Windows Desktop initialize RDP Connection</em>
</p>

## Test the Bastion Instance Functionality

Once the tester is connected to the Windows Bastion machine, double click the `START STOP VM` icon on Desktop to run the EC2-Powerstate PowerShell script as shown below. More information about the script installation and usage can be found in the [README.md](../ARC-EC2-Powerstate/README.md) and [VDE Deployment Guide](02-VDE-Deployment-Guide.md).

<p align="center">
  <img src="images/Bastion Instance Desktop.png" alt="Bastion Instance Desktop">
  <br>
  <em>Bastion Instance Desktop</em>
</p>


### Control the State of the Node Instance from Bastion

The script [ec2-powerstate_gui.ps1](../ARC-EC2-Powerstate/ec2-powerstate_gui.ps1) determines the state of the node instance by querying the mcomm tag value that were tagged to the bastion and node instances. Only the node instance that shares the same mcomm value as the bastion instance is queried. The graphical user interface (GUI) allows users control the power state of their associated node instance by clicking then Power button, as shown in the following 3 figures.

<p align="center">
  <img src="images/EC2 Powerstate Script GUI.png" alt="EC2 Powerstate Script GUI">
  <br>
  <em>EC2 Powerstate Script GUI</em>
</p>

<p align="center">
  <img src="images/Power Off the Compute Node.png" alt="Power Off the Compute Node">
  <br>
  <em>Power Off the Compute Node</em>
</p>

<p align="center">
  <img src="images/Compute Node in the Stopping State.png" alt="Compute Node in the Stopping State">
  <br>
  <em>Compute Node in the Stopping State</em>
</p>

### Connect to the Node from the Bastion

The user can connect to the node instance by clicking the Launch RDC button.

<p align="center">
  <img src="images/Initialize RDP Connection from Bastion Node to Compute Node.png" alt="Initialize RDP Connection from Bastion Node to Compute Node">
  <br>
  <em>Initialize RDP Connection from Bastion Node to Compute Node</em>
</p>

The tester will then be prompted to enter the username and password of their node based on how their organization binds the node VM with their user credentials.

<p align="center">
  <img src="images/Compute Node Loggin Page.png" alt="Compute Node Loggin Page">
  <br>
  <em>Compute Node Loggin Page</em>
</p>

<p align="center">
  <img src="images/Compute Node Desktop.png" alt="Compute Node Desktop">
  <br>
  <em>Compute Node Desktop</em>
</p>

## Test the Node Instance Functionality

### S3 Data Upload and Download Example

Each of the deployed lab templates will create 2 S3 buckets, `enclave-prefix-researchgroupname-in` and `enclave-prefix-researchgroupname-out`.

End-users have read only access to the `enclave-prefix-researchgroupname-in` bucket and can download files from the bucket using the aws s3 cp command.

<p align="center">
  <img src="images/Read Only S3 Bucket of the Enclave Node.png" alt="Read Only S3 Bucket of the Enclave Node">
  <br>
  <em>Read Only S3 Bucket of the Enclave Node</em>
</p>

<p align="center">
  <img src="images/Download sample file from Read Only S3 Bucket to the Compute Node.png" alt="Download sample file from Read Only S3 Bucket to the Compute Node">
  <br>
  <em>Download sample file from Read Only S3 Bucket to the Compute Node</em>
</p>

Users have write access to the enclave-prefix-researchgroupname-out bucket and can upload files to this bucket if they would like to export files. Then the data custodians can review the uploaded files and approve/reject the export attempt.

<p align="center">
  <img src="images/Upload Sample File to the Write Only S3 Bucket.png" alt="Upload Sample File to the Write Only S3 Bucket">
  <br>
  <em>Upload Sample File to the Write Only S3 Bucket</em>
</p>

<p align="center">
  <img src="images/Write Only Enclave S3 Bucket.png" alt="Write Only Enclave S3 Bucket">
  <br>
  <em>Write Only Enclave S3 Bucket</em>
</p>


### User Access to Python and R libraries

The following websites were added to the Squid-Proxy/sites.allowlist.txt for the Squid Proxy by default:

.files.pythonhosted.org

.cloud.r-project.org

.pypi.python.org

.pypi.org

Using the Firefox browser, testers can verify that the users can download libraries from Pypi and CRAN, but they do not have access to websites such as www.google.com in the following figures.

<p align="center">
  <img src="images/Proxy Allowing Access to Python and R Libraries.png" alt="Proxy Allowing Access to Python and R Libraries">
  <br>
  <em>Proxy Allowing Access to Python and R Libraries</em>
</p>

<p align="center">
  <img src="images/Proxy Refusing Access to Sites not on the Allowlist.png" alt="Proxy Refusing Access to Sites not on the Allowlist">
  <br>
  <em>Proxy Refusing Access to Sites not on the Allowlist</em>
</p>