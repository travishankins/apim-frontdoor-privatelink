output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "apim_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.apim.name
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.apim.gateway_url
}

output "apim_portal_url" {
  description = "Developer portal URL"
  value       = azurerm_api_management.apim.developer_portal_url
}

output "apim_management_url" {
  description = "Management API URL"
  value       = azurerm_api_management.apim.management_api_url
}

output "apim_public_ip" {
  description = "Public IP addresses of APIM (before Private Endpoint restriction)"
  value       = azurerm_api_management.apim.public_ip_addresses
}

output "front_door_endpoint_hostname" {
  description = "Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.endpoint.host_name
}

output "front_door_endpoint_url" {
  description = "Front Door endpoint URL"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}"
}

output "front_door_portal_note" {
  description = "Note about Developer Portal access"
  value       = <<-EOT
    The APIM Developer Portal is accessible through the same Front Door endpoint.
    
    Access the Developer Portal by navigating to your Front Door endpoint.
    The Private Link connection (Gateway target type) provides secure access to both
    the API Gateway and the Developer Portal.
    
    Developer Portal URL (via Front Door): ${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}
    Direct Portal URL: ${azurerm_api_management.apim.developer_portal_url}
  EOT
}

output "private_endpoint_approval_required" {
  description = "Instructions for approving the private endpoint connection"
  value       = <<-EOT
    
    ⚠️  MANUAL STEP REQUIRED:
    
    After deployment completes, you must approve the Private Endpoint connection:
    
    1. Go to Azure Portal → API Management → ${azurerm_api_management.apim.name}
    2. Navigate to: Settings → Network → Inbound private endpoint connections
    3. Find the pending connection from Front Door
    4. Click "Approve"
    
    Or use Azure CLI:
    
    az network private-endpoint-connection approve \\
      --resource-group ${azurerm_resource_group.main.name} \\
      --name <connection-name> \\
      --resource-name ${azurerm_api_management.apim.name} \\
      --type Microsoft.ApiManagement/service \\
      --description "Approved via CLI"
    
    Once approved, test the connection:
    curl https://${azurerm_cdn_frontdoor_endpoint.endpoint.host_name}
    
    After testing, optionally disable public access to APIM:
    az apim update \\
      --name ${azurerm_api_management.apim.name} \\
      --resource-group ${azurerm_resource_group.main.name} \\
      --public-network-access Disabled
  EOT
}