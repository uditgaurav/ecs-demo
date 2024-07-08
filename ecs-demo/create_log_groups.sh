#!/bin/bash

services=("frontend" "checkoutservice" "cartservice" "recommendationservice" "paymentservice" "productcatalogservice" "shippingservice" "adservice" "currencyservice" "loadgenerator" "redis-cart")

region="us-east-2"

for service in "${services[@]}"
do
  log_group_name="/ecs/$service"

  if aws logs describe-log-groups --log-group-name-prefix "$log_group_name" --region "$region" | grep -q "$log_group_name"; then
    echo "Log group $log_group_name already exists, skipping creation."
  else
    aws logs create-log-group --log-group-name "$log_group_name" --region "$region"
    if [ $? -eq 0 ]; then
      echo "Successfully created log group $log_group_name."
    else
      echo "Failed to create log group $log_group_name."
    fi
  fi
done
