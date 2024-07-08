#!/bin/bash

REGION="us-east-2"
CLUSTER_NAME="ecs-demo"

VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text --region $REGION)
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text --region $REGION)
SG_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text --region $REGION)

if [ "$VPC_ID" == "None" ]; then
    VPC_ID=$(aws ec2 create-vpc --cidr-block "10.0.0.0/16" --query 'Vpc.VpcId' --output text --region $REGION)
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}" --region $REGION
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}" --region $REGION

    SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block "10.0.1.0/24" --query 'Subnet.SubnetId' --output text --region $REGION)
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region $REGION

    SG_ID=$(aws ec2 create-security-group --group-name "ecs-demo-sg" --description "Security group for ECS Demo" --vpc-id $VPC_ID --query 'GroupId' --output text --region $REGION)
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 1-65535 --cidr "0.0.0.0/0" --region $REGION
fi

services=("frontend" "checkoutservice" "cartservice" "recommendationservice" "paymentservice" "productcatalogservice" "shippingservice" "adservice" "currencyservice" "loadgenerator" "redis-cart")
task_definitions=("frontend" "checkoutservice" "cartservice" "recommendationservice" "paymentservice" "productcatalogservice" "shippingservice" "adservice" "currencyservice" "loadgenerator" "redis-cart")

for ((i = 0; i < ${#services[@]}; i++)); do
    service=${services[$i]}
    task_definition=${task_definitions[$i]}
    echo "Deploying $service using task definition $task_definition"
    if aws ecs describe-services --services "$service" --cluster "$CLUSTER_NAME" --region "$REGION" | grep -q '"status": "ACTIVE"'; then
        aws ecs update-service --cluster "$CLUSTER_NAME" --service "$service" --task-definition "$task_definition" --region "$REGION"
        if [ $? -eq 0 ]; then
            echo "$service updated successfully."
        else
            echo "Failed to update $service."
        fi
    else
        aws ecs create-service --cluster "$CLUSTER_NAME" --service-name "$service" --task-definition "$task_definition" --desired-count 1 --launch-type "FARGATE" --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SG_ID],assignPublicIp=\"ENABLED\"}" --region "$REGION"
        if [ $? -eq 0 ]; then
            echo "$service created successfully."
        else
            echo "Failed to create $service."
        fi
    fi
done
