terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  backend "azurerm" {}   # values are passed at 'terraform init' (see pipeline)
}

provider "azurerm" {
  features {}
  # subscription and credentials come from ARM_* environment variables
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-cfdemo-${var.env}"
  location = var.location
  tags     = { env = var.env, owner = "demo" }
}

resource "random_string" "suffix" {   # web app names must be globally unique
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-cfdemo-${var.env}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = var.sku
}

resource "azurerm_linux_web_app" "app" {
  name                = "cfdemo-${var.env}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  identity {
    type = "SystemAssigned"   # managed identity (used for Key Vault in Block 3)
  }

  site_config {
    always_on           = false   # must be false on the free F1 tier
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"
    app_command_line    = "gunicorn --bind=0.0.0.0 --timeout 600 app:app"
    application_stack {
      python_version = "3.12"
    }
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"   # installs requirements.txt on deploy
    APP_ENV                        = var.env
  }
}
