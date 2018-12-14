#!/bin/sh

sonar_token=$1
sonar_server=$

#take care for the line where is ceTaskId info in the file /.scannerwork/report-task.txt; 
#It changes depending of server and sonar scanner version, in my case is at line 7
ceTaskId=$(head -7 $3 | tail -1)
taskId=$(echo "$ceTaskId" | cut -d'=' -f 2)

## Checking for the request server status.
STATUS=$(curl -u $sonar_token: -s -o /dev/null -w '%{http_code}' https://$sonar_server/api/ce/task?id=$taskId)
echo $STATUS
if [ $STATUS != 200 ]
then
	echo "Was imposible to connect to the server (https://$sonar_server/api/ce/task?id=$taskId)"
	exit 1
fi

taskStatus=$(curl -u $sonar_token: https://$sonar_server/api/ce/task?id=$taskId | jq -r .task.status)
while [ "$taskStatus" = "PENDING" ] || [ "$taskStatus" = "IN_PROGRESS" ]
do
	clear
	echo "Task $taskId status is: $taskStatus, new retry in 5 seconds" 
	sleep 5
	taskStatus=$(curl -u $sonar_token: https://$sonar_server/api/ce/task?id=$taskId | jq -r .task.status)
done

if [ "$taskStatus" = "SUCCESS" ]
then
	analysisId=$(curl -u $sonar_token: https://$sonar_server/api/ce/task?id=$taskId | jq -r .task.analysisId)
	quality_gatesstatus=$(curl -u $sonar_token: https://$sonar_server/api/qualitygates/project_status?analysisId=$analysisId | jq -r .projectStatus.status)
else
	echo "The analysis was not SUCCESS, it was $taskStatus"
	exit 1
fi

echo "the Sonar quality gates for current analysis was: $quality_gatesstatus"
if [ "$quality_gatesstatus" != "OK" ] && [ "$quality_gatesstatus" != "WARN" ]
then
	echo "check sonar server and fix the issues"
	exit 1	
fi
