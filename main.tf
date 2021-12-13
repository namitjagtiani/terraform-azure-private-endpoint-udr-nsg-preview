#---------------------------------------
# Resource Group
#---------------------------------------

# Create a resource group.
# Ensure that this is created in one of the supported regions for the public preview of the 
# feature or you won't be able to use the feature.
resource "azurerm_resource_group" "pe-rg" {
  name     = "pendpoint-rg"
  location = "eastus"
}

#---------------------------------------
# Virtual Networks and Subnets
#---------------------------------------

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet" {
  name                = "pendpoint-vnet"
  resource_group_name = azurerm_resource_group.pe-rg.name
  location            = azurerm_resource_group.pe-rg.location
  address_space       = ["10.1.0.0/16"]
}

# Create required subnets for Firewall, Iaas and PaaS
resource "azurerm_subnet" "subnets" {
  for_each                                      = var.subnetlist
  name                                          = each.value.name
  resource_group_name                           = azurerm_resource_group.pe-rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = each.value.prefixes
  enforce_private_link_service_network_policies = false # This is required to use the UDR and NSG functionality
}

#---------------------------------------
# Route Tables
#---------------------------------------

# Create Route Tables
resource "azurerm_route_table" "route-table" {
  name                          = "iaas-rt"
  location                      = azurerm_resource_group.pe-rg.location
  resource_group_name           = azurerm_resource_group.pe-rg.name
  disable_bgp_route_propagation = true

  # route {
  #   name                   = "pendpoint-specific-route"
  #   address_prefix         = "10.1.2.4/32"
  #   next_hop_type          = "VirtualAppliance"
  #   next_hop_in_ip_address = "10.1.1.4"
  # }
  #   route {
  #   name                   = "pendpoint-subnet-route"
  #   address_prefix         = "10.1.2.0/24"
  #   next_hop_type          = "VirtualAppliance"
  #   next_hop_in_ip_address = "10.1.1.4"
  # }
}

# Associate created Route Tables with Subnets
resource "azurerm_subnet_route_table_association" "rt-association" {
  subnet_id      = azurerm_subnet.subnets["iaas"].id
  route_table_id = azurerm_route_table.route-table.id
}

#---------------------------------------
# Network Security Groups
#---------------------------------------

# Create Network Security Group for PaaS subnet
resource "azurerm_network_security_group" "paas-nsg" {
  name                = var.subnetlist["paas"].nsg
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name

  # security_rule {
  #   name                       = "pendpoint-allow-traffic"
  #   priority                   = 100
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "443"
  #   source_address_prefix      = "10.1.0.0/24"
  #   destination_address_prefix = "10.1.2.4/32"
  # }
  # security_rule {
  #   name                       = "pendpoint-deny-traffic"
  #   priority                   = 200
  #   direction                  = "Inbound"
  #   access                     = "Deny"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "443"
  #   source_address_prefix      = "10.1.0.0/24"
  #   destination_address_prefix = "10.1.2.4/32"
  # }
  # security_rule {
  #   name                       = "pendpoint-allow-fw-traffic"
  #   priority                   = 300
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "443"
  #   source_address_prefix      = "10.1.1.0/24"
  #   destination_address_prefix = "10.1.2.4/32"
  # }
  #   security_rule {
  #   name                       = "pendpoint-deny-fw-traffic"
  #   priority                   = 400
  #   direction                  = "Inbound"
  #   access                     = "Deny"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "443"
  #   source_address_prefix      = "10.1.1.0/24"
  #   destination_address_prefix = "10.1.2.4/32"
  # }
}

# Associate Network Security Groups with subnets
resource "azurerm_subnet_network_security_group_association" "paas-nsga" {
  subnet_id                 = azurerm_subnet.subnets["paas"].id
  network_security_group_id = azurerm_network_security_group.paas-nsg.id
}

#---------------------------------------
# Azure Bastion
#---------------------------------------

# Create Azure Bastion subnet
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.pe-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.3.0/27"]
}

# Create Azure Bastion Public IP
resource "azurerm_public_ip" "bastion-pip" {
  name                = "bastion-pip"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Azure Bastion Host
resource "azurerm_bastion_host" "bastion-host" {
  name                = "bastion-host"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.bastion-pip.id
  }
}

#---------------------------------------
# Test Virtual Machine
#---------------------------------------

