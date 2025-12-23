# Azure Front Door + API Management with Private Link

This Terraform configuration deploys a secure, production-ready architecture with Azure Front Door Premium connecting to API Management via Private Link.

## 🏗️ Architecture

```
Internet → Azure Front Door Premium (Public, Global CDN + WAF)
            ↓ Private Link (Azure Backbone)
          API Management Premium (Public Mode, Public Access Disabled)
            ↓
          Backend APIs
```

**Key Design**: APIM is deployed in **public mode** with **public network access disabled**. Front Door connects via Private Link over Azure's private backbone network, providing enterprise-grade security without VNet complexity.

## ✨ Features

- **Azure API Management Premium** with production SLA
- **Azure Front Door Premium** with Private Link integration
- **Private connectivity** - Traffic flows over Azure backbone, not public internet
- **Public access blocked** - Direct APIM access returns 403 Forbidden
- **Web Application Firewall (WAF)** with Microsoft managed rules (Prevention mode)
- **DDoS protection** built into Front Door
- **Managed Identity** on APIM for Azure integrations
- **Fast deployment** - Premium deploys in 5-15 minutes (vs 30-45 for v1)

## 📋 Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI (for manual approval step)

## 🚀 Quick Start

### 1. Configure Variables

Edit `variables.tf` or create a `terraform.tfvars` file:

```hcl
resource_group_name        = "rg-apim-afd-demo"
location                   = "eastus"
prefix                     = "mycompany"
apim_publisher_name        = "Your Company Name"
apim_publisher_email       = "admin@example.com"
apim_capacity              = 1 # Scale 1-30+ units as needed
enable_availability_zones  = false # Set to true for zone redundancy
```

> **Note**: Replace `prefix`, `apim_publisher_name`, and `apim_publisher_email` with your values. The prefix must be globally unique as it's used in the APIM service name.

### 2. Set Azure Subscription

```bash
# Set your Azure subscription ID as environment variable
export ARM_SUBSCRIPTION_ID="your-subscription-id-here"

# Or set it for the current session
az account show --query id -o tsv | xargs -I {} export ARM_SUBSCRIPTION_ID={}
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (Premium takes ~20-30 minutes for initial deployment)
terraform apply
```

### 4. Approve Private Endpoint Connection ⚠️

**IMPORTANT MANUAL STEP**: After deployment, you must approve the private endpoint connection:

#### Option A: Azure Portal
1. Go to **Azure Portal** → **API Management** → Your APIM instance
2. Navigate to **Settings** → **Network** → **Inbound private endpoint connections**
3. Find the **pending** connection from Front Door
4. Click **Approve**

#### Option B: Azure CLI
```bash
# List pending connections
az network private-endpoint-connection list \
  --name <your-apim-name> \
  --resource-group <your-rg-name> \
  --type Microsoft.ApiManagement/service \
  --query '[].{name: name, status: properties.privateLinkServiceConnectionState.status}' -o table

# Approve the connection using the connection name
az network private-endpoint-connection approve \
  --name <connection-name> \
  --resource-name <your-apim-name> \
  --resource-group <your-rg-name> \
  --type Microsoft.ApiManagement/service \
  --description "Approved Front Door private link"
```

**Wait 5-10 minutes** after approval for the connection to fully establish and Front Door to deploy.

### 5. Test the Deployment

```bash
# Get the Front Door endpoint URL
terraform output front_door_endpoint_url

# Test developer portal access (should return 200 OK)
curl -I https://<your-frontdoor-endpoint>.azurefd.net/signin

# Test root path (should return 200 OK)
curl -I https://<your-frontdoor-endpoint>.azurefd.net/
```

### 6. Verify Developer Portal Access

**The Developer Portal is accessible through Front Door** using Host header routing:

```bash
# Test developer portal paths (should all return 200 OK)
curl -I https://<your-frontdoor-endpoint>.azurefd.net/signin
curl -I https://<your-frontdoor-endpoint>.azurefd.net/signup
curl -I https://<your-frontdoor-endpoint>.azurefd.net/profile
```

**How It Works:**
- Front Door connects to APIM via Private Link using the **Gateway hostname** (`<name>.azure-api.net`)
- The portal origin sends the **Developer Portal hostname** (`<name>.developer.azure-api.net`) in the HTTP Host header
- APIM routes the request to the Developer Portal based on the Host header
- This allows a single Private Link connection to serve both Gateway and Portal traffic

**Portal Routes Configured:**
- Root: `/`
- Authentication: `/signin`, `/signin/*`, `/signup`, `/signup/*`
- User functions: `/profile`, `/profile/*`, `/confirm`, `/confirm/*`
- Portal features: `/captcha`, `/delegations`
- Static assets: `/styles/*`, `/scripts/*`, `/assets/*`, `/dist/*`, `/images/*`, `/fonts/*`, `/content/*`

**Key Architecture Points:**
- Private Link target type: **Gateway** (only supported type for APIM)
- Gateway origin: Uses gateway hostname for both connection and Host header
- Portal origin: Uses gateway hostname for connection, developer hostname for Host header
- This is the **correct and only** way to access the Developer Portal through Private Link

