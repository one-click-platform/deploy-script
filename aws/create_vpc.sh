#!/bin/bash

vpc_name= "$1"
vpc_name=${vpc_name:-CLI-VPC}
echo -e selected VPC name : $vpc_name
if [ -z "$vpc_name" ];
    then  echo "The entered name is not valid ";
else
    while true; do
        vpc_cidr="192.168.0.0/16"
        vpc_cidr=${vpc_cidr:-"192.168.0.0/16"};
        if [ "$vpc_cidr" = "" ] 
            then echo -e "Entered CIDR is not valid. Please retry"
            else
             REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([1][6-9]|[2][0-8]))([^0-9.]|$)'
                 if [[ $vpc_cidr =~ $REGEX ]]
            then
            echo
            echo -e "  === VPC information ===" 
            echo -e "   VPC name = $vpc_name " 
            echo -e "   CIDR = $vpc_cidr"
            break
            else
                echo -e " Entered CIDR is not valid. Please retry"
            fi
        fi    
    done                
fi
vpc_id=$(aws ec2 create-vpc --cidr-block $vpc_cidr --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]"  --query Vpc.VpcId --output text) 
echo
echo -e "==== Created VPC details ===="
aws ec2 describe-vpcs --vpc-ids $vpc_id --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
echo -e Note : the last octet is always zeroed even if you specify a non zero value
echo -e "==== Created Security Group ===="
sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH ,HTTP, and HTTPS" --vpc-id $vpc_id --query GroupId --output text) 
aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]' IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTP access "}]' IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTPS access"}]'
echo -e "==== Created Security Group details ===="
aws ec2 describe-security-groups --group-id $sg_id  --query  'SecurityGroups[].{SG_id:GroupId,Name:GroupName,Vpc_id:VpcId,"Rules": IpPermissions[].{SourceCIDR:IpRanges[].CidrIp|[0],Description:IpRanges[].Description|[0],fromport:FromPort,ToPort:ToPort,Protocol:IpProtocol}}'