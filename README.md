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
| RemoveManagers | Should existing managers be removed from the database | YES |
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

If you wish to use persistent storage so that the SD database, and metrics are maintained after the demise of the instance, then you need to set Parameter `AddDataVolume` to `Yes` and optionally provide either an EBS Volume-ID of an existing volume or existing EBS Snapshot ID.

* If you provide an EBS Volume ID, template will attach this volume to the SD.
* If you leave EBS Volume ID blank, template will create a new EBS Volume of the size you specify, and attach it to the SD.
* If you provide the ID of an existing EBS Snapshot while leaving EBS Volume ID blank, template will create a new Volume from that snapshot.
* If you specify both existing EBS Volume ID and a Snapshot ID, the Snapshot ID will be ignored.

If you choose to create a persistent storage Volume and delete CloudFormation stack, a snapshot of this EBS Volume will be created before deletion. If you specify an existing Volume, it will not be deleted.

### Deploying the stack with persistent storage

You will need to provide the following additional settings to make use of persistent storage:

| Parameter | Description | Default |
|-----------|-------------|---------|
| AddDataVolume | Yes / No for whether to add Data Volume | No |
| VolumeSize | Size in GB of the Volume to create, if DataVolume and EBSSnapshotId are blank | - |
| DataVolume | The Volume ID of the EBS Volume to attach; blank means create new | - |
| EBSSnapshotId | The Snapshot ID to create EBS Volume from | - |



