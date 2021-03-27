#!/bin/bash

echo -e "Note: t2.Micro"
inst_type=$(aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].InstanceType' --output text)


read -p " $1 " public_key
public_key=${public_key:-~/id_rsa_aws.pub}
key=$(echo ${public_key} | awk -F'/' '{print $NF}')
read -p " $2 " instance_name
instance_name=${instance_name:-"Demo"}
aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].{Instance:InstanceType,Memory:MemoryInfo.SizeInMiB,Ghz:ProcessorInfo.SustainedClockSpeedInGhz, VirType:SupportedVirtualizationTypes|[0]}'

#################
# VPC 
#################
echo
while true; do
 aws ec2 describe-vpcs  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 read -p "select the VPC Name for your new instance [$vpc_name]: " vpc_name
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
else ./aws/create_vpc.sh; 
 fi
 done