#  __  __ ____   ____   ____  _     _      _     _      ___        ______
# |  \/  |  _ \ / ___| / ___|| |__ (_) ___| | __| |    / \ \      / / ___|
# | |\/| | | | | |     \___ \| '_ \| |/ _ \ |/ _` |   / _ \ \ /\ / /\___ \
# | |  | | |_| | |___   ___) | | | | |  __/ | (_| |  / ___ \ V  V /  ___) |
# |_|  |_|____/ \____| |____/|_| |_|_|\___|_|\__,_| /_/   \_\_/\_/  |____/

# Microsoft Defender for Cloud (MDC) Shield
# Advanced Remediation for your AWS resources

import io
import json
import logging
import os
import sys

import azure.functions as func
from azure.identity import ChainedTokenCredential, EnvironmentCredential, ManagedIdentityCredential
import awscli.clidriver

# Configure logging
logging.basicConfig(level=logging.INFO)

def execute_aws_cli(cmd):
    output_stream = io.StringIO()
    sys.stdout = output_stream
    sys.stderr = output_stream

    try:
        clidriver = awscli.clidriver.create_clidriver()
        clidriver.main(cmd)
        output_content = output_stream.getvalue().strip()
    except SystemExit as se:
        error_message = f"SystemExit: {se.code}"
        if se.__context__ is not None:
            error_message = f"{error_message}\n{se.__context__}"
        
        return {"content": error_message}
    except Exception as e:
        return {"content": f"Error: {str(e)}"}

    return {"content": output_content}

def authenticate_to_aws(aws_role_arn, aws_session_name, aws_region, token):
    home_dir = os.environ['HOME']
    if not os.path.exists(os.path.join(home_dir, ".aws")):
        os.makedirs(os.path.join(home_dir, ".aws"))
    
    config_file_path = os.path.join(home_dir, ".aws", "config")

    with open(config_file_path, "w") as config_file:
        config_file.write("[default]\n")
        config_file.write(f"region = {aws_region}\n")
        config_file.write(f"output = json\n")

    # clidriver = awscli.clidriver.create_clidriver()

    sso_params = [
        'sts', 'assume-role-with-web-identity',
        '--duration-seconds', '3600',
        '--role-session-name', aws_session_name,
        "--role-arn", aws_role_arn,
        "--web-identity-token", token
    ]

    sso_output = execute_aws_cli(sso_params)
    try:
        sso_output = json.loads(sso_output['content'])
    except Exception as e:
        raise Exception(sso_output)

    credentials_file_path = os.path.join(home_dir, ".aws", "credentials")

    with open(credentials_file_path, "w") as credentials_file:
        credentials_file.write("[default]\n")
        credentials_file.write(f"aws_access_key_id = {sso_output['Credentials']['AccessKeyId']}\n")
        credentials_file.write(f"aws_secret_access_key = {sso_output['Credentials']['SecretAccessKey']}\n")
        credentials_file.write(f"aws_session_token = {sso_output['Credentials']['SessionToken']}\n")

def validate_input(req_body):
    required_params = ['aws_role_arn', 'aws_session_name', 'aws_region', 'cmd']
    for param in required_params:
        if not req_body.get(param):
            return False
    return True

def process_request(req_body):
    aws_role_arn = req_body['aws_role_arn']
    aws_session_name = req_body['aws_session_name']
    aws_region = req_body['aws_region']
    cmd = req_body['cmd']

    token = get_azure_token()

    authenticate_to_aws(aws_role_arn, aws_session_name, aws_region, token)

    output = execute_aws_cli(cmd)

    return output

def get_azure_token():
    audience = os.environ['AZURE_MSI_AUDIENCE']
    msi_credential = ManagedIdentityCredential() ## Modify this if you're using a User-assigned Managed Identity
    ec_credential = EnvironmentCredential() ## For development purposes only
    chained_credential = ChainedTokenCredential(msi_credential, ec_credential)
    token = chained_credential.get_token(audience).token
    return token

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="mdc_shield_aws_cli")
def mdc_shield_aws_cli(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    req_body = req.get_json()

    if not validate_input(req_body):
        return func.HttpResponse(
            "Please provide all required parameters in the request body.",
            status_code=400
        )

    try:
        output = process_request(req_body)
        return func.HttpResponse(
            json.dumps(output),
            status_code=200
        )
    except Exception as e:
        return func.HttpResponse(
            json.dumps({"content": str(e)}),
            status_code=400
        )