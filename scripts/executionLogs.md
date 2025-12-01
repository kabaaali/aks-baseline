./01-setup-entra-id.sh 
==================================================
Azure Entra ID Setup for AKS RBAC
==================================================
✓ Loaded environment configuration

Step 1: Login to Azure
----------------------
A web browser has been opened at https://login.microsoftonline.com/organizations/oauth2/v2.0/authorize. Please continue the login in the web browser. If no web browser is available or if the web browser fails to open, use device code flow with `az login --use-device-code`.

Retrieving tenants and subscriptions for the selection...
Authentication failed against tenant ec118f83-eba5-41ac-8edf-bacd6d978317 'Default Directory': AADSTS5000225: This tenant has been blocked due to inactivity. To learn more about tenant lifecycle policies, see https://aka.ms/TenantLifecycle Trace ID: 6a613f29-75c2-4ff5-85eb-910862794a00 Correlation ID: b2e2b3cd-c327-4c0c-b0ea-ff6bf55be240 Timestamp: 2025-11-26 06:42:40Z
If you need to access subscriptions in the following tenants, please use `az login --tenant TENANT_ID`.
ec118f83-eba5-41ac-8edf-bacd6d978317 'Default Directory'

[Tenant and subscription selection]

No     Subscription name     Subscription ID                       Tenant
-----  --------------------  ------------------------------------  -----------------
[1] *  Azure subscription 1  da68dfda-5d63-42ff-b28c-4e44e79e13b1  Default Directory

The default is marked with an *; the default tenant is 'Default Directory' and subscription is 'Azure subscription 1' (da68dfda-5d63-42ff-b28c-4e44e79e13b1).

Select a subscription and tenant (Type a number or Enter for no changes): 

Tenant: Default Directory
Subscription: Azure subscription 1 (da68dfda-5d63-42ff-b28c-4e44e79e13b1)

[Announcements]
With the new Azure CLI login experience, you can select the subscription you want to use more easily. Learn more about it and its configuration at https://go.microsoft.com/fwlink/?linkid=2271236

If you encounter any problem, please open an issue at https://aka.ms/azclibug

[Warning] The login output has been updated. Please be aware that it no longer displays the full list of available subscriptions by default.

✓ Logged in to Azure subscription: da68dfda-5d63-42ff-b28c-4e44e79e13b1

Step 2: Get Tenant Information
-------------------------------
✓ Tenant ID: 8b00db25-a991-48c8-b92d-384c8be1fa14

Step 3: Create App Registration for API
----------------------------------------
This single app registration will be used for:
  - APIM managed identity authentication
  - AKS microservice token validation

✓ Created app registration: aks-hello-world-api
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#servicePrincipals/$entity",
  "accountEnabled": true,
  "addIns": [],
  "alternativeNames": [],
  "appDescription": null,
  "appDisplayName": "aks-hello-world-api",
  "appId": "ded658c3-3903-4f40-bf82-893c1f0e824f",
  "appOwnerOrganizationId": "8b00db25-a991-48c8-b92d-384c8be1fa14",
  "appRoleAssignmentRequired": false,
  "appRoles": [],
  "applicationTemplateId": null,
  "createdDateTime": null,
  "deletedDateTime": null,
  "description": null,
  "disabledByMicrosoftStatus": null,
  "displayName": "aks-hello-world-api",
  "homepage": null,
  "id": "69ea72b5-fffc-4f02-b348-b19954937674",
  "info": {
    "logoUrl": null,
    "marketingUrl": null,
    "privacyStatementUrl": null,
    "supportUrl": null,
    "termsOfServiceUrl": null
  },
  "keyCredentials": [],
  "loginUrl": null,
  "logoutUrl": null,
  "notes": null,
  "notificationEmailAddresses": [],
  "oauth2PermissionScopes": [],
  "passwordCredentials": [],
  "preferredSingleSignOnMode": null,
  "preferredTokenSigningKeyThumbprint": null,
  "replyUrls": [],
  "resourceSpecificApplicationPermissions": [],
  "samlSingleSignOnSettings": null,
  "servicePrincipalNames": [
    "ded658c3-3903-4f40-bf82-893c1f0e824f"
  ],
  "servicePrincipalType": "Application",
  "signInAudience": "AzureADMyOrg",
  "tags": [],
  "tokenEncryptionKeyId": null,
  "verifiedPublisher": {
    "addedDateTime": null,
    "displayName": null,
    "verifiedPublisherId": null
  }
}
✓ Created service principal
  App ID: ded658c3-3903-4f40-bf82-893c1f0e824f

Step 4: Configure API Identifier URI
-------------------------------------
✓ Set identifier URI: api://ded658c3-3903-4f40-bf82-893c1f0e824f

Step 5: Create App Role for APIM
---------------------------------
⚠ Manual step required:
  1. Go to Azure Portal > Entra ID > App Registrations
  2. Select: aks-hello-world-api
  3. Go to 'App roles' > 'Create app role'
  4. Display name: API.Access
  5. Allowed member types: Applications
  6. Value: API.Access
  7. Description: Allow APIM to access the API
  8. Click 'Apply'

Note: This app role will be assigned to APIM's managed identity later

Press Enter after completing the manual step...

Step 6: Save Configuration
--------------------------
✓ Configuration saved to config/entra-id-config.env

==================================================
Azure Entra ID Setup Complete!
==================================================

Configuration Summary:
  Tenant ID: 8b00db25-a991-48c8-b92d-384c8be1fa14
  API App ID: ded658c3-3903-4f40-bf82-893c1f0e824f

Authentication Flow:
  Client → APIM (subscription key)
  APIM → AKS (OAuth token using API App ID)

Next Steps:
  1. Source the configuration: source config/entra-id-config.env
  2. Run: ./scripts/02-configure-aks-cluster.sh

Rekhas-MacBook-Pro-2:scripts rekhasunil$ ./02-configure-aks-cluster.sh
==================================================
AKS Cluster Configuration for Workload Identity
==================================================
✓ Loaded configuration

