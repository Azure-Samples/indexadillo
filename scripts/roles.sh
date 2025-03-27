#!/bin/bash
output=$(azd env get-values)

while IFS= read -r line; do
  name=$(echo "$line" | cut -d '=' -f 1)
  value=$(echo "$line" | cut -d '=' -f 2 | sed 's/^\"//;s/\"$//')
  export "$name"="$value"
done <<< "$output"


NO_PROMPT=false
for arg in "$@"; do
    if [[ "$arg" == "--no-prompt" ]]; then
        NO_PROMPT=true
        break
    fi
done

echo "Environment variables set."

# Use AZURE_PRINCIPAL_ID or AZURE_CLIENT_ID if available,
# otherwise get the signed in user's principal ID.
if [ -n "$AZURE_PRINCIPAL_ID" ]; then
  PRINCIPAL_ID=$(az ad user show --id "$AZURE_PRINCIPAL_ID" --query id -o tsv)
elif [ -n "$AZURE_CLIENT_ID" ]; then
  PRINCIPAL_ID=$(az ad sp show --id "$AZURE_CLIENT_ID" --query id -o tsv)
else
  PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)
fi

# Try to retrieve the display name assuming it's a user.
AZURE_DISPLAY_NAME=$(az ad user show --id "$PRINCIPAL_ID" --query userPrincipalName -o tsv 2>/dev/null)
# If that fails, try retrieving the service principal's display name.
if [ -z "$AZURE_DISPLAY_NAME" ]; then
  AZURE_DISPLAY_NAME=$(az ad sp show --id "$PRINCIPAL_ID" --query appDisplayName -o tsv 2>/dev/null)
fi

# Get the subscription name and set the subscription.
AZURE_SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

if [[ -z "$AZURE_DISPLAY_NAME" ]]; then
    echo "Error: AZURE_DISPLAY_NAME is not set. Could not retrieve az information." >&2
    exit 1
fi

echo "AZURE_PRINCIPAL_ID: $PRINCIPAL_ID ($AZURE_DISPLAY_NAME)"
echo "AZURE_ENV_NAME: $AZURE_ENV_NAME"
echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID ($AZURE_SUBSCRIPTION_NAME)"



roles=(
    "8ebe5a00-799e-43f5-93ac-243d3dce84a7" # Search Index Data Contributor
    "7ca78c08-252a-4471-8644-bb5ff32d4ba0" # Search Service Contributor
    "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd" # Cognitive Services User
    "25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68" # Cognitive Services Contributor
    "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # Storage Blob Data Contributor
    "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" # Storage Blob Data Owner
    "a97b65f3-24c7-4388-baec-2e87135dc908" # Cognitive Services User
    "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3" # Storage Table Data Contributor
    "974c5e8b-45b9-4653-ba55-5f855dd0fb88" # Storage Queue Data Contributor
    "0ad04412-c4d5-4796-b79c-f76d14c8d402" # Durable Task Scheduler Dashboard User
)

if [ -z "$AZURE_RESOURCE_GROUP" ]; then
    export AZURE_RESOURCE_GROUP="rg-$AZURE_ENV_NAME"
    azd env set AZURE_RESOURCE_GROUP "$AZURE_RESOURCE_GROUP"
fi

echo "AZURE_RESOURCE_GROUP: $AZURE_RESOURCE_GROUP"

if ! $NO_PROMPT; then
    read -p "Do you want to continue? (y/n): " choice
    [[ "$choice" =~ ^[Yy]$ ]] || exit 1
fi

for role in "${roles[@]}"; do
    if [ -z "$AZURE_CLIENT_ID" ]; then
        az role assignment create \
            --role "$role" \
            --assignee-object-id $PRINCIPAL_ID \
            --scope /subscriptions/"$AZURE_SUBSCRIPTION_ID"/resourceGroups/"$AZURE_RESOURCE_GROUP" \
            --assignee-principal-type User
    else
        az role assignment create \
            --role "$role" \
            --assignee-object-id $PRINCIPAL_ID \
            --scope /subscriptions/"$AZURE_SUBSCRIPTION_ID"/resourceGroups/"$AZURE_RESOURCE_GROUP" \
            --assignee-principal-type ServicePrincipal
    fi
done
