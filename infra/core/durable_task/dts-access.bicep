param principalID string
param roleDefinitionID string
param dtsName string
param principalType string

resource dts 'Microsoft.DurableTask/schedulers@2025-04-01-preview' existing = {
  name: dtsName
}

resource dtsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dts.id, principalID, roleDefinitionID)
  scope: dts
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: principalID
    principalType: principalType
  }
}