Step 1: Connect to AKS Cluster
-------------------------------
Merged "skg-aks-cluster" as current context in /Users/rekhasunil/.kube/config
Converted kubeconfig to use Azure CLI authentication.
✓ Connected to AKS cluster: skg-aks-cluster
Kubernetes control plane is running at https://skg-aks-cluster-dns-vwseq1vp.hcp.australiaeast.azmk8s.io:443
CoreDNS is running at https://skg-aks-cluster-dns-vwseq1vp.hcp.australiaeast.azmk8s.io:443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://skg-aks-cluster-dns-vwseq1vp.hcp.australiaeast.azmk8s.io:443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
NAME                                STATUS   ROLES    AGE     VERSION
aks-agentpool-29449757-vmss000000   Ready    <none>   5h58m   v1.32.9
aks-app1-29449757-vms1              Ready    <none>   5h58m   v1.32.9

Step 2: Check Workload Identity Status
---------------------------------------
  OIDC Issuer: true
  Workload Identity: true

Step 3: Get OIDC Issuer URL
---------------------------
✓ OIDC Issuer URL: https://australiaeast.oic.prod-aks.azure.com/8b00db25-a991-48c8-b92d-384c8be1fa14/463c0a15-21fc-44cb-82ee-40c0b1f0a342/

Step 4: Verify RBAC is Enabled
-------------------------------
✓ RBAC is enabled

Step 5: Setup Azure Container Registry
---------------------------------------
✓ ACR already exists: acrskg

