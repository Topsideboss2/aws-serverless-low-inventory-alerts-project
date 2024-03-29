#/bin/bash

# Create new bucket
aws s3api create-bucket \
--bucket <bucket-name>

# List s3 buckets to see new bucket
aws s3api list-buckets

# Create Dynamodb table
# NB: CreateTable is an asynchronous operation. 
# Upon receiving a CreateTable request, DynamoDB immediately returns a response with a TableStatus of CREATING. 
# After the table is created, DynamoDB sets the TableStatus to ACTIVE. 
# You can perform read and write operations only on an ACTIVE table.
aws dynamodb create-table \
--attribute-definitions AttributeName=Product,AttributeType=S AttributeName=StoreRegion,AttributeType=S \
--table-name <dynamodb-table-name> \
--key-schema AttributeName=Product,KeyType=HASH AttributeName=StoreRegion,KeyType=RANGE \
--provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5

# List tables to see created table
aws dynamodb list-tables

# Describe the newly created table
aws dynamodb describe-table \
--table-name <dynamodb-table-name>

# Create sns topic
aws sns create-topic \
--name <sns-topic-name>

# Add an email to subscribe to sns topic
aws sns subscribe \
--topic-arn <sns-topic-arn> \
--protocol email \
--notification-endpoint <your-email>

# Create first policy that will allow you to get objects from s3 and put in DynamoDB
aws iam create-policy \
--policy-name read-s3-update-dynamodb-policy \
--policy-document file://read-s3-update-dynamodb-policy.json

# See created policy
aws iam list-policies

# Create a role for your Lambda function
aws iam create-role \
--role-name read-s3-update-dynamodb-role \
--assume-role-policy-document file://read-s3-update-dynamodb-role.json

# Attach the policy to your role
aws iam attach-role-policy \
--role-name read-s3-update-dynammodb-role \
--policy-arn <first-policy-arn>

# Create second policy that will allow you to read from your dynamodb stream and publish notifications on sns topic
aws iam create-policy \
--policy-name read-dynamodb-publish-sns-policy \
--policy-document file://read-dynamodb-publish-sns-policy.json

# See created policy
aws iam list-policies

# Create a role for your Lambda function
aws iam create-role \
--role-name read-dynamodb-publish-sns-role \
--assume-role-policy-document file://read-dynamodb-publish-sns-role.json

# Attach the policy to your role
aws iam attach-role-policy \
--role-name read-dynamodb-publish-sns-role \
--policy-arn <second-policy-arn>

# Create a zip file of your Lambda function
zip read-s3-update-dynamodb.zip read-s3-update-dynamodb.py

# Create your lambda function
aws lambda create-function \
 --function-name read-s3-update-dynamodb \
 --runtime python3.11 \
 --role <role-arn> \
 --zip-file fileb://read-s3-update-dynamodb.zip \
 --handler read-s3-update-dynamodb.lambda_handler

# Adding event notification to your S3 bucket was a challenge:
# https://sagargiri.com/s3-event-notification-issue

# Use this to add permission for S3 to invoke/trigger your lambda function
aws lambda add-permission \
 --function-name read-s3-update-dynamodb \
 --statement-id AllowToBeInvoked \
 --action "lambda:InvokeFunction" \
 --principal s3.amazonaws.com \
 --source-arn "<bucket-arn>" 

# Create s3 trigger
aws s3api put-bucket-notification-configuration \
 --bucket <bucket-name> \
 --notification-configuration file://notification-configuration.json

# Create a zip file of your 2nd Lambda function
zip read-dynamodb-publish-sns.zip read-dynamodb-publish-sns.py

# Create your second Lambda function
aws lambda create-function \
 --function-name read-dynamodb-publish-sns \
 --runtime python3.11 \
 --role <dynamodb-arn> \
 --zip-file fileb://read-dynamodb-publish-sns.zip \
 --handler read-dynamodb-publish-sns.lambda_handler

# Create a DynamoDB Stream
aws dynamodb update-table \
 --table-name <dynamodb-table-name> \
 --stream-specification StreamEnabled=true,StreamViewType=NEW_IMAGE

# Create trigger from DynamoDB Stream that will invoke Lambda function
aws lambda create-event-source-mapping \
 --event-source-arn <dynamodb-stream-arn> \
 --function-name read-dynamodb-publish-sns \
 --starting-position LATEST

# Finally copy .csv file to S3
aws s3 cp . s3://<s3-bucket-name>/ \
 --recursive \
 --exclude "*" \
 --include "*.csv"


# DELETING ALL RESOURCES
# List s3 buckets to see buckets associated with your account
aws s3api list-buckets

# List objects in your s3 bucket
aws s3api list-objects \
--bucket <bucket-name>

# Delete objects in your s3 bucket
aws s3api delete-object \
--bucket <bucket-name> \
--key inventory.csv

# Delete your s3 bucket
aws s3api delete-bucket \
--bucket <bucket-name>

# List sns topics
aws sns list-topics

# Delete sns topic
aws sns delete-topic \
--topic-arn <sns-topic-arn>

# List dynamodb tables
aws dynamodb list-tables

# Delete dynamodb table
aws dynamodb delete-table \
--table-name <dynamodb-table-name>

# List lambda functions
aws lambda list-functions

# Delete first lambda function
aws lambda delete-function \
--function-name read-s3-update-dynamodb

# Delete the second lambda function
aws lambda delete-function \
--function-name read-dynamodb-publish-sns

# List roles
aws iam list-roles

# List policies
aws iam list-policies

# List policies attached to a role
aws iam list-role-policies \
--role-name read-s3-update-dynamodb-role

# Detach policy from role
aws iam detach-role-policy \
--role-name read-s3-update-dynamodb-role \
--policy-arn <read-s3-update-dynamodb-policy-arn>

# Delete role
aws iam delete-role \
--role-name read-s3-update-dynamodb-role

# List policies attached to a role
aws iam list-role-policies \
--role-name read-dynamodb-publish-sns-role

# Detach policy from role
aws iam detach-role-policy \
--role-name read-dynamodb-publish-sns-role \
--policy-arn <read-dynamodb-publish-sns-policy-arn>

# Delete role
aws iam delete-role \
--role-name read-dynamodb-publish-sns-role

# List policies
aws iam list-policies

# Delete first policy
aws iam delete-policy \
--policy-arn <read-s3-update-dynamodb-policy-arn>

# Delete second policy
aws iam delete-policy \
--policy-arn <read-dynamodb-publish-sns-policy-arn>