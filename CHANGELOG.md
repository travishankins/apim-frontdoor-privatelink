# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-12-18

### Added
- Initial release of Azure Front Door + APIM with Private Link Terraform configuration
- Support for APIM Premium SKU with Private Link connectivity
- Front Door Premium with dual origins (Gateway + Developer Portal)
- WAF Policy with Microsoft managed rules (Prevention mode)
- Separate routing for API calls and Developer Portal pages
- Comprehensive documentation and deployment guide
- Cost estimates and architecture diagrams
- Troubleshooting guide with common issues

### Features
- **11 Azure Resources**: Complete infrastructure deployment
  - APIM Premium (public mode with Private Link support)
  - Front Door Premium profile, endpoint, and security policies
  - Dual origins: Gateway origin + Portal origin
  - Dual routes: API route (`/*`) + Portal route (`/signin`, `/signup`, etc.)
  - WAF with Microsoft Default Rule Set 2.1 + Bot Manager 1.0
  - Origin group with health probes
  
- **Security**:
  - Private Link connectivity (traffic over Azure backbone)
  - WAF in Prevention mode
  - DDoS protection built-in
  - Public network access configurable (enabled by default, can be disabled post-deployment)
  
- **Developer Portal Support**:
  - Dedicated portal origin with Private Link
  - Pre-configured routes for portal pages
  - Supports full portal functionality after publishing

### Technical Notes
- APIM requires `public_network_access_enabled = true` during initial creation (Azure limitation)
- Front Door route patterns must be path-based (no wildcard file extensions like `/*.css`)
- Developer Portal must be published separately via Azure Portal
- Private Endpoint connections require manual approval
- Deployment time: ~25-30 minutes (APIM takes longest)

### Known Limitations
- Cannot disable public network access during APIM creation (must enable, then disable post-deployment)
- Portal content not published by default (manual step required)
- Front Door doesn't support wildcard file extension patterns in routes
- Private Endpoint approval is manual (cannot be automated in Terraform)

### Cost Estimate
- APIM Premium: ~$2,700/month (1 unit)
- Front Door Premium: ~$350-500/month (base + moderate traffic)
- **Total**: ~$3,000-3,200/month minimum

### Requirements
- Terraform >= 1.0
- Azure CLI (for authentication and manual approval steps)
- Azure subscription with appropriate permissions
- Globally unique prefix for APIM service name

---

## Future Enhancements (Not Yet Implemented)

- [ ] Remote state backend configuration (Azure Storage)
- [ ] Custom domain support for Front Door
- [ ] Multi-region APIM deployment
- [ ] Automated Private Endpoint approval (if Azure API supports it)
- [ ] Integration with Azure Key Vault for secrets
- [ ] Application Insights integration
- [ ] Log Analytics workspace for centralized logging
- [ ] Azure DevOps / GitHub Actions CI/CD pipelines
- [ ] Sentinel policies for cost optimization
- [ ] Auto-scaling configuration
