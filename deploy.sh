#!/usr/bin/env bash

ProjectName="sg12.cloud"
ToolsAccount=""
ToolsAccountProfile=""

TestAccount=""
TestAccountProfile=""

ProdAccount=""
ProdAccountProfile=""


GIT_OWNER=""
GIT_REPO=""
GIT_TOKEN=""


echo -n "Step One - Deploy the ArtifactKey and ArtifactBucket..."


aws cloudformation deploy --stack-name step-one-control-plane --template-file templates/step-one-control-plane.yaml \
--parameter-overrides ProjectName=$ProjectName TestAccount=$TestAccount ProductionAccount=$ProdAccount ToolsAccount=$ToolsAccount \
--profile $ToolsAccountProfile


echo -n "Fetching S3 bucket and CMK ARN from CloudFormation automatically..."

get_s3_command="aws cloudformation describe-stacks --stack-name step-one-control-plane --profile $ToolsAccountProfile --query \"Stacks[0].Outputs[?OutputKey=='ArtifactBucket'].OutputValue\" --output text"
ArtifactBucket=$(eval $get_s3_command)
echo -n "Got S3 bucket name: $ArtifactBucket"


get_cmk_command="aws cloudformation describe-stacks --stack-name step-one-control-plane --profile $ToolsAccountProfile --query \"Stacks[0].Outputs[?OutputKey=='CMK'].OutputValue\" --output text"
ArtifactKeyArn=$(eval $get_cmk_command)
echo -n "Got CMK ARN: $ArtifactKeyArn"



echo -n "Step 2.1 - Deploy Roles in testing account"
aws cloudformation deploy --stack-name step-two-cross-accounts-roles \
--template-file templates/step-two-cross-accounts-roles.yaml \
--capabilities CAPABILITY_NAMED_IAM --parameter-overrides ProjectName=$ProjectName  ToolsAccount=$ToolsAccount ArtifactKeyArn=$ArtifactKeyArn  ArtifactBucket=$ArtifactBucket \
--profile $TestAccountProfile

echo -n "Step 2.2 - Deploy roles in production account"
aws cloudformation deploy --stack-name step-two-cross-accounts-roles \
--template-file templates/step-two-cross-accounts-roles.yaml \
--capabilities CAPABILITY_NAMED_IAM --parameter-overrides ProjectName=$ProjectName  ToolsAccount=$ToolsAccount ArtifactKeyArn=$ArtifactKeyArn  ArtifactBucket=$ArtifactBucket \
--profile $ProdAccountProfile

echo -n "Step 3 - Creating Pipeline in Tools Account"
aws cloudformation deploy --stack-name step-three-pipeline --template-file templates/step-three-pipeline.yaml \
--parameter-overrides ProjectName=$ProjectName   TestAccount=$TestAccount ProductionAccount=$ProdAccount ArtifactKey=$ArtifactKeyArn ArtifactBucket=$ArtifactBucket  GitOwner="${GIT_OWNER}" GitRepo="${GIT_REPO}" GitToken="${GIT_TOKEN}" \
--capabilities CAPABILITY_NAMED_IAM --profile $ToolsAccountProfile


echo -n "Adding Permissions to the CMK"
aws cloudformation deploy --stack-name step-one-control-plane --template-file templates/step-one-control-plane.yaml \
--parameter-overrides ProjectName=$ProjectName  CodeBuildCondition=true --profile $ToolsAccountProfile


echo -n "Adding Permissions to the Cross Accounts"
aws cloudformation deploy --stack-name step-three-pipeline --template-file templates/step-three-pipeline.yaml \
--parameter-overrides ProjectName=$ProjectName   CrossAccountCondition=true --capabilities CAPABILITY_NAMED_IAM \
--profile $ToolsAccountProfile