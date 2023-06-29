# Microsoft Defender for Cloud (MDC) Shield

## About this project

Remediation tasks in Microsoft Defender for Cloud can be easily achievable using Azure Policies and other built-in Workflows for Azure, but I often see customers struggling with remediation for AWS and GCP, so I decided to create this project to share some of the remediation tasks I have created for my customers and for the community.

The basis for MDC-Shield is the use of a Azure Function that will allow customers to run CLI Commands from it, which will be triggered by a Workflow Logic App in a Defender for Cloud or even Sentinel Playbook.

CLI commands are frequently used in daily-basis, which will also generate a highly customizable interface for anyone interested in remediating cloud resources in an easy manner.

In order to keep this solution as simple as possible, authentication will be based on Function's Managed Identity, to which privileges will be granted in the  cloud provider (including Azure - why not? :smiley:)

To the provisioned role we will attach a policy that will allow the execution of the required CLI commands and that should be properly managed and controlled to avoid unnecessary privileges.

> Want to know more about how you can discover, monitor and remediate permissions for identities or resources in your Multi-Cloud Environments?
> Take a look at [Microsoft Entra Permissions Management](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-permissions-management) and how it can help you to achieve your goals.

## AWS

### Concept

access through AWS IAM Roles, as described in the following AWS article [Using an IAM role in the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html#cli-configure-role-oidc).

### Prerequisites

1. Azure Subscription with required permissions to create an Azure Function and Logic Apps to be called as remediation tasks.
2. AWS Account with required permissions to create IAM Roles and Policies
   > Depending on what remediation tasks you plan to use, you may need to create additional IAM Roles and Policies in order to restrict the access to the required resources properly
3. [Optional] Configure a User-Assigned Managed Identity, allowing it to be reused across multiple AWS Functions.

### Deployment

#### Azure Function

- Azure AD App Registration

  - Main App Registration: App registration that will be associated to AWS Role.
  - Client App Registration: Used for Development purposes only, once VSCode instance cannot use a Managed Identity
    - For this Registration, just create it and m

- Azure Function Deployment

  - Function can be deployed using the button below. If you prefer, you can use the folder in this repository to adjust it and deploy directly from VSCode or the IDE from your preference.
  - <<< Deploy Button >>>

- Azure Function Configuration

  - Some environment variables should be configured, as example below. It is recommended that you include sensitive information using a KeyVault as described in the article XXXXX.

  ```json
  {
      "AZURE_TENANT_ID": "<Azure AD Tenant ID>",
      "AZURE_AUTHORITY_HOST": "login.microsoftonline.com",
      "AZURE_MSI_AUDIENCE": "<App Registration URI>/.default",
      "AZURE_MSI_CLIENT_ID": "<System/User Managed Identity Client ID>"
  }
  ```

  - For debugging purposes, in Visual Studio code I've created another app registration, also included as member of the main app registration, so in local function code the variables are needed

  ```json
  {
      "AZURE_CLIENT_ID": "<Secondary Azure AD App Registration ID>", 
      "AZURE_CLIENT_SECRET": "<Secondary Azure AD App Registration Secret>"
  }
  ```

- Azure AD Role provisioning

  - **Production**: Ensure that the `$client` object is using the System assigned or user assigned Managed Identity associated to the Azure Function

  ```powershell
  Connect-AzureAD
  $appId = Get-AzureADServicePrincipal -SearchString "<Main Service Principal Name>"
  $appRole = $AppId.AppRoles | ? {$_.DisplayName -eq "AssumeRoleWithWebIdentity"}
  $client = Get-AzureADServicePrincipal -SearchString "<Managed Identity Name>"
  
  ## Add Role Assignment
  New-AzureADServiceAppRoleAssignment -ObjectId $appId.ObjectId -ResourceId $appId.ObjectId -Id $appRole.Id -PrincipalId $client.ObjectId
  ```

- AWS Azure AD OpenID Connect

  - Um dos passos importantes para este ponto é realizar o deployment de um identity provider na AWS para o tenant de Azure AD utilizado.
  - É provavel qeu se há possuir alguma integracão similar, o Identity Provider já exista, sendo necessário apenas incluir o URN/URI às audiencias válidas para a solução
  - Caso seja o primeiro uso, basta realizar o deployment do Cloud Formation disponível no arquivo XXX

- AWS Role provisioning
  - Obtain Azure AD Thumbprint as described in [Obtaining the thumbprint for an OpenID Connect Identity Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc_verify-thumbprint.html). You'll need to check the thumbprint for the well-known URL `https://login.microsoftonline.com/{tenant}/v2.0/.well-known/openid-configuration` as described in [OpenID Connect on the Microsoft identity platform](https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-protocols-oidc#sample-request)
  - Ad

#### AWS Lambda

Hopefully soon... :smiley:

### Execution

To test your Function, you can use a sample payload using the PowerShell script below.

```powershell
# Replace your RoleARN with the one from your AWS Account
$header = @{ "x-functions-key" = "<Your Function Token>" }
$uri = "https://<your function address>/api/<your function name>"
$body = @"
{
  "cmd": [
    "ec2",
    "describe-instances"
  ],
  "aws_role_arn": "<your Role ARN>",
  "aws_session_name": "MDCShield",
  "aws_region": "us-east-2"
}
"@

Invoke-RestMethod -Method Post -Uri $uri -Body $body -Headers $header
```

In a Logic App, you can implement this by using the following steps:

- Use the Function Connector to call the Function, and use the output as the input for the next step.
- The payload must be in the above mentioned format, and you can parse the output json based in the standard schema sample (provided below), or use your own schema based in the expected output of the function, according to the json format your command will return.

```json
{
  "type": "object",
  "properties": {
    "status": {
      "type": "string"
    },
    "message": {
      "type": "string"
    },
    "data": {
      "type": "object"
    }
  }
}
```

## To Do

- [ ] Create a Custom Logic App Connector for easier usage in Logic Apps
- [ ] Create a extensible framework for custom or advanced remediation tasks
- [ ] Create a AWS Lambda function to be used as a custom connector for Logic Apps instead of Azure Function
- [ ] Reproduce the same concept for Azure and GCP

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License: [MIT](https://choosealicense.com/licenses/mit/)

```plaintext
MIT License

Copyright (c) 2023 Davi Cruz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
