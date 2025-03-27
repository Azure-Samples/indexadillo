param location string = resourceGroup().location
param tags object = {}
param sourceStorageAccountName string
param FunctionPlanName string
param functionAppName string
param identityId string
param identityClientId string
param principalID string
param functionContainerName string
param documentIntelligenceName string
param openAIName string
param searchServiceEndpoint string
param diEndpoint string
param openAIEndpoint string
param searchServiceName string
param appInsightsName string
param dtsURL string
param dtsName string
param taskHubName string

resource sourceStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: sourceStorageAccountName
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: documentIntelligenceName
}

resource openAI 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' existing = {
  name: openAIName
}

resource searchService 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchServiceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource dts 'Microsoft.DurableTask/schedulers@2024-10-01-preview' existing = {
  name: dtsName
}


resource flexFunctionPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: FunctionPlanName
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    reserved: true
  }
}

resource flexFunctionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'indexadillo-func' })
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { 
      '${identityId}': {}
    }
  }
  properties: {
    serverFarmId: flexFunctionPlan.id
    httpsOnly: true
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${sourceStorageAccount.properties.primaryEndpoints.blob}${functionContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: identityId
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
    }
  }

  resource webConfig 'config' = {
    name: 'web'
    properties: {
      publicNetworkAccess: 'Enabled'
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      AzureWebJobsStorage__accountName: sourceStorageAccount.name
      AzureWebJobsStorage__clientId: identityClientId
      AzureWebJobsStorage__credential : 'managedidentity'
      AzureWebJobsFeatureFlags: 'EnableWorkerIndexing'
      AZURE_CLIENT_ID: identityClientId
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
      SOURCE_STORAGE_ACCOUNT_NAME: sourceStorageAccount.name
      DI_ENDPOINT: diEndpoint
      AZURE_OPENAI_ENDPOINT: openAIEndpoint
      SEARCH_SERVICE_ENDPOINT: searchServiceEndpoint
      DTS_CONNECTION_STRING: 'Endpoint=${dtsURL};Authentication=ManagedIdentity;ClientID=${identityClientId}'
      TASKHUB_NAME: taskHubName
    }
  }
}

// Storage Blob Data Owner
resource sourceStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sourceStorageAccount.id, principalID, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
  scope: sourceStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor
resource sourceStorageDataRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sourceStorageAccount.id, principalID, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  scope: sourceStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Storage Queue Data Contributor
resource sourceStorageQueueRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sourceStorageAccount.id, principalID, '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
  scope: sourceStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '974c5e8b-45b9-4653-ba55-5f855dd0fb88')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Storage Table Data Contributor
resource sourceStorageTableRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(sourceStorageAccount.id, principalID, '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
  scope: sourceStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services Contributor for Document Intelligence
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(documentIntelligence.id, principalID, '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
  scope: documentIntelligence
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Cognitive Services User for Document Intelligence
resource cognitiveServicesUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(documentIntelligence.id, principalID, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: documentIntelligence
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}


// Cognitive Services OpenAI User
resource cognitiveServicesOAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(openAI.id, principalID, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: openAI
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Search Service Contributor
resource searchServiceContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(searchService.id, principalID, '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
  scope: searchService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

// Search Index Data Contributor
resource searchIndexDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(searchService.id, principalID, '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
  scope: searchService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7')
    principalId: principalID
    principalType: 'ServicePrincipal'
  }
}

resource dtsRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(dts.id, principalID, '0ad04412-c4d5-4796-b79c-f76d14c8d402' )
  scope: dts
  properties: {
   roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '0ad04412-c4d5-4796-b79c-f76d14c8d402' )
   principalId: principalID
   principalType: 'ServicePrincipal'
  }
}




