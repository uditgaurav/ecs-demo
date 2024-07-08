#!/bin/bash

task_definitions_dir="./td"

region="us-east-2"

for file in "$task_definitions_dir"/*.json; do
  task_name=$(basename "$file" .json)

  echo "Registering task definition: $task_name from file $file"
  response=$(aws ecs register-task-definition --cli-input-json file://"$file" --region "$region")

  if echo "$response" | grep -q "taskDefinition"; then
    echo "Task definition $task_name registered successfully."
  else
    echo "Failed to register task definition $task_name. Response from AWS: $response"
  fi
done
