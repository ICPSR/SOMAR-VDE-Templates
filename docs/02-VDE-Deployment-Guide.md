# Virtual Data Enclave (VDE) Deployment Guide

## Table of Contents
- [Deployment Instructions](#deployment-instructions)
- [enclave-admin.yaml CloudFormation Template](#enclave-adminyaml-cloudformation-template)
- [Upload Required Files to S3](#upload-required-files-to-s3)
  - [ec2-image-builder-map.yaml](#ec2-image-builder-mapyaml)
  - [enclave-constants.yaml](#enclave-constantsyaml)
  - [lab-constants.yaml](#lab-constantsyaml)
  - [ec2-powerstate.zip](#ec2-powerstatezip)
- [AMI Build Using EC2 Image Builder](#ami-build-using-ec2-image-builder)
  - [Provisioned Image Components](#provisioned-image-components)
  - [Stack Deployment Instructions](#stack-deployment-instructions)
- [enclave-vpc.yaml CloudFormation Template](#enclave-vpcyaml-cloudformation-template)
- [Squid Proxy Deployment Using Docker](#squid-proxy-deployment-using-docker)
- [enclave-proxy.yaml CloudFormation Template](#enclave-proxyyaml-cloudformation-template)
- [AWS Client VPN Set Up](#aws-client-vpn-set-up)
  - [Prerequisites](#prerequisites)
  - [client-vpn.yaml CloudFormation Template](#client-vpnyaml-cloudformation-template)
  - [Post Deployment Steps](#post-deployment-steps)
- [enclave-lab.yaml CloudFormation Template](#enclave-labyaml-cloudformation-template)
- [ec2-endpoint.yaml CloudFormation Template](#ec2-endpointyaml-cloudformation-template)

## Deployment Instructions

The VDE infrastructure is defined and provisioned using [AWS CloudFormation templates](../AWS-Replication-Templates/) maintained in the project GitHub repository.

The deployment instructions below outline the minimum steps required to deploy a single lab environment. For more detailed instructions and information about the resources being provisioned, please refer to the later sections of this document.

1. **Deploy the [`enclave-admin.yaml`](../AWS-Replication-Templates/enclave-admin.yaml) CloudFormation Template**

   The template provisions core administrative resources. The operator must provide a role or user ARN as a parameter, which will be used to administer the created KMS key.

2. **Upload the following files from the SOMAR-VDE-Replication GitHub repository to the root level of the `enclave-templates-<aws-account-number>-<region-name>` S3 Bucket (do not upload them into a constants/ folder or any other subfolder):**
   1. [ec2-powerstate.zip](../ec2-powerstate.zip)
   2. [AWS-Replication-Templates/constants/ec2-image-builder-map.yaml](../AWS-Replication-Templates/constants/ec2-image-builder-map.yaml)
   3. [AWS-Replication-Templates/constants/enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml)
   4. [AWS-Replication-Templates/constants/lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml)

3. **Deploy the [`ec2-image-builder.yaml`](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation Template**

   This template provisions EC2 Image Builder resources used to create customized AMIs. The deployment of this CloudFormation template may take approximately 40 minutes to complete.

4. **Deploy the [`enclave-vpc.yaml`](../AWS-Replication-Templates/enclave-vpc.yaml.yaml) CloudFormation Template**

   This template provisions core networking resources, including the VPC and associated subnets.

5. **Build and push the Squid Proxy container image**

   Follow the instructions in the [Squid Proxy Deployment Using Docker](#squid-proxy-deployment-using-docker) section to build the Squid Proxy image and push it to your AWS Elastic Container Registry (ECR) repository.

6. **Deploy the [`enclave-proxy.yaml`](../AWS-Replication-Templates/enclave-proxy.yaml) CloudFormation Template**

   This template provisions proxy related resources.

7. **Create and upload VPN certificates**

   Follow the instructions in the [Prerequisites](#prerequisites) under the [AWS Client VPN Set Up](#aws-client-vpn-set-up) section to generate the required certificates and upload them to AWS Certificate Manager (ACM).

8. **Deploy the [`client-vpn.yaml`](../AWS-Replication-Templates/client-vpn.yaml) CloudFormation Template**

   This template provisions AWS Client VPN resources for secure remote access. The operator must provide the ARNs of the client and server certificates uploaded to AWS ACM in the previous step as parameters.

9. **Configure the AWS Client VPN Desktop Client**

   Follow the instructions in the [Post Deployment Steps](#post-deployment-steps) under the [AWS Client VPN Set Up](#aws-client-vpn-set-up) section to set up the AWS Client VPN Desktop client.

10. **Create an EC2 key pair**

    Using Key Pairs under Network & Security in the Amazon EC2 Console, create a .pem key pair with RSA as the key type and name it **enclave-test-keypair**. Download the key file to your local Computer.

11. **Deploy the [`enclave-lab.yaml`](../AWS-Replication-Templates/enclave-lab.yaml) CloudFormation Template**

    This template provisions the resources required for a single research lab environment.


To deploy additional lab environments:

1. Repeat Step 2 to rename and upload a new [`AWS-Replication-Templates/constants/lab-constants.yaml`](../AWS-Replication-Templates/constants/lab-constants.yaml) file to the root level of the enclave-templates S3 bucket.
2. Repeat step 11 to deploy the [`enclave-lab.yaml`](../AWS-Replication-Templates/enclave-lab.yaml) CloudFormation Template.

This sequence ensures that foundational AMIs, administrative and networking components are created before dependent proxy, VPN, and lab resources are deployed. The following figure illustrates the CloudFormation stack deployment orders. Detailed set up instructions are provided in the sections below.

<p align="center">
  <img src="images/AWS CloudFormation Stack Deployment Orders.png" alt="AWS CloudFormation Stack Deployment Orders">
  <br>
  <em>AWS CloudFormation Stack Deployment Orders</em>
</p>

Instructions for testing the deployed lab environment are included in the [`04-End-User-Testing.md`](04-End-User-Testing.md) .

## [enclave-admin.yaml](../AWS-Replication-Templates/enclave-admin.yaml) CloudFormation Template

**Prerequisites**

* An AWS role/user to create the resources in the `enclave-admin.yaml` CloudFormation template.
* An AWS role to administer and manage the created KMS key.

**Provisioned Resources**

The `enclave-admin.yaml` template provisions the following AWS resources:

**KMS customer managed key**

* To encrypt EBS volume for bastion and its associated compute node.
* Includes an alias `KeyAlias` from input parameter.
* A key policy that
  + Grants admin permissions to a `AdminRoleArn` specified from input parameter.
  + Allows EC2 services to use the key for EBS encryption at launch of the instances.
  + Allows EC2 Instance roles to temporarily have permissions to use the KMS key.

**CloudFormation Admin Role**

CloudFormation can assume to create resources with admin access.

**Enclave Template Bucket**

An S3 bucket to store CloudFormation templates and files about constants.

**Logging Bucket**

An S3 bucket to receive S3 access logs from other S3 buckets.

**Stack Deployment Instructions**

<p align="center">
  <img src="images/enclave-admin.yaml CloudFormation Template Parameters.png" alt="enclave-admin.yaml CloudFormation Template Parameters">
  <br>
  <em>enclave-admin.yaml CloudFormation Template Parameters</em>
</p>

To deploy the administrative stack in CloudFormation, the operator must provide the ARN of the IAM role created as part of the prerequisites to perform administration actions on the KMS key.

## Upload Required Files to S3

There are three files and one zipped file that contain constants located in the SOMAR-VDE-Replication GitHub repository under:

* [AWS-Replication-Templates/constants/ec2-image-builder-map.yaml](../AWS-Replication-Templates/constants/ec2-image-builder-map.yaml)
* [AWS-Replication-Templates/constants/enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml)
* [AWS-Replication-Templates/constants/lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml)
* [ec2-powerstate.zip](../ec2-powerstate.zip)

These files must be updated as required and uploaded to the root level of the `enclave-templates-<aws-account-number>-<region-name>` S3 bucket created by the [`enclave-admin.yaml`](../AWS-Replication-Templates/enclave-admin.yaml) CloudFormation Template, before deploying any other CloudFormation templates. The constant values defined in these files are mapped and referenced by other CloudFormation templates later in the deployment process.

Important: The files must be placed at the top level of the bucket. Do not create a `constants/` folder in the S3 bucket.

<p align="center">
  <img src="images/Enclave Templates S3 Bucket.png" alt="enclave-templates-<aws-account-number>-<region-name> S3 Bucket">
  <br>
  <em>Enclave Templates S3 Bucket</em>
</p>

### [ec2-image-builder-map.yaml](../AWS-Replication-Templates/constants/ec2-image-builder-map.yaml)

The contents of the `ec2-image-builder-map.yaml` file shown in the following figure define the base AWS AMI Image name and version used by the [`ec2-image-builder.yaml`](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation template to build the AMIs to be used for the **bastion**, **proxy** and **compute node** instances.

<p align="center">
  <img src="images/ec2-image-builder-map.yaml File.png" alt="ec2-image-builder-map.yaml File">
  <br>
  <em>ec2-image-builder-map.yaml File</em>
</p>

At the time this document was created, the following base images were used by default:

* Bastion Base Image: Windows Server 2022 (released on 2025.9.10)
* Node and Proxy Image: Ubuntu Server 22.04 LTS (x86) (released on 2025.9.25)

Note: Operators should verify that the specified image versions exist and are available in the target AWS Region at the time of deployment. In most cases, the latest listed image version in EC2 Image Builder is available and launchable in the target AWS Region. However, in some rare cases, images may still appear in the EC2 Image Builder console but are no longer launchable or accessible, which can cause image build failures.

<p align="center">
  <img src="images/Windows Server 2022 Base Image.png" alt="Windows Server 2022 Base Image">
  <br>
  <em>Windows Server 2022 Base Image</em>
</p>

<p align="center">
  <img src="images/Ubuntu Server 22.04 LTS Base Image.png" alt="Ubuntu Server 22.04 LTS Base Image">
  <br>
  <em>Ubuntu Server 22.04 LTS Base Image</em>
</p>

To build the bastion AMI, the zipped file [`ec2-powerstate.zip`](../ec2-powerstate.zip) must be uploaded to the `enclave-templates-<aws-account-number>-<region-name>` S3 bucket.

### [enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml)

The contents of the `enclave-constants.yaml` file shown in the following figure define the constants used for setting up the networking stack such as the name and the 2 CIDR ranges of the VPC.

<p align="center">
  <img src="images/enclave-constants.yaml File.png" alt="enclave-constants.yaml File">
  <br>
  <em>enclave-constants.yaml File</em>
</p>

Definition of the constants:

* **Common**
  + **EnclavePrefix:** A prefix used for resource naming (for example, `umich` for the University of Michigan). This value is incorporated into the names of the S3 input and output buckets for each research lab group, as well as the proxy security group and instance.
* **Network**
  + **VPCName:** Name of the enclave VPC.
  + **VpcCidrBlock:** CIDR block used to host the bastion and compute node private subnets.
  + **PublicCidrBlock:** CIDR block used to host the proxy public subnet.
* **Proxy**
  + **InstanceType:** EC2 Instance type for the proxy.
  + **KeyName:** Name of the key-pair created for the proxy EC2 instance.
  + **PrivateIpAddress:** Private IPv4 addresses assigned to the proxy EC2 instance.
  + **ProxyBastionPort:** Port used for traffic from the bastion instances to the proxy.
  + **ProxyNodePort:** Port used for traffic from the compute node instances to the proxy.
  + **Name:** Name of the proxy.

### [lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml)

The `lab-constants.yaml` file defines configuration constants for the bastion and compute nodes, such as the lab name (e.g., the name of the research group). When deploying multiple labs, each `lab-constants.yaml` file is renamed (e.g., `<researcher>-lab-constants.yaml`) and uploaded by the Operator to the designated S3 template bucket used by the [`enclave-lab.yaml`](../AWS-Replication-Templates/enclave-lab.yaml) CloudFormation Template.

Definition of the constants:

* **Attributes**
  + **Name:** Defines base name used for the bastion and node instance, security groups, and instance profile.
  + **MComm:** Value used to associate a bastion instance with its corresponding lab node. This tag allows the bastion node to identify and control the power state of the associated node instance.
* **Bastion**
  + **KeyName:** EC2 Key pair name to launch bastion instance.
  + **InstanceType:** Instance type of the bastion instance.
* **Node**
  + **KeyName:** EC2 Key pair name to launch compute node instance.
  + **InstanceType:** Instance type of the compute node.

<p align="center">
  <img src="images/lab-constants.yaml File.png" alt="lab-constants.yaml File">
  <br>
  <em>lab-constants.yaml File</em>
</p>

The **KeyName** values must match an existing EC2 key pair name in the AWS Region where the resources are deployed. The EC2 key pair must be created before deploying the `enclave-lab.yaml` CloudFormation Template. To create an EC2 key pair:

* Navigate to `EC2 → Network & Security → Key Pairs` in the AWS Management Console, as shown in the follwing figure.
* Select **Create key pair**, configure the key pair with **Key pair type =** RSA, and specify a Key pair name that matches the KeyName value defined in `lab-constants.yaml` (for example, enclave-test-keypair). Then create the key pair.
* The .pem file will be downloaded automatically by your browser. Store this file securely on your local machine. For example, move it to a secure directory (such as `~/.ssh/`) and restrict its permissions using chmod 400 to ensure that only the current user can access the key. This file is required later to retrieve the **Windows Bastion instance credentials** in the [04-End-User-Testing.md](04-End-User-Testing.md).

<p align="center">
  <img src="images/EC2 Key Pairs AWS Console.png" alt="EC2 Key Pairs AWS Console">
  <br>
  <em>EC2 Key Pairs AWS Console</em>
</p>

**Important:** The private key file can only be downloaded at the time the key pair is created. If the file is lost, it cannot be downloaded again, and a new key pair must be created and associated with the instance.

### [ec2-powerstate.zip](../ec2-powerstate.zip)

The `ec2-powerstate.zip` contains the [Windows PowerShell scripts](../ARC-EC2-Powerstate/ec2-powerstate_gui.ps1) and AWS Modules to allow users to start/stop the node EC2 instances, and start a RDC client process to connect to the remote node EC2. The script has the following 2 functionalities:

* Allow Power State Management of EC2 instances with AWS EC2 VPC endpoint established. This allows users to power/stop the Node Instances by clicking the `START STOP VM` icon from the Desktop. When user clicks the `START STOP VM`, the [ec2-powerstate_gui.ps1](../ARC-EC2-Powerstate/ec2-powerstate_gui.ps1) script is executed, and users can send the EC2 start/stop APIs via AWS PowerShell modules via a graphical interface. To ensure the correct node instance is identified by the PowerShell script, the bastion and its associated node instance must share the same mcomm tag key values. The mcomm tag value is defined in the [`lab-constants.yaml`](../AWS-Replication-Templates/constants/lab-constants.yaml).
* Allow users to launch an RDC (Remote Desktop Connection) client session by clicking the Launch RDC button for the selected Node Instances if the host is running. This is done by extracting the Node Instance IP address and starting a RDC process with the extracted IP:

```ps1
$RDPButton.Add_Click({
    $RDPIP = ($ListBox.SelectedItem).split("`t")[2] -replace '.*\[(\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b)\].*','$1'
    start-process -filepath "mstsc" -ArgumentList "/v:$RDPIP"
})
```

Note: The PowerState PowerShell script requires access to EC2 instance metadata. When using Windows Server 2025 as the bastion base image, the EC2 instance metadata option HttpTokens must be set to Optional (IMDSv2 not enforecd). This configuration is applied in the `enclave-lab.yaml` CloudFormation Template to ensure the script can successfully make EC2 API calls.

## AMI Build Using EC2 Image Builder

The primary purpose of the [ec2-image-builder.yaml](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation template is to reduce operator time and effort by automating the creation of reusable, standardized Amazon Machine Images (AMIs). Instead of manually launching and configuring EC2 instances to create images, operators can use the AMIs produced by **EC2 Image Builder** as a consistent starting point for **node, proxy and bastion** instances. This approach also simplifies and accelerates image distribution across environments and regions.

### Provisioned Image Components

The [ec2-image-builder.yaml](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation template provisions the required infrastructure to automatically build custom Amazon Machine Images (AMIs) using the **EC2 Image Builder** service. The template creates basic networking resources including a VPC and public subnet, which are used by the Image Builder during the AMI build process. These resources allow Image Builder to launch temporary EC2 instances that perform the AMI build and configuration steps.

The [ec2-image-builder.yaml](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation template also defines **Image Builder components**, which specify the software and configuration applied during the image build process.

**Node Image Components**

The node image build uses Bash scripts to install and configure the following:

* System and desktop utilities
* Developer and runtime dependencies
* Data Analysis tools and libraries

This process produces an **Ubuntu 22.04 LTS AMI** used by node instances, with Ubuntu Desktop and base software preinstalled, as shown in the table below:

<div align="center">
Table Node Image Builder Components

|  |  |  |  |
| --- | --- | --- | --- |
| **Component** | **Software Installed** | **Configuration Applied** | **Purpose** |
| NodeInstallSSMAgent | amazon-ssm-agent (via snap) | Enables and starts snap.amazon-ssm-agent.amazon-ssm-agent.service | Allows the instance to communicate with AWS Systems Manager so Image Builder and SSM RunCommand can execute build steps. |
| NodeBase | vlc, cmake, libfontconfig1, awscli | Runs apt-get update before installation | Provides base system utilities: multimedia (vlc), build tooling (cmake), font library support, and AWS CLI for interacting with AWS services. |
| NodeUbuntuDesktop | ubuntu-desktop, xrdp | Enables xrdp service | Installs full GUI desktop environment and enables remote desktop access (RDP). |
| NodeR | r-base, r-base-dev | None beyond R package installation | Installs the R statistical computing environment and development libraries. |
| NodeRStudio | wget, rstudio-server (downloaded .deb) | Enables rstudio-server systemd service | Installs RStudio Server so users can access R via a web interface. |
| NodeJupyter | python3-pip, notebook, jupyterlab (via pip) | Installs Python Jupyter tools system-wide | Provides Jupyter Notebook / JupyterLab environment for interactive Python or R analysis. |
</div>

**Windows Image Component**

The Windows build component performs the following actions:

* Downloads the [ec2-powerstate.zip](../ec2-powerstate.zip) that contain the [PowerState PowerShell script](../ARC-EC2-Powerstate/ec2-powerstate_gui.ps1) and modules from the `enclave-templates-<aws-account-number>-<region-name>` S3 bucket.
* Extracts
  + The PowerState PowerShell script
  + AWS PowerShell modules
* Installs AWS modules system-wide.
* Creates a desktop shortcut on the Public Desktop that allows all users to launch a graphic user interface (GUI) using the [PowerShell script ec2-powerstate\_gui.ps1](../ARC-EC2-Powerstate/ec2-powerstate_gui.ps1) to control the node instance states.

This produces a Windows Server 2022 AMI used by bastion instances with a ready to use EC2 start/stop GUI.

**Proxy Image Component**

The proxy image build uses Bash scripts to install and configure the following components:

* Docker Engine for running the Squid Proxy container.
* AWS CLI for interacting with AWS services during proxy configuration and operation.

This process produces a hardened proxy AMI that includes the required container runtime and AWS tooling. The AMI is used by proxy instances to run the Squid Proxy container image stored in Amazon Elastic Container Registry (ECR). Preinstalling these components ensures that proxy instances can quickly retrieve and run the container image during instance initialization without requiring additional manual configuration.

### Stack Deployment Instructions

To deploy the `ec2-image-builder.yaml` CloudFormation template stack, the name of the `ec2-image-builder-map.yaml` file under the Parameters must be provided. The `ec2-image-builder-map.yaml` must be uploaded to the `enclave-templates-<aws-account-number>-<region-name>` S3 bucket.

<p align="center">
  <img src="images/ec2-image-builder.yaml CloudFormation Template Parameters.png" alt="ec2-image-builder.yaml CloudFormation Template Parameters">
  <br>
  <em>ec2-image-builder.yaml CloudFormation Template Parameters</em>
</p>


The EC2 Image Builder template typically completes in approximately 40 minutes. Operators can monitor the build progress by selecting the image in the EC2 Image Builder console and navigating to the Workflow tab. This view displays the status of the build, the steps that have been completed, and any errors encountered during the image creation process, as illustrated in the following figure.

<p align="center">
  <img src="images/EC2 Image Builder Workflow.png" alt="EC2 Image Builder Workflow">
  <br>
  <em>EC2 Image Builder Workflow</em>
</p>

Once the builds are finished, the resulting AMI Ids for the node, bastion and proxy images can be found in the Images section of the console by clicking on the name of each image. Additionally, the AMI IDs are exported as stack outputs, allowing them to be referenced by the proxy and lab CloudFormation templates.

<p align="center">
  <img src="images/EC2 Image Builder Images.png" alt="EC2 Image Builder Images">
  <br>
  <em>EC2 Image Builder Images</em>
</p>

## [enclave-vpc.yaml](../AWS-Replication-Templates/enclave-vpc.yaml) CloudFormation Template

This template creates

**VPC:**

* A Virtual Private Cloud for the enclave environment with DNS support and hostnames enabled.
* Default Classless Inter-Domain Routing (CIDR): 10.236.170.0/24

**VPC CIDR Block:**

* Associates an additional public CIDR block with the VPC.
* Default CIDR: 10.255.0.0/20

**Enclave Flow Log IAM Role:**

* A role that allows VPC flow logs to be stored in CloudWatch.

**VPC Flow Log:**

* Logs all network traffic within the VPC to CloudWatch using the specified IAM role.

**Internet Gateway:**

* Provides the VPC with internet connectivity.

**VPC Gateway Attachment:**

* Attaches the Internet Gateway to the VPC.

**Subnets:**

The bastion and node subnet CIDR by default each takes a total number of 123 IP addresses, if there is a need to deploy more than 123 node and bastion machines, the CIDR will need to be modified based on the organization needs for scaling.

* **BastionSubnet:** A private subnet for Bastion nodes.
  + Default CIDR: 10.236.170.0/25
* **NodeSubnet:** A private subnet for compute nodes.
  + Default CIDR: 10.236.170.128/25
* **PublicSubnet:** A public subnet for proxy instances.
  + Default CIDR: 10.255.0.0/20

**Route Tables and Associations:**

* **BastionRouteTable & Association:** Routes for the bastion subnet.
* **NodeRouteTable & Association:** Routes for the compute nodes subnet.
* **PublicRouteTable, Association, and Route:** Routes for the public subnet, including a route to the Internet Gateway.

**VPC Endpoints:**

* **EC2Endpoint:** An interface endpoint for EC2 service in the bastion subnet.
* **S3Endpoint:** A gateway endpoint for the S3 service utilizing the node route table.

**EC2 Endpoint Security Group:**

* A security group that allows HTTPS traffic within the enclave network.

**EC2 Endpoint Security Group Ingress Rule:**

* Enables inbound HTTPS traffic through port 443 for the EC2 endpoint.

<p align="center">
  <img src="images/enclave-vpc.yaml CloudFormation Template Parameters.png" alt="enclave-vpc.yaml CloudFormation Template Parameters">
  <br>
  <em>enclave-vpc.yaml CloudFormation Template Parameters</em>
</p>

A visual representation of the resources generated in the VPC template can be viewed inside the Amazon VPC console and should have a similar output as shown in the following figure.

<p align="center">
  <img src="images/Enclave VPC Resource Map.png" alt="Enclave VPC Resource Map">
  <br>
  <em>Enclave VPC Resource Map</em>
</p>

## Squid Proxy Deployment Using Docker

Prerequisite

* Docker is installed and running on the workstation used to build the image.
* AWS CLI is installed and configured with credentials that have permission to access Amazon ECR.
* A private Amazon ECR repository has been created in the target AWS Region to store the Squid Proxy image.
* Change to the [`Squid-Proxy`](../Squid-Proxy/) directory in the cloned GitHub repository before executing the build commands.
* Review and update [`Squid-Proxy/sites.allowlist.txt`](../Squid-Proxy/sites.allowlist.txt) to include the domains that enclave users should be permitted to access through the proxy.

For the proxy deployment, the Squid-Proxy image must be built and pushed to a private repository in AWS ECR repository before deploying the proxy CloudFormation template. The proxy EC2 instance later pulls the image from ECR during initialization through its user data script.

After updating the allowlist file and creating the ECR repository, the operator can navigate to the repository in the Amazon ECR console and select **View push commands** to obtain the authentication, build, tag and push commands. Execute the displayed commands from the Squid-Proxy directory to build and push the image to the repository.

<p align="center">
  <img src="images/AWS ECR Authentication and Push Commands for macOSLinux.png" alt="AWS ECR Authentication and Push Commands">
  <br>
  <em>AWS ECR Authentication and Push Commands for macOS/Linux</em>
</p>

Note: The Proxy EC2 Image created by the Image Builder uses Ubuntu Server 22.04 LTS x86_64(amd64) AMI. Therefore, the Docker image must include a `linux/amd64` image. If the image only contains an `arm64` manifest, `docker pull` will fail with `"no matching manifest for linux/amd64 in the manifest list entries"` error. Rebuilding and publishing the Docker image with an `amd64` manifest using Docker Buildx resolves this issue:
```bash
docker buildx build \
  --platform linux/amd64 \
  -t <aws-account-number>.dkr.ecr.<aws-region>.amazonaws.com/enclave-squid-proxy:latest \
  --push .
```


## [enclave-proxy.yaml](../AWS-Replication-Templates/enclave-proxy.yaml) CloudFormation Template

The current Squid Proxy deployment uses EC2 and ECR for simplicity. However, alternative configurations such as using ECS with ECR are also possible. The `enclave-proxy.yaml` CloudFormation Template assumes the name of the key pair is specified in the `enclave-constants.yaml` file.

This template creates

**Proxy EC2 Instance:**

* An EC2 instance configured to serve as a proxy using a specific AMI created by the [ec2-image-builder.yaml](../AWS-Replication-Templates/ec2-image-builder.yaml) CloudFormation template and instance type fetched from the [enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml). The [enclave-proxy.yaml](../AWS-Replication-Templates/enclave-proxy.yaml) CloudFormation template includes user data that installs Docker and the AWS CLI and starts a Docker container running as a squid proxy.

**IAM Role and Instance Profile:**

* **ProxyEC2Role:** An IAM role that grants the EC2 instance permission to access Amazon Elastic Container Registry (ECR) to pull Docker images.
* **ProxyEC2InstanceProfile:** An IAM instance profile associated with the ProxyEC2Role, allowing the EC2 instance to assume the role and use the specified ECR permissions.

**EC2 Key Pair:**

* **EnclaveProxyLocalKey:** An EC2 Key Pair used to SSH into the proxy node instance for updating the Squid Proxy Docker image or performing troubleshooting when necessary. The key name is retrieved from the [enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml).

**Elastic IP (EIP):**

* **ProxyEIP:** An Elastic IP address associated with the proxy EC2 instance, allowing it to have a static IP address since the proxy is hosted in a public subnet.

**Security Group:**

* **ProxySecurityGroup:** A security group created for the EC2 instance, which will have specific ingress rules to control traffic.

**ProxyBastionIngress and ProxyNodeIngress:** Security Group rules specify network access within the security group, for specific ports (`ProxyBastionPort 3128` and `ProxyNodePort 3129`) defined in the [enclave-constants.yaml](../AWS-Replication-Templates/constants/enclave-constants.yaml).

<p align="center">
  <img src="images/enclave-proxy.yaml CloudFormation Template Parameters.png" alt="enclave-proxy.yaml CloudFormation Template Parameters">
  <br>
  <em>enclave-proxy.yaml CloudFormation Template Parameters</em>
</p>

## AWS Client VPN Set Up

This section guides operators through creating and using an AWS Client VPN with certificate-based mutual authentication to securely access the Windows Bastion EC2 instances located in a private subnet.

For testing, evaluation, and lab environments, mutual authentication provides a straightforward way to secure VPN access using client and server certificates. Mutual authentication does not require ownership of a real domain name. Operators may generate certificates using tools such as EasyRSA with arbitrary common names, provided that the client and server certificates are signed by the trusted Certificate Authority (CA) configured for the AWS Client VPN endpoint.

For production environments, it is recommended to use Single sign-on (SSO) or Active Directory based authentication to further improve security and simplify user management. Federated authentication removes the need to distribute .ovpn files that contain certificates and private keys to end users.

### Prerequisites

**Generate Certificates**

Before deploying the Client VPN endpoint, operators must generate server and client certificates and keys, and upload them to AWS Certificate Manager (ACM).

Follow the steps in the AWS document to enable mutual authentication for AWS Client VPN: <https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-auth-mutual-enable.html>

**Upload Certificates to AWS Certificate Manager (ACM)**

This procedure uses OpenVPN easy-rsa to generate the certificates and private keys required for mutual authentication. After completing the steps, import the following certificates into AWS Certificate Manager (ACM):

* The server certificate and private key
* The client certificate and private key

Use the AWS CLI commands below and replace the `aws-region` placeholder to import the certificates. Ensure that all certificates are uploaded to the same AWS Region where the Client VPN endpoint will be created.

```
aws acm import-certificate --certificate fileb://server.crt --private-key fileb://server.key --certificate-chain fileb://ca.crt --region <aws-region>

aws acm import-certificate --certificate fileb://client1.domain.tld.crt --private-key fileb://client1.domain.tld.key --certificate-chain fileb://ca.crt --region <aws-region>
```

<p align="center">
  <img src="images/AWS ACM Client VPN Server and Client Certificate.png" alt="AWS ACM Client VPN Server and Client Certificate">
  <br>
  <em>AWS ACM Client VPN Server and Client Certificate</em>
</p>


### [client-vpn.yaml](../AWS-Replication-Templates/client-vpn.yaml) CloudFormation Template

Deploy the `client-vpn.yaml` CloudFormation template to create the Client VPN infrastructure. The template provisions the following resources:

* **AWS Client VPN endpoint**
  + Uses a default Client IPv4 CIDR of 172.16.0.0/22.
    (The address range cannot overlap with the target network address range, the VPC address range, or any of the routes that will be associated with the Client VPN endpoint)
  + Uses the server certificate uploaded to ACM.
  + Uses the client certificate uploaded to ACM with mutual authentication enabled.
  + Associates the VPN endpoint with the bastion subnet.
  + Creates an authorization rule with the target network CIDR set to the bastion subnet CIDR. (default: 10.236.170.0/25)

* **Security Group**
  + Allows outbound traffic.
  + Associates with the Client VPN endpoint.

When deploying the CloudFormation stack, operators must provide the following parameters:

* The ARN of the server certificate uploaded to ACM.
* The ARN of the client certificate uploaded to ACM.

<p align="center">
  <img src="images/client-vpn.yaml CloudFormation Template Parameters.png" alt="client-vpn.yaml CloudFormation Template Parameters">
  <br>
  <em>client-vpn.yaml CloudFormation Template Parameters</em>
</p>


### Post Deployment Steps

After the Client VPN stack deployment completes, operators must perform the following additional steps.

**Step 1: Download and Configure the Client VPN Configuration File**

From the Client VPN Endpoints section in the AWS Console, select the endpoint and click **Download client configuration** to obtain the .ovpn file. The configuration file includes the Client VPN endpoint details and certificate information required to establish a VPN connection.

<p align="center">
  <img src="images/Download AWS Client VPN Configuration File.png" alt="Download AWS Client VPN Configuration File">
  <br>
  <em>Download AWS Client VPN Configuration File</em>
</p>

**Step 2: Add Client Certificate and Key to the .ovpn File**

Locate the client certificate and key that were generated in the prerequisite step. The client certificate and key are typically found in the following locations in the cloned OpenVPN easy-rsa repository:

* Client certificate — `easy-rsa/easyrsa3/pki/issued/client1.domain.tld.crt`
* Client key — `easy-rsa/easyrsa3/pki/private/client1.domain.tld.key`

Open the downloaded .ovpn client VPN endpoint configuration file using your preferred text editor as shown the following figure. Add `<cert></cert>` and `<key></key>` tags to the file. Place the contents of the client certificate and the contents of the private key between the corresponding tags.

<p align="center">
  <img src="images/Client VPN Endpoint Configuration File.png" alt="Client VPN Endpoint Configuration File">
  <br>
  <em>Client VPN Endpoint Configuration File</em>
</p>

Save and close the Client VPN endpoint configuration file.

**Step 3: Distribute the Client VPN endpoint configuration file to your end users.**

This file will be required to configure the client VPN that is used to connect to the bastion instance. Additional information is included in the [04-End-User-Testing.md](04-End-User-Testing.md)

## [enclave-lab.yaml](../AWS-Replication-Templates/enclave-lab.yaml) CloudFormation Template

This template creates:

* **Bastion Host:**
  + **Bastion (EC2 Instance):**
    - An EC2 instance acting as a bastion host for a research group, which provides a secure way for user to access their node instance in the VPC. The bastion is deployed inside the private bastion subnet.
    - The AMI and instance type are specified in the [ec2-image-builder-map.yaml](../AWS-Replication-Templates/constants/ec2-image-builder-map.yaml) and [lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml) files.
    - Can be accessed using an EC2 Key Pair specified in the [lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml) file.
    - Tagged with specific metadata such as name and mcomm tags. The mcomm tags are used so that the end users can use the EC2 PowerState PowerShell scripts in the bastion to control the state of their compute node.
    - To reduce the risk of unauthorized data transfer between local workstations and the Virtual Data Enclave, Remote Desktop Protocol (RDP) resource redirection features should be disabled on Windows bastion hosts. At a minimum, clipboard, local drive, and printer redirection should be blocked through Group Policy on Windows bastion hosts. The recommended approach for managing these settings at scale is through Active Directory Group Policy. These security hardening configurations are **not** included in the provided CloudFormation templates because Active Directory deployments, domain structures and organizational unit configurations vary across institutions, and bastion hosts must be joined to an organization's Active Directory domain before domain-level Group Policy settings can be applied.
* **Compute Node:**
  + **Node (EC2 Instance):**
    - A general compute EC2 instance within the lab environment for a research group.
    - The AMI is referenced from the output of the EC2 Image Builder CloudFormation stack and the instance type is specified in the [lab-constants.yaml](../AWS-Replication-Templates/constants/lab-constants.yaml) file.
    - Each node takes an input for the following user data, including proxy configurations and setting up the environment for security and access.
    - The ubuntu password is provided via a **NoEcho** CloudFormation parameter during stack creation and injected into the user data script at instance launch. In AWS CloudFormation, the **NoEcho** property masks the parameter value in the console and stack logs to prevent sensitive information from being displayed. This allows the system administrator to use the password to log in to the node instance and perform administrative tasks.

* **IAM Roles and Instance Profiles:**
  + **BastionEC2Role and NodeEC2Role:**
    - Roles with permissions allowing instances to interact with AWS resources such as EC2 and S3.
    - Policies enable actions such as describing and managing instances, and handling S3 buckets.
    - Includes permissions on key management for secure communications.
  + **BastionEC2InstanceProfile and NodeEC2InstanceProfile:**
    - Associate the roles with the EC2 instances allowing them to use the assumed permissions.
* **Security Groups:**
  + **BastionSecurityGroup and NodeSecurityGroup:**
    - Security groups define permissible traffic to and from the bastion and node instances.
    - Ingress rules permit certain types of traffic, such as RDP access to the bastion and internal connectivity between instances.
* **S3 Buckets:**
  + **LabBucketIn and LabBucketOut:**
    - Two S3 buckets for data input and output in the lab environment.
    - Configured with server-side encryption using KMS.
    - Logging is enabled to store access logs inside the `enclave-logging` bucket.
    - Versioning is enabled to keep track of object versions.
  + Note: After deploying each lab template, there may be a brief propagation delay before traffic can successfully reach the S3 buckets. During this period, initial connection attempts may time out. This behavior is expected, connectivity typically stabilizes within several hours without further configuration changes.

Operators must provide the ubuntu password for administration, the name of the `lab-constants.yaml` and `enclave-constants.yaml` file that were uploaded to the enclave template S3 bucket, as shown in the figure below when deploying the template.

<p align="center">
  <img src="images/enclave-lab.yaml CloudFormation Template Parameters.png" alt="enclave-lab.yaml CloudFormation Template Parameters">
  <br>
  <em>enclave-lab.yaml CloudFormation Template Parameters</em>
</p>

## [ec2-endpoint.yaml](../AWS-Replication-Templates/ec2-endpoint.yaml) CloudFormation Template

Optionally, if an operator/tester needs to validate the infrastructure and access the enclave bastion instance in a private subnet without configuring a VPN connection, this template stack can be deployed for testing purposes. The stack provisions a EC2 Instance Connect Endpoint (EICE) within the VPC, enabling secure, temporary connectivity from the AWS managed EC2 Instance Connect service to instances over RDP.

EC2 EICE is intended primarily for administrative access and testing, not for regular end-user access patterns. EICE is ideal for testing and development environment, as it allows operators to quickly access private EC2 instances directly from their local machines via AWS CLI while keeping the instances isolated from the public internet. However, because access is IAM based and does not integrate with enterprise identity systems, this approach may not align with enterprise identity or compliance requirements.

<p align="center">
  <img src="images/EC2 Instance Connect Endpoint (EICE) Architecture Diagram.png" alt="EC2 Instance Connect Endpoint (EICE) Architecture Diagram">
  <br>
  <em>EC2 Instance Connect Endpoint (EICE) Architecture Diagram</em>
</p>

The following CloudFormation parameters are required:

* Bastion security group ID
* Bastion subnet ID
* VPC ID

<p align="center">
  <img src="images/EC2 Endpoint CloudFormation Template Parameters.png" alt="EC2 Endpoint CloudFormation Template Parameters">
  <br>
  <em>EC2 Endpoint CloudFormation Template Parameters</em>
</p>

After the template is deployed, the tester must manually add the security group associated with the EC2 Instance Connect Endpoint to the **ingress rules** of the bastion's security group to allow inbound traffic. Once this is configured, the tester can follow the instructions in the [04-End-User-Testing.md](04-End-User-Testing.md) to validate access to the bastion and compute node.

<p align="center">
  <img src="images/Bastion SG Inbound Rules attachment with EC2 Endpoint SG.png" alt="Bastion SG Inbound Rules attachment with EC2 Endpoint SG">
  <br>
  <em>Bastion SG Inbound Rules attachment with EC2 Endpoint SG</em>
</p>