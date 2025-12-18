terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# API Management Instance (Premium v2 SKU)
# NOTE: For Front Door Private Link, APIM must be in public mode (not VNet-injected)
# The Private Endpoint provides the security layer
# Premium v2 offers: SLA, faster deployment, availability zones, workspaces, up to 30 units scaling
resource "azurerm_api_management" "apim" {
  name                = "${var.prefix}-apim"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = "Premium_${var.apim_capacity}" # Premium v2 tier

  # Public mode - NOT VNet injected (Private Endpoint provides security)
  virtual_network_type = "None"

  # NOTE: Must be enabled during creation, can be disabled after deployment via update
  # Azure doesn't allow disabling public access during initial APIM creation
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  # Optional: Enable availability zones for high availability (Premium v2 only)
  zones = var.enable_availability_zones ? ["1", "2", "3"] : null

  tags = var.tags

  # Premium v2 deploys much faster than v1 (typically 5-15 minutes vs 30-45 minutes)
  timeouts {
    create = "45m"
    update = "45m"
    delete = "30m"
  }
}

# Azure Front Door Premium Profile
resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "${var.prefix}-afd"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor" # Premium required for Private Link
  tags                = var.tags

  depends_on = [azurerm_api_management.apim]
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "endpoint" {
  name                     = "${var.prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  tags                     = var.tags
}

# Front Door Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "apim_origin_group" {
  name                     = "${var.prefix}-apim-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    interval_in_seconds = 60
    path                = "/status-0123456789abcdef"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

# Front Door Origin (APIM with Private Link)
# Front Door Origin - APIM (Gateway and Developer Portal)
# Note: APIM Private Link only supports "Gateway" target type, but this provides
# access to both the Gateway and Developer Portal through the same Private Link connection
resource "azurerm_cdn_frontdoor_origin" "apim_origin" {
  name                           = "${var.prefix}-apim-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.apim_origin_group.id
  enabled                        = true
  certificate_name_check_enabled = true

  # Use the APIM gateway hostname (without https://)
  host_name          = trimsuffix(trimprefix(azurerm_api_management.apim.gateway_url, "https://"), "/")
  origin_host_header = trimsuffix(trimprefix(azurerm_api_management.apim.gateway_url, "https://"), "/")
  priority           = 1
  weight             = 1000

  private_link {
    request_message        = "Please approve this private endpoint connection from Front Door"
    location               = "centralus" # Using Central US as West Central US is not supported for Private Link
    private_link_target_id = azurerm_api_management.apim.id
    target_type            = "Gateway" # For APIM, only "Gateway" is supported; covers both Gateway and Portal
  }
}

# Front Door Origin - APIM Developer Portal
resource "azurerm_cdn_frontdoor_origin" "apim_portal_origin" {
  name                           = "${var.prefix}-portal-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.apim_origin_group.id
  enabled                        = true
  certificate_name_check_enabled = true

  # Use the APIM developer portal hostname
  host_name          = trimsuffix(trimprefix(azurerm_api_management.apim.developer_portal_url, "https://"), "/")
  origin_host_header = trimsuffix(trimprefix(azurerm_api_management.apim.developer_portal_url, "https://"), "/")
  priority           = 1
  weight             = 1000

  private_link {
    request_message        = "Please approve this private endpoint connection from Front Door (Portal)"
    location               = "centralus"
    private_link_target_id = azurerm_api_management.apim.id
    target_type            = "Gateway" # Same Private Link serves both Gateway and Portal
  }
}

# Front Door Route - API Gateway Traffic
resource "azurerm_cdn_frontdoor_route" "route" {
  name                          = "${var.prefix}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.apim_origin.id]

  enabled                = true
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true
}

# Front Door Route - Developer Portal Traffic
resource "azurerm_cdn_frontdoor_route" "portal_route" {
  name                          = "${var.prefix}-portal-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.apim_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.apim_portal_origin.id]

  enabled                = true
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/signin", "/signin/*", "/signup", "/signup/*", "/confirm", "/confirm/*", "/captcha", "/captcha/*", "/delegations", "/delegations/*", "/profile", "/profile/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain = true

  depends_on = [azurerm_cdn_frontdoor_route.route]
}

# Optional: WAF Policy for Front Door
resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                              = "${replace(var.prefix, "-", "")}wafpolicy"
  resource_group_name               = azurerm_resource_group.main.name
  sku_name                          = azurerm_cdn_frontdoor_profile.afd.sku_name
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = "https://www.example.com"
  custom_block_response_status_code = 403
  custom_block_response_body        = base64encode("Access Denied")

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  tags = var.tags
}

# Associate WAF Policy with Front Door Endpoint
resource "azurerm_cdn_frontdoor_security_policy" "security_policy" {
  name                     = "${var.prefix}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.endpoint.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}