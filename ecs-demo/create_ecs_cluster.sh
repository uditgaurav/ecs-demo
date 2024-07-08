#!/bin/bash

cluster_name="ecs-demo"
region="us-east-2"

aws configure set default.region "$region"

response=$(aws ecs create-cluster --cluster-name "$cluster_name" --region "$region")

if echo "$response" | grep -q "$cluster_name"; then
  echo "ECS cluster '$cluster_name' created successfully in region '$region'."
else
  echo "Failed to create ECS cluster. Response from AWS: $response"
fi
