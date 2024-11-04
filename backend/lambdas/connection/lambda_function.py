import boto3
import json
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    logger.info(f'Received event: {json.dumps(event)}')

    route_key = event['requestContext']['routeKey']
    connection_id = event['requestContext']['connectionId']

    client = boto3.client('dynamodb')
    if route_key == '$connect':
        client.put_item(
            TableName='api-connections',
            Item={
                'ConnectionId': {'S': connection_id},
                'Status': {'S': 'CONNECTED'},
            },
        )
        body = 'Connected'
    elif route_key == '$disconnect':
        client.delete_item(
            TableName='api-connections',
            Key={
                'ConnectionId': {'S': connection_id}
            }
        )
        body = 'Disconnected'

    return {'statusCode': 200, 'body': body}
