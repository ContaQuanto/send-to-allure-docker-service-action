#!/bin/bash

ALLURE_RESULTS_DIRECTORY=$1
PROJECT_ID=$2
IS_SECURE=$3
ALLURE_GENERATE=$4
CLEAN_RESULT=$5

SECURITY_USER=$ALLURE_SERVER_USER
SECURITY_PASS=$ALLURE_SERVER_PASSWORD
ALLURE_SERVER=$ALLURE_SERVER_URL

FILES_TO_SEND=$(ls -dp $ALLURE_RESULTS_DIRECTORY/* | grep -v /$)

if [ -z "$FILES_TO_SEND" ]; then
    echo "no files found"
    exit 1
fi

if [ -z "$ALLURE_SERVER_URL" ]; then
    echo "no allure server url provided"
    exit 1
fi


curl "$ALLURE_SERVER/allure-docker-service/version"

FILES=''
for FILE in $FILES_TO_SEND; do
    FILES+="-F files[]=@$FILE "
done



if [[ "$IS_SECURE" == "true" ]]; then
    if [ -z "$SECURITY_USER" ]; then
        echo "no auth username provided"
        exit 1
    fi
    if [ -z "$SECURITY_PASS" ]; then
        echo "no auth password provided"
        exit 1
    fi
    
    # set +o xtrace
    echo "------------------LOGIN-----------------"
    curl -X POST "$ALLURE_SERVER/allure-docker-service/login" \
    -H 'Content-Type: application/json' \
    -d "{
        "\""username"\"": "\""$SECURITY_USER"\"",
        "\""password"\"": "\""$SECURITY_PASS"\""
    }" -c cookiesFile -ik --silent --output /dev/null --show-error --fail
    echo "done"
    echo "------------------EXTRACTING-CSRF-ACCESS-TOKEN------------------"
    CRSF_ACCESS_TOKEN_VALUE=$(cat cookiesFile | grep -o 'csrf_access_token.*' | cut -f2)
    echo "done"
    # echo "csrf_access_token value: $CRSF_ACCESS_TOKEN_VALUE"


    echo "-------------------PROJECT-ID-----------------"
    curl -X GET "$ALLURE_SERVER/allure-docker-service/projects/$PROJECT_ID" \
    -H  "accept: */*" \
    -H 'Content-Type: multipart/form-data' \
    -H "X-CSRF-TOKEN: $CRSF_ACCESS_TOKEN_VALUE" \
    -b cookiesFile -ik > project.txt
    cat project.txt | grep "HTTP/2 404"
    if [[ $? == 0 ]]; then
        curl -X POST "$ALLURE_SERVER/allure-docker-service/projects" \
        -H  "accept: */*" -H 'Content-Type: application/json' \
        -H "X-CSRF-TOKEN: $CRSF_ACCESS_TOKEN_VALUE" \
        -b cookiesFile -ik -d "{\"id\":\"$PROJECT_ID\"}"
    fi
    echo "------------------CLEAR-RESULTS------------------"
    if [[ "$CLEAN_RESULT" == "true" ]]; then
        curl -X GET "$ALLURE_SERVER/allure-docker-service/clean-results?project_id=$PROJECT_ID" \
        -H  "accept: */*" \
        -H 'Content-Type: multipart/form-data' \
        -H "X-CSRF-TOKEN: $CRSF_ACCESS_TOKEN_VALUE" \
        -b cookiesFile -ik
    fi
    echo "------------------SEND-RESULTS------------------"
    curl -X POST "$ALLURE_SERVER/allure-docker-service/send-results?project_id=$PROJECT_ID" \
    -H 'Content-Type: multipart/form-data' \
    -H "X-CSRF-TOKEN: $CRSF_ACCESS_TOKEN_VALUE" \
    -b cookiesFile $FILES -ik
    echo "done"
    set -o xtrace
else
    echo "------------------SEND-RESULTS------------------"
    curl -X POST "$ALLURE_SERVER/allure-docker-service/send-results?project_id=$PROJECT_ID" -H 'Content-Type: multipart/form-data' $FILES -ik
fi

if [[ "$ALLURE_GENERATE" == "true" ]]; then
    echo "-----------------GENERATE-REPORT----------------"
    EXECUTION_NAME='GitHub+Actions'
    EXECUTION_FROM="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
    EXECUTION_FROM_ENCODED=="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$EXECUTION_FROM" "" | cut -c 3-)"

    GENERATE_URL="$ALLURE_SERVER/allure-docker-service/generate-report?project_id=$PROJECT_ID&execution_name=$EXECUTION_NAME&execution_from=$EXECUTION_FROM_ENCODED"
    if [[ "$IS_SECURE" == "true" ]]; then
        RESPONSE=$(curl -X GET "$GENERATE_URL" -H "X-CSRF-TOKEN: $CRSF_ACCESS_TOKEN_VALUE" -b cookiesFile $FILES)
    else
        RESPONSE=$(curl -X GET "$GENERATE_URL" $FILES)
    fi
    echo $(grep -o '"report_url":"[^"]*' <<< "$RESPONSE" | grep -o '[^"]*$')
fi