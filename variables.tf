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
  type      = map(any)
  sensitive = true
}
variable "configs" {
  type = map(any)
  default = {
    Combined_NFIv7_SMA = {
      config_path = "/freqtrade/user_data/config-dev-Combined_NFIv7_SMA.json"
      cpu         = 1024
      memory      = 800
    }
    NFIv7HyperOpt = {
      config_path = "/freqtrade/user_data/config-prod-NFIv7HyperOpt.json"
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
