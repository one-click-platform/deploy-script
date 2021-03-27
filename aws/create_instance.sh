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
     else  ./aws/create_subnet.sh $3 $6;
     fi 
else echo ./aws/create_subnet.sh $3 $6; 
exit 1
 fi 
done 

#################
# ROUTE 
#################
echo -e ...Route Table check
echo
while true; do
rt_id=$(aws ec2 describe-route-tables  --filters "Name=tag:Name,Values=rt_$sub_name" "Name=route.gateway-id,Values=$igw_id" "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[].RouteTableId' --output text)
if [ -n "$rt_id" ];
then echo -e The vpc has a route table with a route across an internet gateway. checking the association with $sub_name subnet. 
  echo -e ...
  asos_id=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query "RouteTables[].Associations[?SubnetId =='$sub_id'].RouteTableAssociationId[]" --output text)
    if [ -n "$asos_id" ];
    then echo
    echo "2. Route is associated with $sub_name subnet. Checking the Security Group"
    echo  ...
    break
    else 
    echo " ... Creating missing Association between'$sub_name' Subnet and the Route Table."
    aws ec2 associate-route-table --subnet-id $sub_id --route-table-id $rt_id 
    echo "2. Route is now associated with $sub_name subnet. Checking the Security Group"
    echo  ...
    fi
  break
else echo "The entered VPC name has no Route table with a path to Internet via an Internet gateway."
    echo "creating the missing route table" 
rt_id=$(aws ec2 create-route-table   --vpc-id $vpc_id --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rt_$sub_name}]" --query 'RouteTable.{RouteTableId:RouteTableId}' --output text )
echo " Create route to Internet Gateway for Route Table ID '$rt_id'." 
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id  --region $AWS_REGION
fi
done 

#################
# Security Group
#################

  echo " ... Checking the availability of a security Group with SSH/HTTP ingress rule ."
  sg_id=$(aws ec2 describe-security-groups --filter "Name=group-name,Values=sg_${vpc_name}" "Name=vpc-id,Values=$vpc_id"  --query 'SecurityGroups[].GroupId' --o text)
  while true; do
   if [ -n "$sg_id" ];
    then  ingress_exists=$(aws ec2 describe-security-groups --group-ids $sg_id --filter "Name=ip-permission.from-port,Values=22" "Name=group-name,Values=sg_${vpc_name}" "Name=vpc-id,Values=$vpc_id"  --query 'length(SecurityGroups[?IpPermissions[?ToPort==`80` && contains(IpRanges[].CidrIp, `0.0.0.0/0`)]])' --o text)
      if [ "$ingress_exists" = "0" ];
      then echo "Creating missing security Group Rules."
         sg_22=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=22" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
         sg_443=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=80" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
         sg_80=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=443" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
           if [ -z "$sg_22" ];
           then echo "opening Port 22"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]'
           fi
           if [ -z "$sg_80" ];
           then echo "opening Port 80"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTP access "}]'
           fi
           if [ -z "$sg_443" ];
           then echo "opening Port 443"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=433,ToPort=433,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTPS access "}]'
           fi
      else  echo  "3. dedicated security Group ingress rules exists  PORT (22,80)."
      fi
      break
    else echo "creating the missing dedicated security Group for the vpc"
    sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH ,HTTP, and HTTPS" --vpc-id $vpc_id --query GroupId --output text)
    fi
 done     
echo  "Creating the instance with the below SG ."  
aws ec2 describe-security-groups --filter "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=sg_${vpc_name}"  --query 'SecurityGroups[].{SG_id:GroupId,Name:GroupName,Vpc_id:VpcId,"Rules": IpPermissions[].{SourceCIDR:IpRanges[].CidrIp|[0],Description:IpRanges[].Description|[0],fromport:FromPort,ToPort:ToPort,Protocol:IpProtocol}}'  
#################
# AMIs
#################
aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
img_id=$(aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
userdata="--user-data file://cloud-init/ubto_userdata.txt"
OS="Ubuntu"
user="ubuntu"