Attaching ACR to AKS cluster...
AAD role propagation done[############################################]  100.0000%keyvaultid: None, enable_kv: True
{
  "aadProfile": {
    "adminGroupObjectIDs": null,
    "adminUsers": null,
    "clientAppId": null,
    "enableAzureRbac": true,
    "managed": true,
    "serverAppId": null,
    "serverAppSecret": null,
    "tenantId": "8b00db25-a991-48c8-b92d-384c8be1fa14"
  },
  "addonProfiles": {
    "azureKeyvaultSecretsProvider": {
      "config": {
        "enableSecretRotation": "false",
        "rotationPollInterval": "2m"
      },
      "enabled": true,
      "identity": {
        "clientId": "1718dd90-ccd2-4547-a869-c9c66955a474",
        "objectId": "10b7097d-d273-4aa8-b896-a3aa29d95575",
        "resourceId": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourcegroups/MC_aks-test-rg_skg-aks-cluster_australiaeast/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azurekeyvaultsecretsprovider-skg-aks-cluster"
      }
    },
    "azurepolicy": {
      "config": null,
      "enabled": true,
      "identity": {
        "clientId": "3fb6d5b2-b022-4a21-b8c9-5599d194fc04",
        "objectId": "51039d90-7838-4c9c-bcbc-30e17ba32fd3",
        "resourceId": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourcegroups/MC_aks-test-rg_skg-aks-cluster_australiaeast/providers/Microsoft.ManagedIdentity/userAssignedIdentities/azurepolicy-skg-aks-cluster"
      }
    },
    "omsAgent": {
      "config": {
        "logAnalyticsWorkspaceResourceID": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourcegroups/DefaultResourceGroup-EAU/providers/Microsoft.OperationalInsights/workspaces/logsaks",
        "useAADAuth": "true"
      },
      "enabled": true,
      "identity": null
    }
  },
  "agentPoolProfiles": [
    {
      "availabilityZones": [
        "1",
        "2",
        "3"
      ],
      "capacityReservationGroupId": null,
      "count": 1,
      "creationData": null,
      "currentOrchestratorVersion": "1.32.9",
      "eTag": "1cd9ee33-2bb5-4ff1-a44c-5e8048a2ffab",
      "enableAutoScaling": false,
      "enableEncryptionAtHost": null,
      "enableFips": false,
      "enableNodePublicIp": false,
      "enableUltraSsd": null,
      "gatewayProfile": null,
      "gpuInstanceProfile": null,
      "gpuProfile": null,
      "hostGroupId": null,
      "kubeletConfig": null,
      "kubeletDiskType": "OS",
      "linuxOsConfig": null,
      "localDnsProfile": null,
      "maxCount": null,
      "maxPods": 110,
      "messageOfTheDay": null,
      "minCount": null,
      "mode": "System",
      "name": "agentpool",
      "networkProfile": null,
      "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202511.07.0",
      "nodeLabels": null,
      "nodePublicIpPrefixId": null,
      "nodeTaints": null,
      "orchestratorVersion": "1.32.9",
      "osDiskSizeGb": 128,
      "osDiskType": "Managed",
      "osSku": "Ubuntu",
      "osType": "Linux",
      "podIpAllocationMode": null,
      "podSubnetId": null,
      "powerState": {
        "code": "Running"
      },
      "provisioningState": "Succeeded",
      "proximityPlacementGroupId": null,
      "scaleDownMode": "Delete",
      "scaleSetEvictionPolicy": null,
      "scaleSetPriority": null,
      "securityProfile": {
        "enableSecureBoot": false,
        "enableVtpm": false,
        "sshAccess": null
      },
      "spotMaxPrice": null,
      "status": null,
      "tags": null,
      "type": "VirtualMachineScaleSets",
      "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "10%",
        "maxUnavailable": "0",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": null
      },
      "virtualMachineNodesStatus": null,
      "virtualMachinesProfile": null,
      "vmSize": "Standard_D2as_v5",
      "vnetSubnetId": null,
      "windowsProfile": null,
      "workloadRuntime": null
    },
    {
      "availabilityZones": [
        "1",
        "2",
        "3"
      ],
      "capacityReservationGroupId": null,
      "count": null,
      "creationData": null,
      "currentOrchestratorVersion": "1.32.9",
      "eTag": "03de0b30-296b-4bab-a62b-58b69ba3910d",
      "enableAutoScaling": null,
      "enableEncryptionAtHost": null,
      "enableFips": false,
      "enableNodePublicIp": false,
      "enableUltraSsd": null,
      "gatewayProfile": null,
      "gpuInstanceProfile": null,
      "gpuProfile": null,
      "hostGroupId": null,
      "kubeletConfig": null,
      "kubeletDiskType": "OS",
      "linuxOsConfig": null,
      "localDnsProfile": null,
      "maxCount": null,
      "maxPods": 30,
      "messageOfTheDay": null,
      "minCount": null,
      "mode": "System",
      "name": "app1",
      "networkProfile": null,
      "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202511.07.0",
      "nodeLabels": null,
      "nodePublicIpPrefixId": null,
      "nodeTaints": null,
      "orchestratorVersion": "1.32.9",
      "osDiskSizeGb": 128,
      "osDiskType": "Managed",
      "osSku": "Ubuntu",
      "osType": "Linux",
      "podIpAllocationMode": null,
      "podSubnetId": null,
      "powerState": {
        "code": "Running"
      },
      "provisioningState": "Succeeded",
      "proximityPlacementGroupId": null,
      "scaleDownMode": "Delete",
      "scaleSetEvictionPolicy": null,
      "scaleSetPriority": null,
      "securityProfile": {
        "enableSecureBoot": false,
        "enableVtpm": false,
        "sshAccess": null
      },
      "spotMaxPrice": null,
      "status": null,
      "tags": null,
      "type": "VirtualMachines",
      "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "10%",
        "maxUnavailable": "0",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": null
      },
      "virtualMachineNodesStatus": [
        {
          "count": 1,
          "size": "Standard_D2as_v5"
        }
      ],
      "virtualMachinesProfile": {
        "scale": {
          "manual": [
            {
              "count": 1,
              "size": "Standard_D2as_v5"
            }
          ]
        }
      },
      "vmSize": "",
      "vnetSubnetId": null,
      "windowsProfile": null,
      "workloadRuntime": null
    }
  ],
  "aiToolchainOperatorProfile": null,
  "apiServerAccessProfile": {
    "authorizedIpRanges": null,
    "disableRunCommand": null,
    "enablePrivateCluster": false,
    "enablePrivateClusterPublicFqdn": null,
    "enableVnetIntegration": null,
    "privateDnsZone": null,
    "subnetId": null
  },
  "autoScalerProfile": null,
  "autoUpgradeProfile": {
    "nodeOsUpgradeChannel": "NodeImage",
    "upgradeChannel": "patch"
  },
  "azureMonitorProfile": {
    "metrics": {
      "enabled": true,
      "kubeStateMetrics": {
        "metricAnnotationsAllowList": "",
        "metricLabelsAllowlist": ""
      }
    }
  },
  "azurePortalFqdn": "skg-aks-cluster-dns-vwseq1vp.portal.hcp.australiaeast.azmk8s.io",
  "bootstrapProfile": {
    "artifactSource": "Direct",
    "containerRegistryId": null
  },
  "currentKubernetesVersion": "1.32.9",
  "disableLocalAccounts": true,
  "diskEncryptionSetId": null,
  "dnsPrefix": "skg-aks-cluster-dns",
  "eTag": "b3f1a485-1aad-40a1-b834-9e68a4b863e8",
  "enableRbac": true,
  "extendedLocation": null,
  "fqdn": "skg-aks-cluster-dns-vwseq1vp.hcp.australiaeast.azmk8s.io",
  "fqdnSubdomain": null,
  "httpProxyConfig": null,
  "id": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourcegroups/aks-test-rg/providers/Microsoft.ContainerService/managedClusters/skg-aks-cluster",
  "identity": {
    "delegatedResources": null,
    "principalId": "7d014a9a-bca0-4a16-a88e-59fd5b1c74ef",
    "tenantId": "8b00db25-a991-48c8-b92d-384c8be1fa14",
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "identityProfile": {
    "kubeletidentity": {
      "clientId": "d24c6028-bd5d-4163-9464-02aed0ee7fad",
      "objectId": "f5f33eca-5d06-41c0-b838-b51394daaf8b",
      "resourceId": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourcegroups/MC_aks-test-rg_skg-aks-cluster_australiaeast/providers/Microsoft.ManagedIdentity/userAssignedIdentities/skg-aks-cluster-agentpool"
    }
  },
  "ingressProfile": null,
  "kind": "Base",
  "kubernetesVersion": "1.32.9",
  "linuxProfile": null,
  "location": "australiaeast",
  "maxAgentPools": 100,
  "metricsProfile": {
    "costAnalysis": {
      "enabled": false
    }
  },
  "name": "skg-aks-cluster",
  "networkProfile": {
    "advancedNetworking": null,
    "dnsServiceIp": "10.0.0.10",
    "ipFamilies": [
      "IPv4"
    ],
    "loadBalancerProfile": {
      "allocatedOutboundPorts": null,
      "backendPoolType": "nodeIPConfiguration",
      "effectiveOutboundIPs": [
        {
          "id": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourceGroups/MC_aks-test-rg_skg-aks-cluster_australiaeast/providers/Microsoft.Network/publicIPAddresses/dda3e7aa-e771-4c36-9f00-537e3afa4b9e",
          "resourceGroup": "MC_aks-test-rg_skg-aks-cluster_australiaeast"
        }
      ],
      "enableMultipleStandardLoadBalancers": null,
      "idleTimeoutInMinutes": null,
      "managedOutboundIPs": {
        "count": 1,
        "countIpv6": null
      },
      "outboundIPs": null,
      "outboundIpPrefixes": null
    },
    "loadBalancerSku": "standard",
    "natGatewayProfile": null,
    "networkDataplane": "cilium",
    "networkMode": null,
    "networkPlugin": "azure",
    "networkPluginMode": "overlay",
    "networkPolicy": "cilium",
    "outboundType": "loadBalancer",
    "podCidr": "10.244.0.0/16",
    "podCidrs": [
      "10.244.0.0/16"
    ],
    "serviceCidr": "10.0.0.0/16",
    "serviceCidrs": [
      "10.0.0.0/16"
    ],
    "staticEgressGatewayProfile": null
  },
  "nodeProvisioningProfile": {
    "defaultNodePools": "Auto",
    "mode": "Manual"
  },
  "nodeResourceGroup": "MC_aks-test-rg_skg-aks-cluster_australiaeast",
  "nodeResourceGroupProfile": null,
  "oidcIssuerProfile": {
    "enabled": true,
    "issuerUrl": "https://australiaeast.oic.prod-aks.azure.com/8b00db25-a991-48c8-b92d-384c8be1fa14/463c0a15-21fc-44cb-82ee-40c0b1f0a342/"
  },
  "podIdentityProfile": null,
  "powerState": {
    "code": "Running"
  },
  "privateFqdn": null,
  "privateLinkResources": null,
  "provisioningState": "Succeeded",
  "publicNetworkAccess": null,
  "resourceGroup": "aks-test-rg",
  "resourceUid": "69264db8e7d398000190f100",
  "securityProfile": {
    "azureKeyVaultKms": null,
    "customCaTrustCertificates": null,
    "defender": null,
    "imageCleaner": {
      "enabled": true,
      "intervalHours": 168
    },
    "workloadIdentity": {
      "enabled": true
    }
  },
  "serviceMeshProfile": {
    "istio": {
      "certificateAuthority": null,
      "components": {
        "egressGateways": null,
        "ingressGateways": [
          {
            "enabled": true,
            "mode": "Internal"
          },
          {
            "enabled": null,
            "mode": "External"
          }
        ]
      },
      "revisions": [
        "asm-1-26"
      ]
    },
    "mode": "Istio"
  },
  "servicePrincipalProfile": {
    "clientId": "msi",
    "secret": null
  },
  "sku": {
    "name": "Base",
    "tier": "Free"
  },
  "status": null,
  "storageProfile": {
    "blobCsiDriver": null,
    "diskCsiDriver": {
      "enabled": true
    },
    "fileCsiDriver": {
      "enabled": true
    },
    "snapshotController": {
      "enabled": true
    }
  },
  "supportPlan": "KubernetesOfficial",
  "systemData": null,
  "tags": null,
  "type": "Microsoft.ContainerService/ManagedClusters",
  "upgradeSettings": null,
  "windowsProfile": {
    "adminPassword": null,
    "adminUsername": "azureuser",
    "enableCsiProxy": true,
    "gmsaProfile": null,
    "licenseType": null
  },
  "workloadAutoScalerProfile": {
    "keda": null,
    "verticalPodAutoscaler": null
  }
}
✓ ACR attached to AKS cluster