# Create Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["iaas"].id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Test Virtual Machine
resource "azurerm_windows_virtual_machine" "test-vm" {
  name                  = "test-vm"
  resource_group_name   = azurerm_resource_group.pe-rg.name
  location              = azurerm_resource_group.pe-rg.location
  size                  = "Standard_F2"
  admin_username        = var.username
  admin_password        = var.password
  license_type          = "Windows_Server"
  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

#---------------------------------------
# Azure Firewall and Public IP
#---------------------------------------

# Create Azure Firewall Public IP
resource "azurerm_public_ip" "azfw-pip" {
  name                = "azfw-pip"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Azure Firewall
resource "azurerm_firewall" "azfw" {
  name                = "azfw"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name

  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.subnets["azfw"].id
    public_ip_address_id = azurerm_public_ip.azfw-pip.id
  }
}

# Create Azure Firewall Rule Collection
resource "azurerm_firewall_application_rule_collection" "pendpoint-app-rc" {
  name                = "pendpoint-app-rc"
  azure_firewall_name = azurerm_firewall.azfw.name
  resource_group_name = azurerm_resource_group.pe-rg.name
  priority            = 1000
  action              = "Allow"

  rule {
    name = "allow-vm-to-pendpoint"

    source_addresses = [
      "10.1.0.0/24",
    ]

    target_fqdns = [
      "pendpoint-webapp.azurewebsites.net",
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}

#---------------------------------------
# App Services
#---------------------------------------

# Create App Service Plan
# Ensure you select a PremiumV2 plan to be able to use Private Endpoints
resource "azurerm_app_service_plan" "asp" {
  name                         = "pendpoint-asp"
  location                     = azurerm_resource_group.pe-rg.location
  resource_group_name          = azurerm_resource_group.pe-rg.name
  maximum_elastic_worker_count = 1
  kind                         = "Windows"

  sku {
    tier     = "PremiumV2"
    size     = "P1v2"
    capacity = 1
  }
}

# Create App Service
resource "azurerm_app_service" "webapp" {
  name                = "pendpoint-webapp"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  source_control {
    repo_url           = "https://github.com/Azure-Samples/html-docs-hello-world"
    branch             = "master"
    manual_integration = true
    use_mercurial      = false
  }
}

#---------------------------------------
# Private DNS Zone
#---------------------------------------

# Create Private DNS Zone
resource "azurerm_private_dns_zone" "pdns" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.pe-rg.name
}

# Create VNET link to Private DNS Zone
resource "azurerm_private_dns_zone_virtual_network_link" "pdns-vnet-link" {
  name                  = "pezone"
  resource_group_name   = azurerm_resource_group.pe-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.pdns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Create A records for Private Endpoint
resource "azurerm_private_dns_a_record" "arecord1" {
  name                = "pendpoint-webapp"
  zone_name           = azurerm_private_dns_zone.pdns.name
  resource_group_name = azurerm_resource_group.pe-rg.name
  ttl                 = 10
  records             = ["10.1.2.4"]
}

resource "azurerm_private_dns_a_record" "arecord2" {
  name                = "pendpoint-webapp.scm"
  zone_name           = azurerm_private_dns_zone.pdns.name
  resource_group_name = azurerm_resource_group.pe-rg.name
  ttl                 = 10
  records             = ["10.1.2.4"]
}

#---------------------------------------
# Private Endpoint
#---------------------------------------

# Create Private Endpoint for the App Service
resource "azurerm_private_endpoint" "pendpoint" {
  depends_on          = [azurerm_app_service.webapp]
  name                = "web-pendpoint"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name
  subnet_id           = azurerm_subnet.subnets["paas"].id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdns.id]
  }

  private_service_connection {
    name                           = "web-privateserviceconnection"
    private_connection_resource_id = azurerm_app_service.webapp.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }
}

#---------------------------------------
# Log Analytics Workspace
#---------------------------------------

resource "azurerm_log_analytics_workspace" "la-wks" {
  name                = "pendpoint-wks"
  location            = azurerm_resource_group.pe-rg.location
  resource_group_name = azurerm_resource_group.pe-rg.name
  sku                 = "Free"
  retention_in_days   = 7
}

resource "azurerm_monitor_diagnostic_setting" "azfw-diag" {
  name                       = "azfwdiag"
  target_resource_id         = azurerm_firewall.azfw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la-wks.id
  depends_on = [
    azurerm_firewall_application_rule_collection.pendpoint-app-rc
  ]

  log {
    category = "AzureFirewallNetworkRule"
    enabled  = true
  }

  log {
    category = "AzureFirewallApplicationRule"
    enabled  = true
  }

  metric {
    category = "AllMetrics"
  }
}
