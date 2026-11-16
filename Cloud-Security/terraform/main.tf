# =====================================================================
#  INTENTIONALLY INSECURE AZURE LAB — for ScoutSuite evaluation only.
#  Deploy in a personal/lab subscription. Run `terraform destroy` when done.
# =====================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.110" }
    azuread = { source = "hashicorp/azuread", version = "~> 2.53" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "azurerm" {
  features {
    resource_group { prevent_deletion_if_contains_resources = false }
  }
}

provider "azuread" {}

data "azurerm_subscription" "current" {}
data "azuread_domains" "tenant" { only_initial = true }

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_password" "lab" {
  length           = 16
  special          = true
  override_special = "!@#"
}

locals {
  name   = "scoutlab"
  domain = data.azuread_domains.tenant.domains[0].domain_name
  tags = {
    purpose = "scoutsuite-insecure-lab"
    owner   = "africahackon-student"
  }
}

# ---------------------------------------------------------------------
# IDENTITY — standard user granted a custom role with Actions = ["*"]
#            at SUBSCRIPTION scope (an Owner-equivalent "custom owner").
#            CIS Azure 1.x: "Ensure no custom subscription owner roles".
# ---------------------------------------------------------------------
resource "azuread_user" "lab_user" {
  user_principal_name   = "lab.operator@${local.domain}"
  display_name          = "Lab Operator"
  password              = random_password.lab.result
  force_password_change = false
}

resource "azurerm_role_definition" "custom_owner" {
  name        = "${local.name}-custom-subscription-owner"
  scope       = data.azurerm_subscription.current.id
  description = "INSECURE: wildcard permissions at subscription scope"

  permissions {
    actions     = ["*"]
    not_actions = []
  }

  assignable_scopes = [data.azurerm_subscription.current.id]
}

resource "azurerm_role_assignment" "lab_user_custom_owner" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.custom_owner.role_definition_resource_id
  principal_id       = azuread_user.lab_user.object_id
}

# ---------------------------------------------------------------------
# RESOURCE GROUP
# ---------------------------------------------------------------------
resource "azurerm_resource_group" "lab" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------
# DATA — storage account: HTTP allowed, public network access from all
#        networks, anonymous blob access, shared keys enabled, and a
#        container set to public "container" (list + read) access.
# ---------------------------------------------------------------------
resource "azurerm_storage_account" "lab" {
  name                            = "st${local.name}${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  https_traffic_only_enabled      = false # INSECURE
  allow_nested_items_to_be_public = true  # INSECURE
  shared_access_key_enabled       = true  # INSECURE (keys usable)
  public_network_access_enabled   = true  # INSECURE
  min_tls_version                 = "TLS1_2"

  network_rules {
    default_action = "Allow" # INSECURE: all networks
  }

  blob_properties {
    delete_retention_policy { days = 1 } # weak soft-delete
  }

  tags = local.tags
}

resource "azurerm_storage_container" "public" {
  name                  = "customer-exports"
  storage_account_name  = azurerm_storage_account.lab.name
  container_access_type = "container" # INSECURE: anonymous list + read
}

resource "azurerm_storage_blob" "fake_pii" {
  name                   = "customer_records_FAKE.csv"
  storage_account_name   = azurerm_storage_account.lab.name
  storage_container_name = azurerm_storage_container.public.name
  type                   = "Block"
  source                 = "${path.module}/data/customer_records_FAKE.csv"
}

# ---------------------------------------------------------------------
# NETWORK — VNet / Subnet / NSG allowing SSH + RDP from the Internet
# ---------------------------------------------------------------------
resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${local.name}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${local.name}-web"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-SSH-Any" # INSECURE
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-RDP-Any" # INSECURE
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.tags
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "vm" {
  name                = "pip-${local.name}-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-${local.name}-vm"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
  tags = local.tags
}

# ---------------------------------------------------------------------
# VIRTUAL MACHINE — public IP, password auth, managed identity that can
#                   read/write the storage account (lateral-movement path)
# ---------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "web" {
  name                            = "vm-${local.name}-web"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = var.vm_size
  admin_username                  = "azureadmin"
  admin_password                  = random_password.lab.result
  disable_password_authentication = false # INSECURE
  network_interface_ids           = [azurerm_network_interface.vm.id]

  identity { type = "SystemAssigned" }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "vm_mi_rg_contributor" {
  scope                = azurerm_resource_group.lab.id
  role_definition_name = "Contributor" # INSECURE: over-privileged MI
  principal_id         = azurerm_linux_virtual_machine.web.identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_mi_blob" {
  scope                = azurerm_storage_account.lab.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.web.identity[0].principal_id
}