Step 6: Create Federated Identity Credential
---------------------------------------------
Creating federated identity credential...
{
  "@odata.context": "https://graph.microsoft.com/v1.0/$metadata#applications('13b4280a-967a-4ea7-94f4-9fd0cf384eab')/federatedIdentityCredentials/$entity",
  "audiences": [
    "api://AzureADTokenExchange"
  ],
  "description": null,
  "id": "ed237e2b-b80f-4908-a19d-abbd622ac826",
  "issuer": "https://australiaeast.oic.prod-aks.azure.com/8b00db25-a991-48c8-b92d-384c8be1fa14/463c0a15-21fc-44cb-82ee-40c0b1f0a342/",
  "name": "kubernetes-federated-credential",
  "subject": "system:serviceaccount:hello-world:hello-world-sa"
}
✓ Federated identity credential created

Step 7: Save Configuration
--------------------------
✓ Configuration updated

==================================================
AKS Cluster Configuration Complete!
==================================================

Configuration Summary:
  Cluster: skg-aks-cluster
  OIDC Issuer: https://australiaeast.oic.prod-aks.azure.com/8b00db25-a991-48c8-b92d-384c8be1fa14/463c0a15-21fc-44cb-82ee-40c0b1f0a342/
  Workload Identity: Enabled
  RBAC: Enabled
  ACR: acrskg

Next Steps:
  1. Run: ./scripts/03-build-and-deploy.sh

  ./03-build-and-deploy.sh 
==================================================
Build and Deploy Microservice to AKS
==================================================
✓ Loaded configuration

Step 1: Update Kubernetes Manifests
------------------------------------
✓ Updated manifests with configuration values

Step 2: Update appsettings.json
--------------------------------
✓ Updated appsettings.json

Step 3: Build Docker Image
--------------------------
Building image: acrskg.azurecr.io/hello-world-service:v1
[+] Building 0.6s (17/17) FINISHED                                                                                                                                                docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                              0.0s
 => => transferring dockerfile: 951B                                                                                                                                                              0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/aspnet:8.0                                                                                                                              0.5s
 => [internal] load metadata for mcr.microsoft.com/dotnet/sdk:8.0                                                                                                                                 0.5s
 => [internal] load .dockerignore                                                                                                                                                                 0.0s
 => => transferring context: 2B                                                                                                                                                                   0.0s
 => [build 1/6] FROM mcr.microsoft.com/dotnet/sdk:8.0@sha256:874c4613d5ebf8b328ad920a90640c8dea9758bdbe61dc191dbcbed03721fc79                                                                     0.0s
 => [internal] load build context                                                                                                                                                                 0.0s
 => => transferring context: 684B                                                                                                                                                                 0.0s
 => [runtime 1/5] FROM mcr.microsoft.com/dotnet/aspnet:8.0@sha256:47091f7cee02e448630df85542579e09b7bbe3b10bd4e1991ff59d3adbddd720                                                                0.0s
 => CACHED [runtime 2/5] WORKDIR /app                                                                                                                                                             0.0s
 => CACHED [runtime 3/5] RUN groupadd -r appuser && useradd -r -g appuser appuser                                                                                                                 0.0s
 => CACHED [build 2/6] WORKDIR /src                                                                                                                                                               0.0s
 => CACHED [build 3/6] COPY *.csproj ./                                                                                                                                                           0.0s
 => CACHED [build 4/6] RUN dotnet restore                                                                                                                                                         0.0s
 => CACHED [build 5/6] COPY . ./                                                                                                                                                                  0.0s
 => CACHED [build 6/6] RUN dotnet publish -c Release -o /app/publish                                                                                                                              0.0s
 => CACHED [runtime 4/5] COPY --from=build /app/publish .                                                                                                                                         0.0s
 => CACHED [runtime 5/5] RUN chown -R appuser:appuser /app                                                                                                                                        0.0s
 => exporting to image                                                                                                                                                                            0.0s
 => => exporting layers                                                                                                                                                                           0.0s
 => => writing image sha256:8416f845068c46dc68b74e9f8e689714345886354096aecaee2ddde3b97ebddc                                                                                                      0.0s
 => => naming to acrskg.azurecr.io/hello-world-service:v1                                                                                                                                         0.0s

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview 
✓ Docker image built successfully

