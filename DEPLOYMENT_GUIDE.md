# Azure APIM + Front Door Deployment Guide

## 📋 Pre-Deployment Checklist

### Before You Begin
- [ ] Azure subscription with appropriate permissions
- [ ] Terraform >= 1.0 installed
- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Chosen a globally unique prefix for your APIM service name

### Required Information
You'll need to provide:
1. **Company prefix** (globally unique, e.g., "contoso", "fabrikam")
2. **Publisher name** (your company/organization name)
3. **Publisher email** (valid email for API management notifications)
4. **Azure region** (e.g., "eastus", "westus2")

## 🚀 Quick Start Guide

### Step 1: Clone/Download Repository
```bash
git clone <your-repo-url>
cd apim-deploy
```

### Step 2: Configure Your Deployment

Copy the example configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
resource_group_name        = "rg-apim-afd-prod"      # Your resource group name
location                   = "eastus"                 # Your preferred region
prefix                     = "yourcompany"            # MUST be globally unique!
apim_publisher_name        = "Your Company Name"     # Your organization name
apim_publisher_email       = "admin@yourcompany.com" # Your admin email
apim_capacity              = 1                        # Start with 1 unit
enable_availability_zones  = false                    # Set true for zone redundancy
```

### Step 3: Authenticate to Azure
```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "Your-Subscription-Name"

# Set subscription ID as environment variable (required for Terraform)
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Verify
az account show
echo $ARM_SUBSCRIPTION_ID
```

### Step 4: Initialize Terraform
```bash
terraform init
```

### Step 5: Review Deployment Plan
```bash
terraform plan
```

**Review carefully:**
- Resource names (check the prefix is applied correctly)
- Location/region
- SKU (Premium_1)
- Tags

### Step 6: Deploy Infrastructure
```bash
# Deploy (will take 15-30 minutes for APIM Premium)
terraform apply

# Type 'yes' when prompted
```

**Expected timeline:**
- Resource Group: ~30 seconds
- APIM Premium: 20-25 minutes
- Front Door Profile: ~45 seconds  
- Front Door Origins (2): ~3-4 minutes each
- Front Door Routes (2): ~40 seconds each
- Front Door Endpoint & WAF: ~1-2 minutes
- **Total: ~25-30 minutes**

### Step 7: Approve Private Endpoint ⚠️

**CRITICAL**: After deployment, you must manually approve the private endpoint connection.

#### Option A: Azure Portal
1. Navigate to **Azure Portal** → **API Management**
2. Select your APIM instance (e.g., `yourcompany-apim`)
3. Go to **Settings** → **Network** → **Inbound private endpoint connections**
4. Find the **pending** connection from Front Door
5. Click the connection, then click **Approve**

#### Option B: Azure CLI
```bash
# List connections to find the ID
az network private-endpoint-connection list \
  --name yourcompany-apim \
  --resource-group rg-apim-afd-prod \
  --type Microsoft.ApiManagement/service

# Approve using the connection ID from above
az network private-endpoint-connection approve \
  --id <connection-id> \
  --description "Approved via CLI"
```

**Wait 5-10 minutes** after approval for the connection to fully establish.

### Step 8: Verify Deployment

#### Check APIM Configuration
```bash
# Verify public access is disabled
az apim show -n yourcompany-apim -g rg-apim-afd-prod \
  --query '{publicAccess:publicNetworkAccess, privateEndpoint:privateEndpointConnections[0].provisioningState}'
```

Expected output:
```json
{
  "privateEndpoint": "Succeeded",
  "publicAccess": "Disabled"
}
```

#### Test Direct Access is Blocked
```bash
# Should return 403 Forbidden
curl -I https://yourcompany-apim.azure-api.net
```

#### Test Front Door Connectivity
```bash
# Get your Front Door URL
terraform output front_door_endpoint_url

# Test developer portal access (should return 200 OK)
curl -I https://yourcompany-endpoint-xxxxxxxx.b01.azurefd.net/signin

# Test root path (should return 200 OK)
curl -I https://yourcompany-endpoint-xxxxxxxx.b01.azurefd.net/

# Test signup page (should return 200 OK)
curl -I https://yourcompany-endpoint-xxxxxxxx.b01.azurefd.net/signup
```

**Success indicators:**
- HTTP/2 200 OK response
- `x-azure-ref` header present
- `x-cache` header present
- `content-type: text/html` for portal pages
- Portal pages load successfully in browser

### Step 9: View Deployment Outputs
```bash
terraform output
```

**Key outputs:**
- `front_door_endpoint_url` - Your public API endpoint
- `apim_gateway_url` - Direct APIM URL (blocked)
- `apim_portal_url` - Developer portal URL (blocked)

## 🔧 Post-Deployment Configuration

### Add Your First API

1. Navigate to Azure Portal → API Management
2. Go to **APIs** section
3. Click **+ Add API**
4. Choose your API type (OpenAPI, SOAP, etc.)
5. Configure and create

### Test Your API Through Front Door
```bash
# Replace with your endpoint and API path
curl -H "Ocp-Apim-Subscription-Key: your-subscription-key" \
  https://yourcompany-endpoint-xxxxxxxx.b01.azurefd.net/your-api-path
