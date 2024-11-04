import boto3
import json
import logging
import os


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    logger.info(f'Received event: {json.dumps(event)}')

    connection_id = event['requestContext']['connectionId']

    body = json.loads(event['body'])
    number = body['number']


    client = boto3.client(
        'apigatewaymanagementapi',
        endpoint_url=f'https://{os.environ["API_GATEWAY_ID"]}.execute-api.{os.environ["REGION"]}.amazonaws.com/{os.environ["STAGE"]}'
    )

    client.post_to_connection(
        ConnectionId=connection_id,
        Data=json.dumps({'statusCode': 200, 'body': int(number) ** 1000}),
    )

    return {'statusCode': 200, 'body': 'sape'}