Step 4: Login to ACR
--------------------
Login Succeeded
✓ Logged in to ACR

Step 5: Push Image to ACR
-------------------------
The push refers to repository [acrskg.azurecr.io/hello-world-service]
45cf62f7b763: Pushed 
9d7ca73e2ae5: Pushed 
6e931683cae2: Pushed 
b6b94318a1bf: Pushed 
031bb123f762: Pushed 
aeb7f70c13d1: Pushed 
f0b8ee344f14: Pushed 
d554dfe2590f: Pushed 
b8293e23ac8d: Pushed 
bd2be69c2f99: Pushed 
v1: digest: sha256:859f8fd9c5b90e3a004a210cd364967105ad1780ed7282b934d19d132366874f size: 2416
✓ Image pushed to ACR
CreatedTime                   ImageName            LastUpdateTime                ManifestCount    Registry           TagCount
----------------------------  -------------------  ----------------------------  ---------------  -----------------  ----------
2025-11-26T11:34:08.7833574Z  hello-world-service  2025-11-26T11:34:08.9060667Z  1                acrskg.azurecr.io  1

Step 6: Apply Kubernetes Manifests
-----------------------------------
namespace/hello-world created
✓ Namespace created/updated
serviceaccount/hello-world-sa created
role.rbac.authorization.k8s.io/hello-world-role created
rolebinding.rbac.authorization.k8s.io/hello-world-rolebinding created
✓ RBAC configured
deployment.apps/hello-world-deployment created
✓ Deployment created/updated
service/hello-world-service created
✓ Service created/updated
ingress.networking.k8s.io/hello-world-ingress created

Step 7: Wait for Deployment
---------------------------
Waiting for deployment to be ready...
Waiting for deployment "hello-world-deployment" rollout to finish: 0 of 2 updated replicas are available...
error: timed out waiting for the condition
Rekhas-MacBook-Pro-2:scripts rekhasunil$ ./03-build-and-deploy.sh 
==================================================
Build and Deploy Microservice to AKS
==================================================
✓ Loaded configuration

Step 1: Update Kubernetes Manifests
------------------------------------
✓ Updated manifests with configuration values

Step 2: Update appsettings.json
--------------------------------
✓ Updated appsettings.json

Step 3: Build Docker Image
--------------------------
Building image: acrskg.azurecr.io/hello-world-service:v1
[+] Building 0.8s (17/17) FINISHED                                                                                                                                                docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                              0.0s
 => => transferring dockerfile: 951B                                                                                                                                                              0.0s
 => [internal] load metadata for mcr.microsoft.com/dotnet/sdk:8.0                                                                                                                                 0.7s
 => [internal] load metadata for mcr.microsoft.com/dotnet/aspnet:8.0                                                                                                                              0.7s
 => [internal] load .dockerignore                                                                                                                                                                 0.0s
 => => transferring context: 2B                                                                                                                                                                   0.0s
 => [build 1/6] FROM mcr.microsoft.com/dotnet/sdk:8.0@sha256:874c4613d5ebf8b328ad920a90640c8dea9758bdbe61dc191dbcbed03721fc79                                                                     0.0s
 => [runtime 1/5] FROM mcr.microsoft.com/dotnet/aspnet:8.0@sha256:47091f7cee02e448630df85542579e09b7bbe3b10bd4e1991ff59d3adbddd720                                                                0.0s
 => [internal] load build context                                                                                                                                                                 0.0s
 => => transferring context: 684B                                                                                                                                                                 0.0s
 => CACHED [runtime 2/5] WORKDIR /app                                                                                                                                                             0.0s
 => CACHED [runtime 3/5] RUN groupadd -r appuser && useradd -r -g appuser appuser                                                                                                                 0.0s
 => CACHED [build 2/6] WORKDIR /src                                                                                                                                                               0.0s
 => CACHED [build 3/6] COPY *.csproj ./                                                                                                                                                           0.0s
 => CACHED [build 4/6] RUN dotnet restore                                                                                                                                                         0.0s
 => CACHED [build 5/6] COPY . ./                                                                                                                                                                  0.0s
 => CACHED [build 6/6] RUN dotnet publish -c Release -o /app/publish                                                                                                                              0.0s
 => CACHED [runtime 4/5] COPY --from=build /app/publish .                                                                                                                                         0.0s
 => CACHED [runtime 5/5] RUN chown -R appuser:appuser /app                                                                                                                                        0.0s
 => exporting to image                                                                                                                                                                            0.0s
 => => exporting layers                                                                                                                                                                           0.0s
 => => writing image sha256:8416f845068c46dc68b74e9f8e689714345886354096aecaee2ddde3b97ebddc                                                                                                      0.0s
 => => naming to acrskg.azurecr.io/hello-world-service:v1                                                                                                                                         0.0s

What's next:
    View a summary of image vulnerabilities and recommendations → docker scout quickview 
✓ Docker image built successfully

Step 4: Login to ACR
--------------------
Login Succeeded
2025/11/26 22:47:00 notifying Desktop of credentials store update: Post "http://ipc/registry/credstore-updated": context deadline exceeded
✓ Logged in to ACR

Step 5: Push Image to ACR
-------------------------
The push refers to repository [acrskg.azurecr.io/hello-world-service]
45cf62f7b763: Layer already exists 
9d7ca73e2ae5: Layer already exists 
6e931683cae2: Layer already exists 
b6b94318a1bf: Layer already exists 
031bb123f762: Layer already exists 
aeb7f70c13d1: Layer already exists 
f0b8ee344f14: Layer already exists 
d554dfe2590f: Layer already exists 
b8293e23ac8d: Layer already exists 
bd2be69c2f99: Layer already exists 
v1: digest: sha256:859f8fd9c5b90e3a004a210cd364967105ad1780ed7282b934d19d132366874f size: 2416
✓ Image pushed to ACR
CreatedTime                   ImageName            LastUpdateTime                ManifestCount    Registry           TagCount
----------------------------  -------------------  ----------------------------  ---------------  -----------------  ----------
2025-11-26T11:34:08.7833574Z  hello-world-service  2025-11-26T11:34:08.9060667Z  1                acrskg.azurecr.io  1

