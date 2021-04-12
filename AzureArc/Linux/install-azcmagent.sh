#
# Install Azure Arc Using Service Principal, specifying proxy configuration
# in the script
#


# Variables
tenantID="TBD"
subscriptionID="TBD"
ResourceGroupName="TBD"
serviceprincipalAppID="TBD"
serviceprincipalSecret="TBD"
resourceLocation="TBD"
proxyUrl="" # Format: http[s]://server.fqdn:port
proxyArcOnly='true'

# Defines proxy to this execution
if [ -n "$proxyUrl"  ] && export https_proxy=$proxyUrl

# Download the installation package
wget https://aka.ms/azcmagent -O ~/install_linux_azcmagent.sh

# Configures proxy to service
if [ -n proxyUrl ]; then
    if [ proxyArcOnly == 'true']; then
        # Download proxy configuration script
        wget https://raw.githubusercontent.com/davi-cruz/Security/main/AzureArc/Linux/azcmagent_proxydaemon.sh -O ~/azcmagent_proxydaemon.sh
        bash ~/azcmagent_proxydaemon.sh $proxyUrl
        bash ~/install_linux_azcmagent.sh
    else
        # Install the hybrid agent
        bash ~/install_linux_azcmagent.sh --proxy $proxyUrl
    fi
else
    # Install the hybrid agent
    bash ~/install_linux_azcmagent.sh
fi

# Run connect command
azcmagent.exe connect --tenant-id $tenantID --subscription-id $subscriptionID \
    --resource-group $ResourceGroupName \
    --service-principal-id $serviceprincipalAppID \
    --service-principal-secret $serviceprincipalSecret \
    --location $resourceLocation \
    --cloud "AzureCloud

if [ $? = 0 ]; then echo "\033[33mTo view your onboarded server(s), navigate to https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.HybridCompute%2Fmachines\033[m"; fi