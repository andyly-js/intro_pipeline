import json
import boto3
import urllib.parse

s3_client=boto3.client('s3')
sqs_client = boto3.client('sqs')

# lambda function to copy file from 1 s3 to another s3
def handler(event, context):
    
    #decode nested SQS message body content 
    message_body = json.loads(event['Records'][0]['body'])
    message_body_content = json.loads(message_body['Message'])

    source_bucket_name=message_body_content['Records'][0]['s3']['bucket']['name']
    
    #get object that has been uploaded
    file_name=message_body_content['Records'][0]['s3']['object']['key']
    
    #specify destination bucket
    destination_bucket_name='datalake-intro'
    
    #specify from where file needs to be copied
    copy_object={'Bucket':source_bucket_name,'Key':file_name}
    
    #write copy statement 
    s3_client.copy_object(CopySource=copy_object,Bucket=destination_bucket_name,Key=file_name)

    return {
        'statusCode': 3000,
        'body': json.dumps('File has been Successfully Copied')
    }