Step 6: Apply Kubernetes Manifests
-----------------------------------
namespace/hello-world unchanged
✓ Namespace created/updated
serviceaccount/hello-world-sa unchanged
role.rbac.authorization.k8s.io/hello-world-role unchanged
rolebinding.rbac.authorization.k8s.io/hello-world-rolebinding unchanged
✓ RBAC configured
deployment.apps/hello-world-deployment configured
✓ Deployment created/updated
service/hello-world-service unchanged
✓ Service created/updated
ingress.networking.k8s.io/hello-world-ingress unchanged

Step 7: Wait for Deployment
---------------------------
Waiting for deployment to be ready...
Waiting for deployment "hello-world-deployment" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "hello-world-deployment" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "hello-world-deployment" rollout to finish: 1 old replicas are pending termination...
deployment "hello-world-deployment" successfully rolled out

Step 8: Verify Deployment
-------------------------

Pods:
NAME                                      READY   STATUS      RESTARTS   AGE
hello-world-deployment-6b46d76ddf-qbkgd   0/1     Completed   6          4m44s
hello-world-deployment-74cb4758fd-68ckg   1/1     Running     0          15s

Services:
NAME                  TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)        AGE
hello-world-service   LoadBalancer   10.0.103.0   4.237.126.197   80:30398/TCP   13m

Service Account:
Name:                hello-world-sa
Namespace:           hello-world
Labels:              azure.workload.identity/use=true
Annotations:         azure.workload.identity/client-id: ded658c3-3903-4f40-bf82-893c1f0e824f
Image pull secrets:  <none>
Mountable secrets:   <none>
Tokens:              <none>
Events:              <none>

Step 9: Get Service Endpoint
-----------------------------
Waiting for external IP (this may take a few minutes)...
✓ Service external IP: 4.237.126.197

Step 10: Test Service Directly
-------------------------------
Testing health endpoint...
Healthy
Testing public endpoint...
{"message":"Hello from AKS! (Public endpoint)","authenticated":false,"timestamp":"2025-11-26T11:47:36.0022229Z"}
Step 11: Check Pod Logs
-----------------------
Latest logs from hello-world-deployment-74cb4758fd-68ckg:
warn: Program[0]
      No Authorization header found
info: Program[0]
      Incoming request: GET /health
warn: Program[0]
      No Authorization header found
info: Program[0]
      Incoming request: GET /health
warn: Program[0]
      No Authorization header found
info: Program[0]
      Incoming request: GET /api/hello/public
warn: Program[0]
      No Authorization header found
info: HelloWorldService.Controllers.HelloController[0]
      Public hello endpoint called
info: Program[0]
      Incoming request: GET /health
warn: Program[0]
      No Authorization header found

Step 12: Save Service Configuration
------------------------------------
✓ Configuration updated

==================================================
Deployment Complete!
==================================================

Deployment Summary:
  Image: acrskg.azurecr.io/hello-world-service:v1
  Namespace: hello-world
  Service IP: 4.237.126.197
  Health URL: http://4.237.126.197/health
  Public API: http://4.237.126.197/api/hello/public
  Protected API: http://4.237.126.197/api/hello (requires auth)

Next Steps:
  1. Test the service: curl http://4.237.126.197/health
  2. Run: ./scripts/04-setup-apim.sh


---
./04-setup-apim.sh 
==================================================
Azure API Management Setup
==================================================
✓ Loaded configuration

Step 1: Check/Create APIM Instance
-----------------------------------
✓ APIM instance exists: pocskgapim

