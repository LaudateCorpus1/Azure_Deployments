/*
 * Copyright (c) 2021 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

module "workstation-map" {
  source       = "../../modules/workstation-map"
  workstations = var.workstations
}

module "dc-cac-network" {
  source = "../../modules/network/dc-cac-one-ip"

  resource_group_name     = azurerm_resource_group.main.name
  locations               = var.cac_location_list
  vnet_peer_to_peer_links = module.workstation-map.virtual-network-peer-to-peer-links

  prefix                        = var.prefix
  application_id                = var.application_id
  aad_client_secret             = var.aad_client_secret
  active_directory_netbios_name = var.active_directory_netbios_name
  create_debug_rdp_access       = var.create_debug_rdp_access
}

module "active-directory-domain-vm" {
  source = "../../modules/dc/dc-vm"

  dc_vm_depends_on = [module.dc-cac-network.all-output]

  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  active_directory_domain_name = "${var.active_directory_netbios_name}.dns.internal"
  ad_admin_username            = var.ad_admin_username
  ad_admin_password            = var.ad_admin_password
  ad_pass_secret_name          = var.ad_pass_secret_name
  key_vault_id                 = var.key_vault_id
  nic_id                       = module.dc-cac-network.dc-network-interface-id
  prefix                       = var.prefix
  application_id               = var.application_id
  aad_client_secret            = var.aad_client_secret
}

module "active-directory-domain-service" {
  source = "../../modules/dc/dc-service"

  dc_vm_setup_depends_on = [
    module.dc-cac-network.all-output,
    module.active-directory-domain-vm.domain-controller-name,
    module.active-directory-domain-vm.domain-controller-id
  ]

  domain_controller_virtual_machine_name      = module.active-directory-domain-vm.domain-controller-name
  domain_controller_virtual_machine_id        = module.active-directory-domain-vm.domain-controller-id
  domain_controller_virtual_machine_public_ip = module.dc-cac-network.dc-public-ip
  active_directory_domain_users_list_file     = var.ad_domain_users_list_file
  active_directory_domain_name                = "${var.active_directory_netbios_name}.dns.internal"
  ad_admin_username                           = var.ad_admin_username
  ad_admin_password                           = var.ad_admin_password
  ad_pass_secret_name                         = var.ad_pass_secret_name
  key_vault_id                                = var.key_vault_id
  application_id                              = var.application_id
  aad_client_secret                           = var.aad_client_secret
  tenant_id                                   = var.tenant_id
  safe_mode_admin_password                    = var.safe_mode_admin_password
}

module "active-directory-domain-configure" {
  source = "../../modules/dc/dc-configure"

  dc_configure_depends_on = [
    module.dc-cac-network.all-output,
    module.active-directory-domain-service.uploaded-scripts,
    module.active-directory-domain-service.uploaded-domain-users-list-count
  ]

  application_id                         = var.application_id
  aad_client_secret                      = var.aad_client_secret
  resource_group_name                    = azurerm_resource_group.main.name
  domain_controller_virtual_machine_name = module.active-directory-domain-vm.domain-controller-name
}

module "cas-mgr" {
  source = "../../modules/cas-mgr-private"

  blob_depends_on = [azurerm_storage_account.storage, azurerm_storage_container.blob]
  cas_mgr_subnet_depends_on = [module.dc-cac-network.all-output]

  cas_mgr_deployment_sa_file = local.cas_mgr_deployment_sa_file
  cas_mgr_admin_password     = var.cas_mgr_admin_password
  private_container_url      = azurerm_storage_container.private-container.id

  storage_account_name         = azurerm_storage_account.storage.name
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  azurerm_virtual_network_name = module.dc-cac-network.virtual-network-name
  network_security_group_ids   = module.dc-cac-network.network-security-group-ids

  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  tenant_id                   = var.tenant_id
  key_vault_id                = var.key_vault_id
  ad_pass_secret_name         = var.ad_pass_secret_name
  pcoip_registration_code     = var.pcoip_registration_code

  storage_connection_string = azurerm_storage_account.storage.primary_connection_string
  private_container_name    = azurerm_storage_container.private-container.name
}

module "cac" {
  source = "../../modules/cac-cas-mgr"

  blob_depends_on = [azurerm_storage_account.storage, azurerm_storage_container.blob]
  cac_subnet_depends_on = [module.cas-mgr.subnet]
  cac_count_list = var.cac_count_list

  cas_mgr_url                = "https://${module.cas-mgr.internal-ip}"
  cas_mgr_insecure           = true
  cas_mgr_deployment_sa_file = local.cas_mgr_deployment_sa_file

  network_security_group_ids    = module.dc-cac-network.network-security-group-ids
  azurerm_virtual_network_names = module.dc-cac-network.virtual-network-names

  prefix                = var.prefix
  domain_name           = "${var.active_directory_netbios_name}.dns.internal"
  domain_controller_ip  = module.dc-cac-network.dc-private-ip
  storage_account_name  = azurerm_storage_account.storage.name
  private_container_url = azurerm_storage_container.private-container.id

  cac_admin_user     = var.cac_admin_username
  cac_admin_password = var.ad_admin_password

  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  locations                   = var.cac_location_list
  application_id              = var.application_id
  aad_client_secret           = var.aad_client_secret
  ad_service_account_username = var.ad_admin_username
  ad_service_account_password = var.ad_admin_password
  tenant_id                   = var.tenant_id
  key_vault_id                = var.key_vault_id
  ad_pass_secret_name         = var.ad_pass_secret_name
  ssl_key                     = var.ssl_key
  ssl_cert                    = var.ssl_cert

  storage_connection_string = azurerm_storage_account.storage.primary_connection_string
  private_container_name    = azurerm_storage_container.private-container.name

  cas_mgr_internal_ip       = module.cas-mgr.internal-ip
  cas_mgr_public_ip         = module.cas-mgr.public-ip
  cas_mgr_public_ip_id       = module.cas-mgr.public-ip-id
  cas_mgr_cidr              = module.cas-mgr.cidr

  ws_subnet_cidr            = module.dc-cac-network.subnet-workstation-cidr
  is_private = true
}

module "load-balancer" {
  source = "../../modules/network/cas-mgr-load-balancer-private"

  load_balancer_depends_on = [module.cac.cac-fw-name, module.cac.cac-fw-frontend]

  count = length(var.cac_location_list)

  instance_count            = var.cac_count_list[count.index]
  prefix                    = var.prefix
  resource_group_name       = azurerm_resource_group.main.name
  location                  = var.cac_location_list[count.index]
  cac_network_interface_ids = module.cac.network-interface-nic-ids[count.index]
  cac_subnet_ids            = module.cac.subnet-ids[count.index]
  cac_fw_name               = module.cac.cac-fw-name[count.index]
  cac_fw_frontend           = module.cac.cac-fw-frontend[count.index]
}

module "route-table" {
  source               = "../../modules/network/route-table"
  resource_group_name  = azurerm_resource_group.main.name
  cac_subnet_ids       = module.cac.subnet-ids
  ws_subnet_ids        = module.dc-cac-network.subnet-workstation-ids
  fw_public_ip         = module.cac.cac-fw-frontend[0]
  fw_private_ip        = module.cac.cac-fw-internal[0]
  locations                   = module.workstation-map.virtual-network-locations
}

module "windows-std-vm" {
  source = "../../modules/windows-std-vm"

  windows_host_vm_depends_on = [module.dc-cac-network.subnet-dc-id, module.cac.cac-fw-name]
  blob_depends_on = [azurerm_storage_account.storage, azurerm_storage_container.blob]

  workstations                 = module.workstation-map.windows-std-workstations
  resource_group_name          = azurerm_resource_group.main.name
  admin_name                   = var.windows_admin_username
  admin_password               = var.ad_admin_password
  pcoip_registration_code      = var.pcoip_registration_code
  domain_name                  = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username  = var.ad_admin_username
  ad_service_account_password  = var.ad_admin_password
  application_id               = var.application_id
  tenant_id                    = var.tenant_id
  aad_client_secret            = var.aad_client_secret
  key_vault_id                 = var.key_vault_id
  ad_pass_secret_name          = var.ad_pass_secret_name
  storage_account_name         = azurerm_storage_account.storage.name
  workstation_subnet_ids       = module.dc-cac-network.subnet-workstation-ids
  workstation_subnet_locations = module.dc-cac-network.subnet-workstation-locations

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval
}

module "windows-gfx-vm" {
  source = "../../modules/windows-gfx-vm"

  windows_host_vm_depends_on = [module.dc-cac-network.subnet-dc-id]
  blob_depends_on = [azurerm_storage_account.storage, azurerm_storage_container.blob]

  workstations                 = module.workstation-map.windows-gfx-workstations
  resource_group_name          = azurerm_resource_group.main.name
  admin_name                   = var.windows_admin_username
  admin_password               = var.ad_admin_password
  pcoip_registration_code      = var.pcoip_registration_code
  domain_name                  = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username  = var.ad_admin_username
  ad_service_account_password  = var.ad_admin_password
  application_id               = var.application_id
  tenant_id                    = var.tenant_id
  aad_client_secret            = var.aad_client_secret
  key_vault_id                 = var.key_vault_id
  ad_pass_secret_name          = var.ad_pass_secret_name
  storage_account_name         = azurerm_storage_account.storage.name
  workstation_subnet_ids       = module.dc-cac-network.subnet-workstation-ids
  workstation_subnet_locations = module.dc-cac-network.subnet-workstation-locations

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval
}

module "centos-std-vm" {
  source = "../../modules/centos-std-vm"

  centos_std_depends_on = [module.dc-cac-network.subnet-dc-id]

  workstations                 = module.workstation-map.centos-std-workstations
  resource_group_name          = azurerm_resource_group.main.name
  admin_name                   = var.centos_admin_username
  admin_password               = var.ad_admin_password
  pcoip_registration_code      = var.pcoip_registration_code
  domain_name                  = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username  = var.ad_admin_username
  ad_service_account_password  = var.ad_admin_password
  application_id               = var.application_id
  tenant_id                    = var.tenant_id
  aad_client_secret            = var.aad_client_secret
  key_vault_id                 = var.key_vault_id
  ad_pass_secret_name          = var.ad_pass_secret_name
  domain_controller_ip         = module.dc-cac-network.dc-private-ip
  workstation_subnet_ids       = module.dc-cac-network.subnet-workstation-ids
  workstation_subnet_locations = module.dc-cac-network.subnet-workstation-locations

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval
}

module "centos-gfx-vm" {
  source = "../../modules/centos-gfx-vm"

  centos_gfx_depends_on = [module.dc-cac-network.subnet-dc-id]

  workstations                 = module.workstation-map.centos-gfx-workstations
  resource_group_name          = azurerm_resource_group.main.name
  admin_name                   = var.centos_admin_username
  admin_password               = var.ad_admin_password
  pcoip_registration_code      = var.pcoip_registration_code
  domain_name                  = "${var.active_directory_netbios_name}.dns.internal"
  ad_service_account_username  = var.ad_admin_username
  ad_service_account_password  = var.ad_admin_password
  application_id               = var.application_id
  tenant_id                    = var.tenant_id
  aad_client_secret            = var.aad_client_secret
  key_vault_id                 = var.key_vault_id
  ad_pass_secret_name          = var.ad_pass_secret_name
  domain_controller_ip         = module.dc-cac-network.dc-private-ip
  workstation_subnet_ids       = module.dc-cac-network.subnet-workstation-ids
  workstation_subnet_locations = module.dc-cac-network.subnet-workstation-locations

  enable_workstation_idle_shutdown = var.enable_workstation_idle_shutdown
  minutes_idle_before_shutdown     = var.minutes_idle_before_shutdown
  minutes_cpu_polling_interval     = var.minutes_cpu_polling_interval
}
