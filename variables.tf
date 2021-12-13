variable "subnetlist" {
  type = object({
    iaas = object({
      name     = string
      rt       = string
      prefixes = list(string)
      nsg      = string
    })
    paas = object({
      name     = string
      rt       = string
      prefixes = list(string)
      nsg      = string
    })
    azfw = object({
      name     = string
      rt       = string
      prefixes = list(string)
      nsg      = string
    })
  })

  default = {
    iaas = {
      name     = "iaas-subnet"
      rt       = "iaas-rt"
      prefixes = ["10.1.0.0/24"]
      nsg      = ""
    }
    paas = {
      name     = "paas-subnet"
      rt       = ""
      prefixes = ["10.1.2.0/24"]
      nsg      = "paas-nsg"
    }
    azfw = {
      name     = "AzureFirewallSubnet"
      rt       = ""
      prefixes = ["10.1.1.0/24"]
      nsg      = ""
    }
  }
}

variable "username" {
  description = "value"
}

variable "password" {
  description = "value"
}