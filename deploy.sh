#!/bin/bash

# more bash-friendly output for jq
# more bash-friendly output for jq
# --raw-output With this option, if the filter’s result is a string then it will be written directly to standard output rather than being formatted as a JSON string with quotes. This can be useful for making jq filters talk to non-JSON-based systems.
# --exit-status Sets the exit status of jq to 0 if the last output values was neither false nor null, 1 if the last output value was either false or null, or 4 if no valid result was ever produced. Normally jq exits with 2 if there was any usage problem or system error, 3 if there was a jq program compile error, or 0 if the jq program ran.
# Another way to set the exit status is with the halt_error builtin function.
# https://stedolan.github.io/jq/manual/
# can be change for -e -r
JQ="jq -r -e"

# assign the paramenters to some variables
APP_NAME=$1
CLUSTER_NAME=$2
ENVIRONMENT=$3
VERSION=$4

# Create other variables
SERVICE_NAME="$ENVIRONMENT-accountopen-$APP_NAME-service"
CLUSTER_NAME="bdb-accountopen-$ENVIRONMENT-$CLUSTER_NAME-cluster"
BUILD_NUMBER=${CIRCLE_BUILD_NUM}
IMAGE_TAG=${CIRCLE_SHA1}
TASK_FAMILY="$ENVIRONMENT-accountopen-$APP_NAME-task-family"
AWS_ACCOUNT_ID=058018423448

# define function
configure_aws_cli(){
    # verify version of AWS
    aws --version
    # configure the dafult regiion
    aws configure set default.region us-east-1
    # configure the output format
    aws configure set default.output json
}

# define function
push_ecr_image(){
    # http://docs.aws.amazon.com/cli/latest/reference/ecr/get-login.html
    eval $(aws ecr get-login --region us-east-1)

    # Create a docker image from the source of this folder
    docker build -t $ENVIRONMENT-$APP_NAME .

    # modify the tag of the image builded
    docker tag $ENVIRONMENT-$APP_NAME $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$ENVIRONMENT-$APP_NAME:$VERSION

    # Push the docker image to the AWS instance
    docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/$ENVIRONMENT-$APP_NAME:$VERSION
}

deploy_cluster(){

    # Call this function
    make_task_def
    # Call this function
    register_task_definition

    if  [ ${ENVIRONMENT} != "prod" ]; then
        echo ${CLUSTER_NAME}
        echo ${SERVICE_NAME}

        DESIRED_COUNT=$(aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} | egrep "desiredCount" | head -1 | tr "/" " " | awk '{print $2}' | sed 's/,$//')
        if [ ${DESIRED_COUNT} = "0" ]; then
            DESIRED_COUNT="1"
        fi
        #DESIRED_COUNT="1"

        tasks=$(aws --region us-east-1 ecs list-tasks --cluster $CLUSTER_NAME --family ${TASK_FAMILY} | jq -r '.taskArns | map(.[40:]) | reduce .[] as $item (""; . + $item + " ")')
        for task in $tasks; do
            aws --region us-east-1 ecs stop-task --task $task --cluster $CLUSTER_NAME
            echo "Service stoped: $task"
        done
        #aws --region us-west-2 ecs deregister-container-instance --cluster $cluster --container-instance $container_instance

        if [[ $(aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $revision --desired-count ${DESIRED_COUNT} | \
                       $JQ '.service.taskDefinition') != $revision ]]; then
            echo "Error updating service."
            return 1
        else
            echo "Update service.."
        fi
    fi

}

make_task_def(){

    # http://docs.aws.amazon.com/cli/latest/reference/ecs/describe-task-definition.html
    TASK_ALL=$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY})
    echo "Task All: $TASK_ALL"


    TASK_TEMPLATE=$(aws ecs describe-task-definition --task-definition ${TASK_FAMILY} | jq -r .taskDefinition.containerDefinitions[0])
    echo "Template anterior: $TASK_TEMPLATE"

    NEW_CONTAINER_DEFINITIONS=$(echo "$TASK_TEMPLATE" | jq ".image = \"%s.dkr.ecr.us-east-1.amazonaws.com/${ENVIRONMENT}-${APP_NAME}:%s\""  )

    echo "Template nuevo: $NEW_CONTAINER_DEFINITIONS"

    task_def=$(printf "$NEW_CONTAINER_DEFINITIONS" $AWS_ACCOUNT_ID $VERSION)
}

register_task_definition() {
    #--container-definitions "$task_def"
    if revision=$(aws ecs register-task-definition --container-definitions "$task_def" --family $TASK_FAMILY | $JQ '.taskDefinition.taskDefinitionArn'); then
        echo "Revision: $revision"
    else
        echo "Failed to register task definition"
        return 1
    fi

}

setup_env_amazon()
{
    if  [ ${ENVIRONMENT} = "prod" ]; then
        export AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID_PROD
        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_PROD
        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_PROD
    fi
}

setup_env_amazon
configure_aws_cli
push_ecr_image
deploy_cluster
