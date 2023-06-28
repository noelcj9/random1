variable "resource_group_location" {
  default     = "southeastasia"
  description = "Location of the resource group."
}

variable "DC_prefix" {
  type        = string
  default     = "winserver"
  description = "Prefix of the resource name for DC"
}

variable "winclient_prefix" {
  type        = string
  default     = "winclient"
  description = "Prefix of the resource name for winclient"
}

variable "unixclient_prefix" {
  type        = string
  default     = "unixclient"
  description = "Prefix of the resource name for unixclient"
}

variable "Domain_DNSName" {
  description = "FQDN for the Active Directory forest root domain"
  default     = "contoso.local"
  type        = string
  sensitive   = false
}

variable "netbios_name" {
  description = "NETBIOS name for the AD domain"
  default     = "CONTOSO"
  type        = string
  sensitive   = false
}

variable "unixclient_joindomain_script" {
  type    = string
  default =  "joindomain.sh"
}