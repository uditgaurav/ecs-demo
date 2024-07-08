#!/bin/bash

REGION="us-east-2"
CLUSTER_NAME="ecs-demo"
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region $REGION)
NAMESPACE="boutique.local"
NAMESPACE_DESCRIPTION="Namespace for Online Boutique Microservices"

# Get the Namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces --query "Namespaces[?Name=='$NAMESPACE'].Id" --output text --region $REGION)
if [ -z "$NAMESPACE_ID" ] || [ "$NAMESPACE_ID" == "None" ]; then
    OPERATION_ID=$(aws servicediscovery create-private-dns-namespace --name "$NAMESPACE" --vpc "$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text --region $REGION)" --description "$NAMESPACE_DESCRIPTION" --query 'Operation.Id' --output text --region $REGION)
    echo "Creating Namespace: $NAMESPACE, OperationId: $OPERATION_ID"
    while [ "$(aws servicediscovery get-operation --operation-id $OPERATION_ID --query 'Operation.Status' --output text --region $REGION)" != "SUCCESS" ]; do
        echo "Waiting for namespace to be created..."
        sleep 10
    done
    NAMESPACE_ID=$(aws servicediscovery list-namespaces --query "Namespaces[?Name=='$NAMESPACE'].Id" --output text --region $REGION)
fi

services=("frontend" "checkoutservice" "cartservice" "recommendationservice" "paymentservice" "productcatalogservice" "shippingservice" "adservice" "currencyservice" "loadgenerator" "redis-cart")

for service in "${services[@]}"; do
    echo "Setting up service discovery for $service"
    SDS_ID=$(aws servicediscovery create-service --name "$service" --namespace-id "$NAMESPACE_ID" --dns-config 'DnsRecords=[{Type="A", TTL="60"}]' --query 'Service.Id' --output text --region $REGION 2>/dev/null)
    if [ -z "$SDS_ID" ]; then
        SDS_ID=$(aws servicediscovery list-services --query "Services[?Name=='$service' && NamespaceId=='$NAMESPACE_ID'].Id" --output text --region $REGION)
    fi
    aws ecs update-service --cluster "$CLUSTER_NAME" --service "$service" --service-registries "registryArn=arn:aws:servicediscovery:$REGION:$ACCOUNT_ID:service/$SDS_ID" --region $REGION
    echo "Updated ECS service $service to use service discovery."
done
