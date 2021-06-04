  resource "azurerm_resource_group" "aks_resource_group" {
    name     = "${var.environment_name}-aks-${var.company_tag}"
    location = "${var.location}"
  }

  locals {
    name_prefix = "${var.company_tag}"
  }

# # Create virtual network (VNet)
  resource "azurerm_virtual_network" "main" {
    name                = "${local.name_prefix}-network"
    location            = azurerm_resource_group.aks_resource_group.location
    resource_group_name = azurerm_resource_group.aks_resource_group.name
    address_space       = ["10.240.0.0/16"]
  }

# # # Create AKS subnet to be used by nodes and pods
  resource "azurerm_subnet" "aks" {
    name                 = "${var.aks_subnet_aks_name}"
    resource_group_name  = azurerm_resource_group.aks_resource_group.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefix       = "${var.aks_subnet_aks_address_prefix}"
  }

# # # Create Virtual Node (ACI) subnet
# # Creates MC_{env}-aks-nxl_{dev}-core-aks-nxl_eastus
  resource "azurerm_subnet" "aci" {
    name                 = "${var.aks_subnet_aci_name}"
    resource_group_name  = azurerm_resource_group.aks_resource_group.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefix       = "${var.aks_subnet_aci_address_prefix}"
#   # Designate subnet to be used by ACI
    delegation {
      name = "${var.aks_subnet_delegation_name}"

      service_delegation {
        name    = "Microsoft.ContainerInstance/containerGroups"
        actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      }
    }
  }

  resource "azurerm_kubernetes_cluster" "core_kubernetes_cluster" {
    name                        = "${var.environment_name}-core-aks-${var.company_tag}"
    location                    = azurerm_resource_group.aks_resource_group.location
    resource_group_name         = azurerm_resource_group.aks_resource_group.name
    dns_prefix                  = "${var.environment_name}-${var.company_tag}"
    kubernetes_version          = "${var.aks_azurerm_kubernetes_cluster_core_kubernetes_cluster_kubernetes_version}"
    # api_server_authorized_ip_ranges = ["0.0.0.0/0"]

    default_node_pool {
     name                   = "${var.aks_kubernetes_cluster_default_node_pool_name}"
     enable_auto_scaling    = "${var.aks_kubernetes_cluster_default_node_pool_enable_auto_scaling}"
     #node_count             = "${var.aks_kubernetes_cluster_default_node_pool_node_count}"
     min_count              = "${var.aks_kubernetes_cluster_default_node_pool_min_count}"
     max_count              = "${var.aks_kubernetes_cluster_default_node_pool_max_count}"
     max_pods               = "${var.aks_kubernetes_cluster_default_node_pool_max_pods}"
     vm_size                = "${var.aks_kubernetes_cluster_default_node_pool_vm_size}"
     type                   = "${var.aks_kubernetes_cluster_default_node_pool_type}"
     vnet_subnet_id         = azurerm_subnet.aks.id
     orchestrator_version   = "${var.aks_azurerm_kubernetes_cluster_core_kubernetes_cluste_default_node_pool_orchestrator_version}"
    }

    service_principal {
     client_id     = "${var.ARM_CLIENT_ID}"
     client_secret = "${var.ARM_CLIENT_SECRET}"
    }

    addon_profile {
      # Enable virtual node (ACI connector) for Linux
      aci_connector_linux {
        enabled     = true
        subnet_name = azurerm_subnet.aci.name
      }
      kube_dashboard {
        enabled = true
      }
    
      oms_agent {
        enabled = true
        log_analytics_workspace_id = "${var.aks_kubernetes_cluster_addon_profile_log_analytics_workspace_id}"
      }
      azure_policy {
        enabled = "${var.aks_kubernetes_cluster_addon_profile_azure_policy_enabled}"
      }
    }
    
    network_profile {
      network_plugin    = "${var.aks_network_profile_network_plugin}"
      outbound_type     = "${var.aks_network_profile_outbound_type}"
      load_balancer_sku = "${var.aks_network_profile_load_balancer_sku}"

      load_balancer_profile {
        managed_outbound_ip_count   = "${var.aks_network_profile_load_balancer_profile_managed_outbound_ip_count}"
      }
    }

    role_based_access_control {
      enabled = "${var.aks_role_based_access_control_enabled}"
    }

    tags = {
      Name        = "${var.aks_kubernetes_cluster_tags}"
      Environment = "${var.environment_name}"
    }
  }

  resource "azurerm_kubernetes_cluster_node_pool" "user_node_pool1" {
    name                  = "${var.aks_kubernetes_cluster_user_node_pool1_name}"
    kubernetes_cluster_id = azurerm_kubernetes_cluster.core_kubernetes_cluster.id
    enable_auto_scaling    = true
    min_count              = "${var.aks_kubernetes_cluster_user_node_pool1_min_count}"
    max_count              = "${var.aks_kubernetes_cluster_user_node_pool1_max_count}"
    max_pods               = "${var.aks_kubernetes_cluster_user_node_pool1_max_pods}"
    vm_size                = "${var.aks_kubernetes_cluster_user_node_pool1_vm_size}"
    vnet_subnet_id         = "${azurerm_subnet.aks.id}"
    node_taints            = ["application=userpool1:NoSchedule"]
    orchestrator_version   = "${var.aks_azurerm_kubernetes_cluster_core_kubernetes_cluste_user_node_pool1_orchestrator_version}"

    tags = {
      Environment = "${var.environment_name}"
    }
  }

  resource "azurerm_kubernetes_cluster_node_pool" "composite_node_pool1" {
    name                  = "${var.aks_kubernetes_cluster_composite_node_pool1_name}"
    kubernetes_cluster_id = azurerm_kubernetes_cluster.core_kubernetes_cluster.id
    enable_auto_scaling    = true
    min_count              = "${var.aks_kubernetes_cluster_composite_node_pool1_min_count}"
    max_count              = "${var.aks_kubernetes_cluster_composite_node_pool1_max_count}"
    max_pods               = "${var.aks_kubernetes_cluster_composite_node_pool1_max_pods}"
    vm_size                = "${var.aks_kubernetes_cluster_composite_node_pool1_vm_size}"
    vnet_subnet_id         = "${azurerm_subnet.aks.id}"
    node_taints            = ["composite=compositepool1:NoSchedule"]
    orchestrator_version   = "${var.aks_azurerm_kubernetes_cluster_core_kubernetes_cluste_composite_node_pool1_orchestrator_version}"

    tags = {
      Environment = "${var.environment_name}"
    }
  }

