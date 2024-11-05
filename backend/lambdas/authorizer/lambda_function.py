import json
import jwt
import os
import urllib3

from jwt.algorithms import RSAAlgorithm


COGNITO_USER_POOL_ID = os.environ['COGNITO_USER_POOL_ID']
REGION = os.environ['REGION']
CLIENT_ID = os.environ.get('CLIENT_ID')

# JWKS URL for Cognito
JWKS_URL = f'https://cognito-idp.{REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json'

# Initialize urllib3 PoolManager for HTTP requests
http = urllib3.PoolManager()


# Fetch JWKS (JSON Web Key Set) for your Cognito User Pool
def get_jwks():
    response = http.request('GET', JWKS_URL)
    if response.status != 200:
        raise Exception(f"Failed to fetch JWKS: {response.status}")
    return json.loads(response.data.decode('utf-8'))


# Helper function to generate IAM policy
def generate_policy(principal_id, effect, resource):
    return {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "execute-api:Invoke",
                    "Effect": effect,
                    "Resource": resource
                }
            ]
        }
    }


def lambda_handler(event, context):
    token = event['headers'].get('Authorization')

    if not token:
        return generate_policy("user", "Deny", event['methodArn'])

    # Remove "Bearer " prefix if present
    token = token.replace("Bearer ", "")

    try:
        # Get the public keys (JWKS) from Cognito
        jwks = get_jwks()
        
        # Decode the JWT header to find the key ID (kid)
        unverified_header = jwt.get_unverified_header(token)
        rsa_key = {}
        
        for key in jwks['keys']:
            if key['kid'] == unverified_header['kid']:
                rsa_key = {
                    "kty": key['kty'],
                    "kid": key['kid'],
                    "use": key['use'],
                    "n": key['n'],
                    "e": key['e']
                }
                break

        if not rsa_key:
            raise Exception("RSA key not found")

        # Verify and decode the token
        payload = jwt.decode(
            token,
            key=RSAAlgorithm.from_jwk(rsa_key),
            algorithms=["RS256"],
            audience=CLIENT_ID  # Optional: Verify audience if needed
        )
        
        # Token is valid, allow access
        return generate_policy(payload['sub'], "Allow", event['methodArn'])

    except Exception as e:
        # Token is invalid, deny access
        print(f"Authorization error: {e}")
        return generate_policy("user", "Deny", event['methodArn'])
