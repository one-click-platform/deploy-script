#!/bin/bash

echo
while true; do
 aws ec2 describe-vpcs --vpc-ids $vpc_id --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 vpc_name=$1
 vpc_name=${vpc_name:-$vpc_name}
 aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].VpcId' --output text)
 if [ -n "$vpc_id" ];
    then  
   echo -e selected VPC name : $vpc_name
   sub_name=$2
   sub_name=${sub_name:-CLI-SUB}
   echo selected Subnet name : $sub_name
   while true; do
   echo ============ SUBNET CIDR ========================== 
   echo Subnet CIDR must be contained in its VPC CIDR block "$(aws ec2 describe-vpcs --vpc-ids $vpc_id  --query   'Vpcs[].CidrBlock' --output text)"
   echo ===================================================
   sub_cidr="192.168.11.0/24"
            sub_cidr=${sub_cidr:-"192.168.10.0/24"};
            if [ "$sub_cidr" = "" ] 
                then echo -e "Entered CIDR is not valid. Please retry"
                else
                REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([1][6-9]|[2][0-9]|3[0]))([^0-9.]|$)'
                vpc_pref=$(aws ec2 describe-vpcs --vpc-ids $vpc_id  --query   'Vpcs[].CidrBlock' --output text| awk -F/ '{print $2}')
                sub_pref=`echo $sub_cidr | awk -F/ '{print $2}'`
                if [[ $sub_cidr =~ $REGEX ]]  && (( $sub_pref >= $vpc_pref && $sub_pref <= 28 ))
                then
                echo
                echo == Subnet information === 
                echo VPC name = ${GREEN}$vpc_name${NC} 
                echo VPC CIDR = ${GREEN}$sub_cidr${NC}
                echo SUBNET name = ${GREEN}$sub_name${NC}
                echo SUBNET CIDR = ${GREEN}$sub_cidr${NC}
                break
                else
                            echo -e "Entered CIDR is not valid. Please retry"
                fi
            fi
    done
    break
 else echo -e "The entered VPC name is not valid. Please retry"; 
 fi
done          

sub_id=$(aws ec2 create-subnet --vpc-id $vpc_id  --cidr-block $sub_cidr --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$sub_name}]" --query 'Subnet.{SubnetId:SubnetId}' --output text )
echo
echo "==== Created SUBNET details ===="
aws ec2 describe-subnets  --subnet-id $sub_id --query 'Subnets[].{VPC_id:VpcId,SUB_id:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,AutoIP:MapPublicIpOnLaunch,IP_COUNT:AvailableIpAddressCount,Name:Tags[?Key==`Name`].Value| [0]}'
echo "--> Auto-assign Public IP enabled for $sub_name"
aws ec2 modify-subnet-attribute  --subnet-id $sub_id --map-public-ip-on-launch