# add permissions
# kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard

   output "host" {
   value = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.host
 }

 output "client_key" {
   value = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.client_key
 }

 output "client_certificate" {
   value = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.client_certificate
 }

output "kube_config" {
  value = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config_raw
}

 output "cluster_ca_certificate" {
   value = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.cluster_ca_certificate
 }

  provider "kubernetes" {
    version = "=1.13.3"
    load_config_file = "false"

    host = azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.host
  
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.core_kubernetes_cluster.kube_config.0.cluster_ca_certificate)}"
  }

## Persistent Volume using Azure Managed Disk, Claim and Storage Class
      resource "kubernetes_persistent_volume_claim" "core_persistent_volume_claim" {
       metadata {
         name = "${var.environment_name}-akspvclaim-${var.company_tag}"
       }
       spec {
         access_modes = ["${var.aks_kubernetes_persistent_volume_claim_core_persistent_volume_claim_access_modes}"]
         storage_class_name = "${var.environment_name}-akssc-${var.company_tag}"
         resources {
           requests = {
             storage = "${var.aks_kubernetes_persistent_volume_claim_core_persistent_volume_claim_storage}"
           }
         }
         volume_name = "${kubernetes_persistent_volume.core_persistent_volume.metadata.0.name}"
       }
     }
 
     resource "kubernetes_persistent_volume" "core_persistent_volume" {
       metadata {
         name = "${var.environment_name}-akspv-${var.company_tag}"
       }
       spec {
         capacity = {
           storage = "${var.aks_kubernetes_persistent_volume_claim_core_persistent_volume_claim_storage}"
         }
         access_modes = ["${var.aks_kubernetes_persistent_volume_claim_core_persistent_volume_claim_access_modes}"]
         storage_class_name = "${var.environment_name}-akssc-${var.company_tag}"
         persistent_volume_source {
           azure_disk {
             caching_mode  = "${var.aks_kubernetes_persistent_volume_core_persistent_volume_azure_disk_caching_mode}"
             data_disk_uri = "${var.aks_kubernetes_persistent_volume_core_persistent_volume_azure_disk_data_disk_uri}"
             disk_name     = "${var.environment_name}-aksdisk-${var.company_tag}"
             kind          = "${var.aks_kubernetes_persistent_volume_core_persistent_volume_kind}"
           }
         }
       }
     }

   resource "kubernetes_storage_class" "core_storage_class" {
     metadata {
       name = "${var.environment_name}-akssc-${var.company_tag}"
     }
     storage_provisioner    = "${var.aks_kubernetes_storage_class_core_storage_class_storage_provisioner}"
     reclaim_policy         = "${var.aks_kubernetes_storage_class_core_storage_class_reclaim_policy}"
     allow_volume_expansion = "${var.aks_kubernetes_storage_class_core_storage_class_allow_volume_expansion}"
     parameters = {
       storageaccounttype   = "${var.aks_kubernetes_storage_class_core_storage_class_storageaccounttype}"
       kind = "${var.aks_kubernetes_persistent_volume_core_persistent_volume_kind}"
     }
     mount_options = ["file_mode=0700", "dir_mode=0777", "mfsymlinks", "uid=1000", "gid=1000", "nobrl", "cache=none"]
   }

 resource "azurerm_managed_disk" "core_aks_managed_disk" {
   name                 = "${var.environment_name}-aksmanageddisk-${var.company_tag}"
   location             = "${var.location}"
   resource_group_name  = "${var.environment_name}-aks-${var.company_tag}"
   storage_account_type = "${var.aks_kubernetes_storage_class_core_storage_class_storageaccounttype}"
   create_option        = "${var.aks_azurerm_managed_disk_core_aks_managed_disk_create_option}"
   disk_size_gb         = "${var.aks_azurerm_managed_disk_core_aks_managed_disk_disk_size_gb}"
   tags = {
     environment = "${var.environment_name}"
   }
 }