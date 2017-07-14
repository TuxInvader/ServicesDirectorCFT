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

## TODO

* Support mounting persistent storage on var so that the database/logs can be persistent.

