import boto3

def lambda_handler(event, context):
    # Extract necessary information from the event
    alarm_name = event['alarmData']['alarmName']
    alarm_state = event['alarmData']['state']['value']
    # print(event)

    # Check if the alarm is in ALARM state
    if alarm_state == 'ALARM':
        # Get the ARN of the AWS CodePipeline to trigger
        pipeline_name = 'Scaling_deployment'
        codepipeline_client = boto3.client('codepipeline')
        response = codepipeline_client.start_pipeline_execution(name=pipeline_name)
        
        # Log the result
        print(f"Triggered CodePipeline execution for {pipeline_name}. Execution ID: {response['pipelineExecutionId']}")
    else:
        print(f"Ignoring CloudWatch alarm '{alarm_name}' because it's not in ALARM state.")


