
/*
 * Copyright (c) 2020 Teradici Corporation
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

variable "cac_configure_depends_on" {
  description = "Value that internal module components can use as a dependency for externally created recources"
  type        = any
  default     = null
}

variable "domain_group" {
  description = "Active Directory Distinguished Name for the User Group to log into the CAM Management Interface. Default is 'Domain Admins'. (eg, 'CN=CAM Admins,CN=Users,DC=example,DC=com')"
  default     = "Domain Admins"
}

variable "ssl_key" {
  description = "SSL private key for the Connector"
  default     = ""
}

variable "ssl_cert" {
  description = "SSL certificate for the Connector"
  default     = ""
}

variable "cac_installer_url" {
  description = "Location of the Cloud Access Connector installer"
}

variable "cam_url" {
  type    = string
  default = "https://cam.teradici.com"
}

locals {
  startup_cac_filename = "cac-startup.sh"
}
