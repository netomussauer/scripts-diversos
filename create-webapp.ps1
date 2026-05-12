###########################
## Constants
###########################
# Azure tenant
SubscriptionId="c4c80dac-8a5d-4c20-b0b3-1d8a5634eebf"
# Azure location
Location="BrazilSouth"
# Environment
TenantName="Stone"
TenantShortName="Sto"
EnvName="Production"    # Production / Staging          / Test / Development / Homolog / QA
EnvShortName="P"        # P          / S                / T    / D           / H       / Q
# Service
ServiceName="Websites"
# Application name
ApplicationName="SiteMundi"

# App Service Plan
AppSvcPlanNumber="1"
AppSvcPlanSku="P2v2"
AppSvcPlanWorkersCount="1"

# WebApp 1 constants
WebApp1ShortName="SiteMundi"
WebApp1Fqdn="http://www.mundipagg.com"
WebApp1Runtime="php|7.1"
WebApp1PhpVersion="7.1"

###########################
## Variables
###########################
# Environment
TenantAndEnvShortName="${TenantShortName}-${EnvShortName}"
# Resource Group
RgName="${TenantAndEnvShortName}-${ServiceName}"
# App Service Plan
AppSvcPlanName="${TenantAndEnvShortName}-AppSvcPlan-${Location}-$(printf "%02.0f" $AppSvcPlanNumber)"

###########################
## Resource: App Service Plan
###########################
# Specify the subscription that you want to use
az account set --subscription $SubscriptionId

# Create an App Service Plan
if [[ -z $(az appservice plan show --name $AppSvcPlanName --resource-group $RgName) ]]; then az appservice plan create --name $AppSvcPlanName --sku $AppSvcPlanSku --number-of-workers $AppSvcPlanWorkersCount --resource-group $RgName --location $Location; fi

###########################
## Resource: WebApp 1
###########################
# Set variables
WebAppIndex="1"
eval "WebAppShortName=$(echo "\$WebApp${WebAppIndex}ShortName")"
eval "WebAppFqdn=$(echo "\$WebApp${WebAppIndex}Fqdn")"
eval "WebAppRuntime=$(echo "\$WebApp${WebAppIndex}Runtime")"
eval "WebAppPhpVersion=$(echo "\$WebApp${WebAppIndex}PhpVersion")"
eval "WebAppPythonVersion=$(echo "\$WebApp${WebAppIndex}PythonVersion")"
WebAppFullName="${TenantAndEnvShortName}-WebApp-${WebAppShortName}"

# Create the Web App
if [[ -z $(az webapp show --name $WebAppFullName --resource-group $RgName) ]]; then az webapp create --name $WebAppFullName --plan $AppSvcPlanName --resource-group $RgName --runtime $WebAppRuntime; fi

# Assign App Settings in the Web App
az webapp config appsettings set --settings "PHPMYADMIN_EXTENSION_VERSION=latest" --name $WebAppFullName --resource-group $RgName
az webapp config appsettings set --settings "WEBSITE_DYNAMIC_CACHE=0" --name $WebAppFullName --resource-group $RgName
az webapp config appsettings delete --setting-names "WEBSITE_NODE_DEFAULT_VERSION" --name $WebAppFullName --resource-group $RgName
# Optional
#az webapp config appsettings set --settings "WEBSITE_MYSQL_ENABLED=1" --name $WebAppName --resource-group $RgName
#az webapp config appsettings set --settings "WEBSITE_MYSQL_GENERAL_LOG=0" --name $WebAppName --resource-group $RgName
#az webapp config appsettings set --settings "WEBSITE_MYSQL_SLOW_QUERY_LOG=0" --name $WebAppName --resource-group $RgName
#az webapp config appsettings set --settings "WEBSITE_MYSQL_ARGUMENTS=--max_allowed_packet=16M" --name $WebAppName --resource-group $RgName

az webapp config set --name $WebAppFullName --resource-group $RgName --php-version "${WebAppPhpVersion}"
az webapp config set --name $WebAppFullName --resource-group $RgName --python-version "${WebAppPythonVersion}"
az webapp config set --name $WebAppFullName --resource-group $RgName --use-32bit-worker-process true
az webapp config set --name $WebAppFullName --resource-group $RgName --web-sockets-enabled false
az webapp config set --name $WebAppFullName --resource-group $RgName --always-on true
az webapp config set --name $WebAppFullName --resource-group $RgName --remote-debugging-enabled false