```

### Access Developer Portal (Optional)

If you need to configure the developer portal:

1. **Temporarily enable public access**:
   ```bash
   # Edit main.tf, set: public_network_access_enabled = true
   terraform apply
   ```

2. **Access and configure portal**:
   ```
   https://yourcompany-apim.developer.azure-api.net
   ```

3. **Re-disable public access**:
   ```bash
   # Edit main.tf, set: public_network_access_enabled = false
   terraform apply
   ```

## 📊 Monitoring and Management

### View Resource Status
```bash
az resource list -g rg-apim-afd-prod \
  --query "[].{Name:name, Type:type, State:provisioningState}" -o table
```

### Check APIM Health
```bash
az apim show -n yourcompany-apim -g rg-apim-afd-prod \
  --query '{status:provisioningState, gatewayUrl:gatewayUrl}'
```

### View Front Door Metrics
1. Azure Portal → Front Door → Metrics
2. Key metrics to monitor:
   - Request count
   - Latency
   - Error rate
   - WAF blocked requests

## 💰 Cost Management

### Current Configuration Cost
- **APIM Premium (1 unit)**: ~$2,700/month
- **Front Door Premium**: ~$350-500/month (base + traffic)
- **Total**: ~$3,000-3,200/month

### Cost Optimization Tips
1. Right-size APIM capacity based on actual load
2. Enable availability zones only if needed (costs 3x)
3. Monitor data transfer costs
4. Use Azure Cost Management for tracking

### Scaling
To scale APIM capacity:
```hcl
# In terraform.tfvars
apim_capacity = 2  # Doubles the cost
```

## 🔐 Security Best Practices

### Implemented Security Features
- ✅ Public network access disabled on APIM
- ✅ Private Link between Front Door and APIM
- ✅ WAF with Microsoft managed rules (Prevention mode)
- ✅ DDoS protection (built into Front Door)
- ✅ HTTPS-only enforcement
- ✅ TLS 1.2+ required

### Additional Security Recommendations
1. **Enable APIM subscription keys** for all APIs
2. **Configure OAuth/OpenID Connect** for API authentication
3. **Set up rate limiting policies** in APIM
4. **Enable diagnostic logs** for APIM and Front Door
5. **Review WAF logs** regularly for threats
6. **Rotate APIM keys** periodically

## 🔄 Making Changes

### Update Configuration
```bash
# Make changes to .tf files or terraform.tfvars
terraform plan
terraform apply
```

### Enable Availability Zones
```hcl
# In terraform.tfvars
enable_availability_zones = true
```

**Note**: Enables zone redundancy but triples APIM cost.

### Scale APIM Capacity
```hcl
# In terraform.tfvars
apim_capacity = 3  # Scale to 3 units
```

## 🗑️ Cleanup

### Destroy All Resources
```bash
# WARNING: This will delete everything!
terraform destroy
```

**Destruction takes 20-30 minutes** (APIM deletion is slow)

### Cost During Cleanup
You'll be charged until resources are fully deleted. APIM deletion can take 30+ minutes.

## 🆘 Troubleshooting

### Common Issues and Solutions

#### Issue: "Name already exists"
**Problem**: APIM service name must be globally unique  
**Solution**: Change `prefix` in terraform.tfvars to something unique

#### Issue: Private endpoint stuck "Pending"
**Problem**: Forgot to approve the private endpoint connection  
**Solution**: Follow Step 7 above to approve

#### Issue: Front Door returns 403
**Problem**: Private endpoint not approved or not yet propagated  
**Solution**: 
1. Verify private endpoint is approved (see Step 7)
2. Wait 5-10 minutes for propagation
3. Check WAF isn't blocking requests

#### Issue: Direct APIM access still works
**Problem**: Public access not disabled  
**Solution**: Verify `public_network_access_enabled = false` in main.tf and re-apply

#### Issue: Developer portal returns 404 through Front Door
**Problem**: Portal origin Host header not configured correctly  
**Solution**: 
1. Verify portal origin `origin_host_header` is set to `<apim-name>.developer.azure-api.net`
2. Verify portal origin `host_name` is set to `<apim-name>.azure-api.net` (gateway)
3. Wait 5-10 minutes after private endpoint approval for provisioning
4. Check Front Door deployment status in Azure Portal
5. Portal should be accessible at: `https://<frontdoor-endpoint>.azurefd.net/signin`

#### Issue: Terraform authentication fails
**Problem**: Not logged into Azure or wrong subscription  
**Solution**: Run `az login` and `az account set --subscription <name>`

## 📞 Support Resources

- [Azure Front Door Documentation](https://learn.microsoft.com/en-us/azure/frontdoor/)
- [APIM Documentation](https://learn.microsoft.com/en-us/azure/api-management/)
- [Private Link with APIM](https://learn.microsoft.com/en-us/azure/frontdoor/standard-premium/how-to-enable-private-link-apim)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## ✅ Deployment Checklist

- [ ] Configured terraform.tfvars with your values
- [ ] Authenticated to Azure (`az login`)
- [ ] Set correct subscription
- [ ] Ran `terraform init`
- [ ] Reviewed `terraform plan` output
- [ ] Ran `terraform apply` successfully
- [ ] Approved private endpoint connection (Step 7)
- [ ] Verified public access is blocked
- [ ] Verified Front Door connectivity works
- [ ] Added at least one API to APIM
- [ ] Tested API through Front Door
- [ ] Configured monitoring/alerts
- [ ] Documented API keys securely

---

**Deployment Date**: _________________  
**Deployed By**: _________________  
**Environment**: Production / Staging / Development  
**Subscription ID**: _________________