> **Note**: If you need to publish or customize the portal, you can temporarily enable public access, make changes, then disable it again.

## 📦 Resources Created

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all resources |
| API Management | Premium SKU in public mode (public access enabled initially, can be disabled post-deployment) |
| Front Door Profile | Premium tier with Private Link support |
| Front Door Endpoint | Public entry point (global CDN) |
| Front Door Origin Group | Health probes and load balancing configuration |
| Front Door Origin (Gateway) | APIM connection with Private Link; uses gateway hostname for both connection and Host header |
| Front Door Origin (Portal) | APIM connection with Private Link; uses gateway hostname for connection, developer portal hostname for Host header (enables portal routing) |
| Front Door Route (API) | Traffic routing for API calls (pattern: `/*`) |
| Front Door Route (Portal) | Traffic routing for portal pages (patterns: `/signin`, `/signup`, `/profile`, etc.) |
| WAF Policy | Web Application Firewall with Microsoft managed rules |
| Front Door Security Policy | Associates WAF policy with endpoint |

**Total**: 11 resources deployed

## 🔐 Security Features

### Network Isolation
- **Public network access disabled** on APIM (returns 403 to direct access)
- Front Door connects to APIM via **Private Endpoint**
- Traffic flows over **Azure's private backbone network** (not public internet)
- Private Link provides enterprise-grade isolation without VNet complexity

### Web Application Firewall (WAF)
- **Microsoft Default Rule Set 2.1** (OWASP protection)
- **Bot Manager Rule Set 1.0** (bot protection)
- **Prevention mode** (blocks malicious requests)
- Custom rules support for additional security

### DDoS Protection
- Front Door provides platform-level DDoS protection
- No additional cost for basic protection

## 💰 Cost Considerations

### APIM Premium SKU (as configured)
- **Base cost**: ~$2,700/month (1 capacity unit)
- **Production SLA**: 99.99% uptime guarantee
- **Features**: 
  - Private Link support ✅
  - Multi-region deployment
  - Availability zones support
  - Scale up to 30+ units
  - VNet injection capability
  - Self-hosted gateway
- **Deployment time**: 15-30 minutes (initial), 5-10 minutes (updates)

### Scaling
- **Additional units**: ~$2,700/month per unit
- **Scale range**: 1-30+ units
- **With availability zones**: Cost multiplied per zone

### Why Premium Required
- ✅ **Private Link support** (required for this architecture)
- ✅ **Production SLA**
- ❌ Developer SKU: No Private Link, no SLA, dev/test only (~$50/month)
- ❌ Standard SKU: No Private Link support

### Front Door Premium
- **Base**: ~$35/month
- **Data transfer**: ~$0.12-0.25/GB (varies by region)
- **Requests**: ~$0.0135 per 10,000 requests
- **Private Link**: Included (required for APIM Private Link)
- **Estimate**: $350-500/month for moderate traffic

### Total Estimated Monthly Cost
- **Minimum**: ~$3,000-3,200/month (APIM Premium_1 + Front Door Premium)
- **With traffic**: Add data transfer and request costs
- **Multi-region**: Costs multiply per region
- **Availability zones**: Costs multiply per zone (3x for 3 zones)
## 🔧 Configuration Options

### Enable Availability Zones (Recommended for Production)

In `terraform.tfvars`:
```hcl
enable_availability_zones = true
```

This deploys APIM across 3 availability zones for maximum reliability.

### Scale APIM Capacity

In `terraform.tfvars`:
```hcl
apim_capacity = 5  # Scale from 1-30 units
```

### Important: Premium Required for Private Link

**Note**: This architecture requires **Premium SKU** for Private Link support. Developer and Standard tiers do not support Private Link connections from Front Door.

If you need to use a different tier:
- ❌ **Developer**: No Private Link support
- ❌ **Standard**: No Private Link support  
- ✅ **Premium**: Required for this architecture

### Add Custom Domain to Front Door

### Add Custom Domain to Front Door

```hcl
resource "azurerm_cdn_frontdoor_custom_domain" "custom" {
  name                     = "api-custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  dns_zone_id             = azurerm_dns_zone.custom.id
  host_name               = "api.yourdomain.com"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}
```

### Enable Multi-Region APIM (Premium only)

```hcl
resource "azurerm_api_management" "apim" {
  # ... existing config ...
  
  additional_location {
    location = "westus2"
    capacity = 1
  }
}
```

## 🧪 Testing Your Deployment

### 1. Verify Private Endpoint Connection

```bash
# Check APIM network configuration
az apim show -n <your-apim-name> -g <your-rg-name> \
  --query '{publicAccess:publicNetworkAccess, privateEndpoint:privateEndpointConnections[0].provisioningState}'
```

Expected output:
```json
{
  "privateEndpoint": "Succeeded",
  "publicAccess": "Disabled"
}
```

### 2. Test Direct Access is Blocked