Step 2: Enable Managed Identity on APIM
----------------------------------------
{
  "additionalLocations": null,
  "apiVersionConstraint": {
    "minApiVersion": null
  },
  "certificates": null,
  "createdAtUtc": "2025-11-26T05:53:58.484787+00:00",
  "customProperties": {
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10": "False",
    "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11": "False"
  },
  "developerPortalUrl": "https://pocskgapim.developer.azure-api.net",
  "disableGateway": false,
  "enableClientCertificate": null,
  "etag": "AAAAAADvvRk=",
  "gatewayRegionalUrl": "https://pocskgapim-australiaeast-01.regional.azure-api.net",
  "gatewayUrl": "https://pocskgapim.azure-api.net",
  "hostnameConfigurations": [
    {
      "certificate": null,
      "certificatePassword": null,
      "certificateSource": "BuiltIn",
      "certificateStatus": null,
      "defaultSslBinding": true,
      "encodedCertificate": null,
      "hostName": "pocskgapim.azure-api.net",
      "identityClientId": null,
      "keyVaultId": null,
      "negotiateClientCertificate": false,
      "type": "Proxy"
    }
  ],
  "id": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourceGroups/apim-poc-rg/providers/Microsoft.ApiManagement/service/pocskgapim",
  "identity": {
    "principalId": "cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a",
    "tenantId": "8b00db25-a991-48c8-b92d-384c8be1fa14",
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "location": "Australia East",
  "managementApiUrl": "https://pocskgapim.management.azure-api.net",
  "name": "pocskgapim",
  "natGatewayState": "Unsupported",
  "notificationSenderEmail": "apimgmt-noreply@mail.windowsazure.com",
  "outboundPublicIpAddresses": [
    "4.198.23.208"
  ],
  "platformVersion": "stv2",
  "portalUrl": "https://pocskgapim.portal.azure-api.net",
  "privateEndpointConnections": null,
  "privateIpAddresses": null,
  "provisioningState": "Succeeded",
  "publicIpAddressId": null,
  "publicIpAddresses": [
    "4.198.23.208"
  ],
  "publicNetworkAccess": "Enabled",
  "publisherEmail": "sunilgajendran.cto@gmail.com",
  "publisherName": "skg",
  "resourceGroup": "apim-poc-rg",
  "restore": null,
  "scmUrl": "https://pocskgapim.scm.azure-api.net",
  "sku": {
    "capacity": 1,
    "name": "Developer"
  },
  "systemData": {
    "createdAt": "2025-11-26T05:53:58.452042+00:00",
    "createdBy": "sunilgajendran.cto@gmail.com",
    "createdByType": "User",
    "lastModifiedAt": "2025-11-26T11:57:09.988316+00:00",
    "lastModifiedBy": "sunilgajendran.cto@gmail.com",
    "lastModifiedByType": "User"
  },
  "tags": {},
  "targetProvisioningState": "",
  "type": "Microsoft.ApiManagement/service",
  "virtualNetworkConfiguration": null,
  "virtualNetworkType": "None",
  "zones": null
}
✓ Managed identity enabled
  Principal ID: cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a

Step 3: Grant APIM Access to API
----------------------------------
⚠ Manual step required:

1. Go to Azure Portal > Entra ID > Enterprise Applications
2. Search for 'aks-hello-world-api'
3. Go to 'Users and groups' > 'Add user/group'
4. Under 'Users', click 'None Selected'
5. Search for 'pocskgapim' (the APIM managed identity)
6. Select it and click 'Select'
7. Under 'Select a role', choose 'API.Access'
8. Click 'Assign'

This grants APIM's managed identity permission to call the API

Press Enter after completing the manual steps...

Step 4: Get Backend URL
-----------------------
✓ Backend URL: http://4.237.126.197

Step 5: Create API in APIM
--------------------------
⚠ API already exists, updating...
{
  "apiRevision": "1",
  "apiRevisionDescription": null,
  "apiType": null,
  "apiVersion": null,
  "apiVersionDescription": null,
  "apiVersionSet": null,
  "apiVersionSetId": null,
  "authenticationSettings": {
    "oAuth2": null,
    "oAuth2AuthenticationSettings": [],
    "openid": null,
    "openidAuthenticationSettings": []
  },
  "contact": null,
  "description": null,
  "displayName": "Hello World API",
  "id": "/subscriptions/da68dfda-5d63-42ff-b28c-4e44e79e13b1/resourceGroups/apim-poc-rg/providers/Microsoft.ApiManagement/service/pocskgapim/apis/hello-world-api",
  "isCurrent": true,
  "isOnline": null,
  "license": null,
  "name": "hello-world-api",
  "path": "hello",
  "protocols": [
    "https"
  ],
  "resourceGroup": "apim-poc-rg",
  "serviceUrl": "http://4.237.126.197",
  "sourceApiId": null,
  "subscriptionKeyParameterNames": {
    "header": "Ocp-Apim-Subscription-Key",
    "query": "subscription-key"
  },
  "subscriptionRequired": false,
  "termsOfServiceUrl": null,
  "type": "Microsoft.ApiManagement/service/apis"
}
✓ API created/updated

Step 6: Create API Operations
------------------------------
  Health operation already exists
  Hello operation already exists
  Public hello operation already exists
✓ API operations created

Step 7: Apply Authentication Policy
------------------------------------
  Applying policy via REST API...
Not a json response, outputting to stdout. For binary data suggest use "--output-file" to write to a file
<policies>
	<inbound>
		<base />
		<!-- Acquire token from Azure Entra ID using APIM's managed identity -->
		<authentication-managed-identity resource="api://ded658c3-3903-4f40-bf82-893c1f0e824f" output-token-variable-name="msi-access-token" ignore-error="false" />
		<!-- Set the Authorization header with the acquired token -->
		<set-header name="Authorization" exists-action="override">
			<value>@("Bearer " + (string)context.Variables["msi-access-token"])</value>
		</set-header>
		<!-- Remove the subscription key from being forwarded to backend -->
		<set-header name="Ocp-Apim-Subscription-Key" exists-action="delete" />
		<!-- CORS policy -->
		<cors allow-credentials="false">
			<allowed-origins>
				<origin>*</origin>
			</allowed-origins>
			<allowed-methods>
				<method>GET</method>
				<method>POST</method>
				<method>PUT</method>
				<method>DELETE</method>
				<method>OPTIONS</method>
			</allowed-methods>
			<allowed-headers>
				<header>*</header>
			</allowed-headers>
		</cors>
		<!-- Rate limiting -->
		<rate-limit calls="100" renewal-period="60" />
		<!-- Log the request -->
		<trace source="apim-policy">
			<message>@{
                return new JObject(
                    new JProperty("method", context.Request.Method),
                    new JProperty("url", context.Request.Url.ToString()),
                    new JProperty("hasToken", context.Variables.ContainsKey("msi-access-token"))
                ).ToString();
            }</message>
		</trace>
	</inbound>
	<backend>
		<base />
	</backend>
	<outbound>
		<base />
		<!-- Remove sensitive headers from response -->
		<set-header name="X-Powered-By" exists-action="delete" />
		<set-header name="X-AspNet-Version" exists-action="delete" />
	</outbound>
	<on-error>
		<base />
		<!-- Log errors -->
		<trace source="apim-policy-error">
			<message>@{
                return new JObject(
                    new JProperty("error", context.LastError.Message),
                    new JProperty("source", context.LastError.Source),
                    new JProperty("reason", context.LastError.Reason)
                ).ToString();
            }</message>
		</trace>
		<!-- Return friendly error message -->
		<return-response>
			<set-status code="500" reason="Internal Server Error" />
			<set-header name="Content-Type" exists-action="override">
				<value>application/json</value>
			</set-header>
			<set-body>@{
                return new JObject(
                    new JProperty("error", "An error occurred processing your request"),
                    new JProperty("message", context.LastError.Message),
                    new JProperty("timestamp", DateTime.UtcNow.ToString("o"))
                ).ToString();
            }</set-body>
		</return-response>
	</on-error>
</policies>
✓ Authentication policy applied

Step 8: Get APIM Gateway URL
-----------------------------
✓ APIM Gateway URL: https://pocskgapim.azure-api.net

Step 9: Get Subscription Key
-----------------------------
✓ Subscription key retrieved

Step 10: Save Configuration
---------------------------
✓ Configuration saved

==================================================
APIM Setup Complete!
==================================================

Configuration Summary:
  APIM Name: pocskgapim
  Gateway URL: https://pocskgapim.azure-api.net
  Backend URL: http://4.237.126.197
  Managed Identity: cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a

Test URLs:
  Health: https://pocskgapim.azure-api.net/hello/health
  Public: https://pocskgapim.azure-api.net/hello/api/hello/public
  Authenticated: https://pocskgapim.azure-api.net/hello/api/hello
---

./test-api.sh 
==================================================
API Testing Script
==================================================
✓ Loaded configuration

Configuration:
  APIM Gateway: https://pocskgapim.azure-api.net
  Namespace: hello-world

==================================================
Test 1: Health Endpoint (No Auth Required)
==================================================

Request:
  GET https://pocskgapim.azure-api.net/hello/health

Response:
Healthy

✓ Test 1 PASSED (HTTP 200)

==================================================
Test 2: Public Endpoint (No Auth Required)
==================================================

Request:
  GET https://pocskgapim.azure-api.net/hello/api/hello/public

Response:
{
  "message": "Hello from AKS! (Public endpoint)",
  "authenticated": false,
  "timestamp": "2025-11-26T14:59:10.3090769Z"
}

✓ Test 2 PASSED (HTTP 200)

==================================================
Test 3: Authenticated Endpoint (Requires Token)
==================================================

Request:
  GET https://pocskgapim.azure-api.net/hello/api/hello
  (APIM will acquire token using managed identity)

Response:
{
  "message": "Hello from AKS with Workload Identity!",
  "authenticated": true,
  "timestamp": "2025-11-26T14:59:10.4748903Z",
  "user": {
    "id": "cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a",
    "name": "Unknown",
    "applicationId": "23fc5b24-5e19-4a0f-bbf0-5972ca4a1031",
    "tenantId": "Unknown"
  },
  "authorization": {
    "roles": [
      "API.Access"
    ],
    "scopes": []
  },
  "claims": [
    {
      "type": "aud",
      "value": "api://ded658c3-3903-4f40-bf82-893c1f0e824f"
    },
    {
      "type": "iss",
      "value": "https://sts.windows.net/8b00db25-a991-48c8-b92d-384c8be1fa14/"
    },
    {
      "type": "iat",
      "value": "1764168847"
    },
    {
      "type": "nbf",
      "value": "1764168847"
    },
    {
      "type": "exp",
      "value": "1764255547"
    },
    {
      "type": "aio",
      "value": "k2JgYGiK/hn/yueuxCxmf7mZQvzrAA=="
    },
    {
      "type": "appid",
      "value": "23fc5b24-5e19-4a0f-bbf0-5972ca4a1031"
    },
    {
      "type": "appidacr",
      "value": "2"
    },
    {
      "type": "http://schemas.microsoft.com/identity/claims/identityprovider",
      "value": "https://sts.windows.net/8b00db25-a991-48c8-b92d-384c8be1fa14/"
    },
    {
      "type": "http://schemas.microsoft.com/identity/claims/objectidentifier",
      "value": "cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a"
    },
    {
      "type": "rh",
      "value": "1.AUIAJdsAi5GpyEi5LThMi-H6FMNY1t4DOUBPv4KJPB8Ogk-kAABCAA."
    },
    {
      "type": "http://schemas.microsoft.com/ws/2008/06/identity/claims/role",
      "value": "API.Access"
    },
    {
      "type": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
      "value": "cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a"
    },
    {
      "type": "http://schemas.microsoft.com/identity/claims/tenantid",
      "value": "8b00db25-a991-48c8-b92d-384c8be1fa14"
    },
    {
      "type": "uti",
      "value": "fWzA__b1xUq5thcYzKhkAA"
    },
    {
      "type": "ver",
      "value": "1.0"
    },
    {
      "type": "xms_ftd",
      "value": "v2cEb7pAu2KxJ8oYcc5Rsk5ZguErouvw5X_ce5W1uB8BYXVzdHJhbGlhZWFzdC1kc21z"
    }
  ],
  "environment": {
    "machineName": "hello-world-deployment-74cb4758fd-68ckg",
    "osVersion": "Unix 5.15.0.1098",
    "dotnetVersion": "8.0.22"
  }
}

✓ Test 3 PASSED (HTTP 200)

Authentication Details:
{
  "id": "cfb8abd7-d4d9-4d8a-89a2-6a6a230d877a",
  "name": "Unknown",
  "applicationId": "23fc5b24-5e19-4a0f-bbf0-5972ca4a1031",
  "tenantId": "Unknown"
}
{
  "roles": [
    "API.Access"
  ],
  "scopes": []
}

==================================================
Test 4: Direct Service Access (Should Fail)
==================================================

Request:
  GET http://4.237.126.197/api/hello (without token)

Response:


✓ Test 4 PASSED (HTTP 401 - Unauthorized as expected)

==================================================
Test 5: Workload Identity Verification
==================================================

Checking pod: hello-world-deployment-74cb4758fd-68ckg

Service Account:
hello-world-sa

Workload Identity Labels:
true

Environment Variables:
AZURE_AUTHORITY_HOST=https://login.microsoftonline.com/
AzureAd__ClientId=ded658c3-3903-4f40-bf82-893c1f0e824f
AzureAd__Audience=api://ded658c3-3903-4f40-bf82-893c1f0e824f
AZURE_TENANT_ID=8b00db25-a991-48c8-b92d-384c8be1fa14
AzureAd__TenantId=8b00db25-a991-48c8-b92d-384c8be1fa14
AzureAd__Instance=https://login.microsoftonline.com/
AZURE_CLIENT_ID=ded658c3-3903-4f40-bf82-893c1f0e824f
AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/azure-identity-token

✓ Test 5 COMPLETED

==================================================
Test Summary
==================================================

All tests completed. Review the results above.

For detailed logs, run:
  kubectl logs -l app=hello-world -n hello-world --tail=50

To view APIM logs:
  Go to Azure Portal > APIM > APIs > Hello World API > Test
