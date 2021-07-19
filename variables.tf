variable "region" {
  default = "ap-northeast-1"
}

variable "grafana_username" {
  type      = string
  sensitive = true
}

variable "grafana_password" {
  type      = string
  sensitive = true
}

variable "ft_creds" {
  type = object({
    ProtectedZeus = object({
      ft_username = string
      ft_password = string
    })
    Combined_NFIv7_SMA = object({
      ft_username = string
      ft_password = string
    })
    NFI7HO2 = object({
      ft_username = string
      ft_password = string
    })
  })
  sensitive = true
}
variable "configs" {
  type = object({
    ProtectedZeus = object({
      config_path = string
      cpu         = number
      memory      = number
    })
    Combined_NFIv7_SMA = object({
      config_path = string
      cpu         = number
      memory      = number
    })
    NFI7HO2 = object({
      config_path = string
      cpu         = number
      memory      = number
    })
  })

  default = {
    Combined_NFIv7_SMA = {
      config_path = "/freqtrade/user_data/config-dev-Combined_NFIv7_SMA.json"
      cpu         = 1024
      memory      = 800
    }
    NFI7HO2 = {
      config_path = "/freqtrade/user_data/config-dev-NFI7HO2.json"
      cpu         = 1024
      memory      = 800
    }
    ProtectedZeus = {
      config_path = "/freqtrade/user_data/config-prod.json"
      cpu         = 1024
      memory      = 800
    }
  }
  description = "Strategies to run"
}