```bash
# This should return 403 Forbidden
curl -I https://<your-apim-name>.azure-api.net
```

### 3. Test Front Door Access Works

```bash
# Get your Front Door endpoint
terraform output front_door_endpoint_url

# Test connection (will return 404 if no APIs configured, but confirms connectivity)
curl -I https://<your-frontdoor-endpoint>.azurefd.net
```

### 4. Add and Test an API

After adding APIs to APIM:
```bash
# Test with subscription key
curl -H "Ocp-Apim-Subscription-Key: your-key" \
  https://<your-frontdoor-endpoint>.azurefd.net/your-api-path
```

## 📊 Monitoring

### View APIM Metrics
```bash
az monitor metrics list \
  --resource <apim-resource-id> \
  --metric Requests,Capacity \
  --start-time 2025-01-01T00:00:00Z
```

### View Front Door Logs
1. Enable diagnostics on Front Door
2. Send to Log Analytics workspace
3. Query with KQL in Azure Monitor

## 🔄 Updating the Infrastructure

```bash
# Make changes to .tf files
terraform plan
terraform apply
```

### Issue: APIM deployment takes longer than expected
**Solution**: Premium typically deploys in 15-30 minutes initially. If it takes longer:
- Check Azure status page for regional issues
- Verify quota limits in your subscription
- With availability zones enabled, deployment takes longer (30-45 minutes)
- Subsequent updates are faster (5-10 minutes)
## 🗑️ Cleanup

```bash
# Destroy all resources (will take 20-30 minutes)
terraform destroy
```

## 🔧 Troubleshooting

### Issue: APIM creation fails with "NotSupported: Blocking all public network access"
**Solution**: This is expected behavior:
- Azure **requires** `public_network_access_enabled = true` during initial APIM creation
- The Terraform code is configured correctly with public access enabled
- After deployment, you can disable public access manually via Azure Portal or CLI:
  ```bash
  az apim update \
    --name <apim-name> \
    --resource-group <rg-name> \
    --public-network-access Disabled
  ```

### Issue: Front Door route creation fails with "Invalid patterns found"
**Solution**: Front Door routes don't support wildcard file extensions like `/*.css` or `/*.js`
- Use path-based patterns only: `/signin`, `/signin/*`, `/profile`, etc.
- The portal route is configured with valid portal-specific paths
- Static assets are served through the gateway origin

### Issue: Private Endpoint Connection Stuck Pending
**Solution**: Manually approve in Azure Portal:
1. Go to APIM → Network → Inbound private endpoint connections
2. Click on the pending connection
3. Click "Approve"

### Issue: Front Door returns 403 after approval
**Solution**: 
1. Wait 5-10 minutes for private endpoint provisioning to complete
2. Check APIM public network access status: `az apim show -n <name> -g <rg> --query publicNetworkAccess`
3. Verify WAF policy is not blocking legitimate requests
4. Check Front Door origin health status
4. Check Front Door origin health status

### Issue: Direct APIM access still works
**Solution**: 
- Verify `public_network_access_enabled = false` in main.tf
- Run `terraform apply` to update the configuration
- Wait 5-10 minutes for the change to propagate

### Issue: Developer Portal returns 404 through Front Door
**Solution**: Verify the portal origin configuration:
1. Check that portal origin has correct Host header: `<apim-name>.developer.azure-api.net`
2. Verify private endpoint connection is approved and provisioned (wait 5-10 minutes after approval)
3. Wait for Front Door deployment to complete (check Azure Portal for deployment status)
4. Test direct portal access works: `curl -I https://<apim-name>.developer.azure-api.net/signin`
5. If direct access returns 404, the portal may need publishing (Azure Portal → APIM → Developer portal → Publish)

**Key**: The portal origin must use gateway hostname for `host_name` but developer portal hostname for `origin_host_header`

### Issue: Direct APIM access still works (not blocked)

## 📚 Additional Resources

- [Azure Front Door Private Link with APIM](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-enable-private-link-apim)
- [APIM Network Configuration](https://learn.microsoft.com/en-us/azure/api-management/virtual-network-concepts)
- [Front Door Security Best Practices](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview#security)
- [Terraform AzureRM Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [APIM Premium SKU Features](https://learn.microsoft.com/en-us/azure/api-management/api-management-features)

## 🔑 Key Architectural Decisions

### Why Public Mode with Disabled Public Access?
- **Private Link Requirement**: Front Door Private Link only supports APIM in public mode
- **Security**: Disabling public network access blocks all direct internet traffic (returns 403)
- **Simplicity**: Simpler than VNet injection, no NSG management
- **Performance**: Direct Azure backbone connectivity, no additional hops

### Why Not Internal VNet Mode?
- **Incompatible**: Cannot use Front Door Private Link with VNet-injected APIM
- **Complexity**: Requires Application Gateway, complex networking, additional costs
- **Latency**: Additional hop through Application Gateway adds latency

## 📝 License

MIT

## 🤝 Contributing

Feel free to submit issues and enhancement requests!
