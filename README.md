Set of scripts to deploy AWS instances and prepare them for the installation of MapR.
Create the mapr user, the repo, install Java, clustershell etc.
You need to have the ec2tools installed on your machine and EC2_CERT and EC2_PRIVATE_KEY set in your profile, as well as have your private AWS key on your machine.

To deploy a set of nodes in AWS, just invoke launch_aws_nodes.sh <nametag> <numinstances> <ami_id> <region> <zone> <secgroup> <keyfile> <instance_type> <number of EBS volumes> <volume size (GB)>\

where

nametag: just a tag give to all the nodes
numinstances: number of nodes to be deployed
ami_id: ID of the AMI image you want to use
region: AWS region
secgroup: AWS security group
keyfile: your AWS keyfile (pem file)
instance_type: I use “default” here
number of EBS volumes: number of volumes to be attached to the node
volume size: their size in GB

It should the deploy the nodes and volumes, install Java etc, run yum update inside the nodes. It will also create a directory /output/<nametag> on your machine where you’ll fine the internal and external IPs/hostnames.

To terminate the nodes again, you can use terminate_aws_nodes.sh.
