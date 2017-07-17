# ServicesDirectorCFT

## About
This is a Cloud Formation template for Brocade Services Director. 

* It can be used to deploy a SD into a new VPC.
* It will enable NAT to the public IP by default so that you can license remote vTMs

## Usage
Simply download the template and then launch it in the cloudformation manager.

* Europe(Ireland): https://eu-west-1.console.aws.amazon.com/cloudformation/home

When the stack is built the public IP address will be returned, and it's ready for recieving REST calls.

### Parameters
| Parameter | Description | Default |
|-----------|-------------|---------|
| AZ      | The availability zone to deploy the Services Director | - |
| VPCCIDR | The VPC subnet | 10.8.0.0/16 |
| PublicSubnetCIDR | Public Subnet used by SD | 10.8.1.0/24 |
| InstanceType | The machine type | t2.small |
| KeyName | SSH Keys to install | - |
| SDVers | Services Director Version | 17.2 |
| SDEncKey | SD Encryption Key | Password1\_2 |
| SDUseNat | SD Use NAT | YES |
| RestUser | SD REST Username | admin |
| RestPass | SD REST Password | Password123 |
| SSLPublicKey | Your SD Public Cert | TEST CERT |
| SSLPrivateKey | Your SD Private Key | TEST CERT KEY |
| DBHost | Mysql Host | localhost |
| DBUser | Mysql User | ssc |
| DBPass | Mysql Password | Password123 |
| DBName | Mysql DB Name | ssc |
| Licenses | CSV list of your license keys | - |
| AlertEmail | Email for alerts | root@localhost |
| AlertServer | SMTP server for email | localhost |
| RemoteAccessCIDR | IP range for restricting SSH access | 0.0.0.0/0 |

* If you leave the `DBHost` set to `localhost`, then the template will install a Mysql server for you.
* If you leave the `AlertServer` set to `localhost`, then the template will install postfix for you.
* You _must_ provide licenses in the `Licenses` parameter. Include the controller license, and any bandwidth or add-ons you may have.
* You _must_ select an `AZ` 
* You _must_ provide `KeyName` if you want to be able to ssh to the instance.

## Using Persistent Storage

If you wish to use persistent storage so that the SD database, and metrics are maintained after the demise of the instance, then you need to provide an EBS Volume-ID, and access credentials for a user with permissions to attach/detach storage. See below on creating such a user.

### Create a Policy/User

* In the AWS console, create a new policy with the following permissions.

|Effect|Action|Resource|
|------|------|--------|
|Allow | ec2:AttachVolume| * |
|Allow | ec2:DetachVolume| * |

* Then create a user with access type: _Programmatic Access_ and assign the above policy directly to the user. 

* Make a note of the `Access Key ID` and the `Secret Access Key`, you will need to provide these when deploying the stack.

### Deploying the stack with persistent storage

You will need to provide the following additional settings to make use of persistent storage:

| Parameter | Description | Default |
|-----------|-------------|---------|
| DataVolume      | The Volume ID of the EBS Volume to attach | - |
| AccessKey | The Access Key ID for calling the AWS API | - |
| SecretAccessKey | The Secret Access Key for the above | - |
| RemoveManagers | Should existing managers be removed from the database | YES |



