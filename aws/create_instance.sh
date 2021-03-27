#!/bin/bash

echo -e "Note: t2.Micro"
inst_type=$(aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].InstanceType' --output text)


public_key= $1
public_key=${public_key:-~/id_rsa_aws.pub}
key=$(echo ${public_key} | awk -F'/' '{print $NF}')
instance_name= $2
instance_name=${instance_name:-"Demo"}
aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].{Instance:InstanceType,Memory:MemoryInfo.SizeInMiB,Ghz:ProcessorInfo.SustainedClockSpeedInGhz, VirType:SupportedVirtualizationTypes|[0]}'

#################
# VPC 
#################
echo
while true; do
 aws ec2 describe-vpcs  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 vpc_name=$3
 vpc_name=${vpc_name:-$vpc_name}
 vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].VpcId' --output text)
if [ -n "$vpc_id" ];
    then  
     echo selected VPC name $vpc_name
     while true; do
     igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[].InternetGatewayId' --output text) 
     if  [ -n "$igw_id" ];
     then echo 
     echo "1. Internet gateway exists => checking the subnet availability$"
     echo ...
     break
     else echo "No Internet Gateway is associated to $vpc_name VPC.";
     echo "creating and attaching the missing Internet gateway"
     igw_id=$(aws ec2 create-internet-gateway  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw_$vpc_name}]" --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text  ) #--region $AWS_REGION
     aws ec2 attach-internet-gateway   --vpc-id $vpc_id  --internet-gateway-id $igw_id  --region $AWS_REGION
     fi
     done 
     break
else ./aws/create_vpc.sh $4; 
 fi
 done

#################
# SUBNET 
#################
while true; do
sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
if [ -n "$sub_id" ];
    then  
     aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].{VPC_id:VpcId,SUB_id:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,AutoIP:MapPublicIpOnLaunch,IP_COUNT:AvailableIpAddressCount,Name:Tags[?Key==`Name`].Value| [0]}' 
     sub_name= $5
     sub_name=${sub_name:-$sub_name}
     sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$sub_name"  --query   'Subnets[].SubnetId' --output text)
     echo selected subnet name : $sub_name
     if  [ -n "$sub_id" ];
     then echo
     echo " Internet gateway and subnet exist => checking the Route table"
     echo ...
     break
     else  ./aws/create_subnet.sh;
     fi 
else echo ./aws/create_subnet.sh; 
exit 1
 fi 
done 