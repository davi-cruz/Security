# Defender for Containers

## Evaluation Guide

### Enable Microsoft Defender for Containers

Please refer to [How to enable Microsoft Defender for Containers components - Microsoft Defender for Cloud | Microsoft Learn](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-containers-enable?tabs=aks-deploy-portal%2Ck8s-deploy-asc%2Ck8s-verify-asc%2Ck8s-remove-arc%2Caks-removeprofile-api&pivots=defender-for-container-aks) to prepare the subscription to be used for this evaluation.

Make sure to **enable auto provisioning for Defender DaemonSet and Azure Policy Extension for Kubernetes** so you won't need to take any additional step afterwards.

### Kubernetes Goat Deployment

To this evaluation we'll use a Standard AKS Managed Cluster and a Azure Container Registry. Resources can be deployed using the bicep template `main.bicep` located in this folder, which can be deployed using both PowerShell or Azure CLI. One example is provided below

```bash
rgName="MyResourceGroup"
resourceName="MyResourceName"
subscriptionName="MySubscriptionName"
location="eastus"

az login
az account set --subscription $subscriptionName

# Creates Azure Resource Group
az group create --name $rgName --location $location

parameters=$(cat <<EOF
{
    "resourceName": "$resourceName",
    "dnsPrefix": "${resourceName//-/}",
    "agentCount": 2,
    "linuxAdminUsername": "yourusername",
    "sshRSAPublicKey": "$(cat $HOME/.ssh/id_rsa.pub)"
}
EOF
)

az deployment group create --resource-group $rgName --template-file <path-to-bicep> --parameters $parameters
```

After deploying resources, we need to grant AKS Cluster rights on ACR as well as upload publicly available images to ACR so we can leverage Vulnerability Scanning capabilities from Defender for Containers. For this task I've created the script below:

```bash
# List of images to be uploaded
dockerHubImages=$(cat <<EOF
hacker-container
k8s-goat-batch-check
k8s-goat-build-code
k8s-goat-cache-store
k8s-goat-health-check
k8s-goat-hidden-in-layers
k8s-goat-home
k8s-goat-hunger-check
k8s-goat-info-app
k8s-goat-internal-api
k8s-goat-poor-registry
k8s-goat-system-monitor
EOF
)

dockerHubUser="madhuakula"

# Replace with your own values
acrName="myacr"
aksName="myaks"
rgName="myResourceGroup"
subscriptName="mySubscription"

az login
az account set --subscription $subscriptName
az aks update -n $aksName -g $rgName --attach-acr $acrName

for image in $dockerHubImages; do
    az acr import --name $acrName --source docker.io/$dockerHubUser/$image:latest
done
```

To Setup Kubernetes goat, we now need to do the exact same steps as advised in the [Kubernetes Goat](https://madhuakula.com/kubernetes-goat/) portal, but we should first make some adjustments first:

- Update all deployment files with the appropriate ACR name (as we're using ACR instead of Docker Hub)

```bash
git clone https://github.com/madhuakula/kubernetes-goat
cd kubernetes-goat
ACR_NAME="defendercontainersgoat"
find ./scenarios -type f -name '*.yaml' -exec sed -i "s/image: madhuakula/image: $ACR_NAME.azurecr.io/g" {} +
```

- Also, as AKS uses `containerd` instead of `docker` daemon, we have to fix `./scenarios/health-check/deployment.yaml` to mound a different sensitive directory (well use `/var` as it contains sensitive information in `/var/logs`)

```diff
         securityContext:
           privileged: true
         volumeMounts:
-          - mountPath: /custom/docker/docker.sock
-            name: docker-sock-volume
+          - mountPath: /var
+            name: logs
       volumes:
-        - name: docker-sock-volume
+        - name: logs
           hostPath:
-            path: /var/run/docker.sock
-            type: Socket
+            path: /var
+            type: Directory
 ---
 apiVersion: v1
 kind: Service
```

We can now proceed and run the setup script from `kubernetes-goat` folder:

```bash
bash ./setup-kubernetes-goat.sh
```

Now you're ready to start all scenarios from [the project website](https://madhuakula.com/kubernetes-goat/docs/scenarios/) :smile:

Note that there are some scenarios in this project which abuses of Node Ports and Docker Daemon, which won't work for AKS and other Cloud Managed K8s clusters.

Also keep in mind that Defender for Cloud separates detections in CSPM as Recommendations, while Defender for Containers detections are shown as Alerts. So you'll need to check both places to see all detections triggered by Kubernetes Goat.
