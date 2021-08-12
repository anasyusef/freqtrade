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
      config_path     = "/freqtrade/user_data/config-dev-Combined_NFIv7_SMA.json"
      cpu             = 2048
      memory          = 900
      ft_port         = 8080
      ft_metric_port  = 8090
      create_instance = true
    }

    # NostalgiaForInfinityV5MultiOffsetAndHO = {
    #   config_path     = "/freqtrade/user_data/config-dev-NostalgiaForInfinityV5MultiOffsetAndHO.json"
    #   cpu             = 2048
    #   memory          = 900
    #   ft_port         = 8080
    #   ft_metric_port  = 8090
    #   create_instance = true
    # }

    # BigZ04_TSL2 = {
    #   config_path     = "/freqtrade/user_data/config-dev-BigZ04_TSL2.json"
    #   cpu             = 2048
    #   memory          = 458
    #   ft_port         = 8080
    #   ft_metric_port  = 8090
    #   create_instance = true
    # }

    # BigZ04_TSL3 = {
    #   config_path     = "/freqtrade/user_data/config-dev-BigZ04_TSL3.json"
    #   cpu             = 2048
    #   memory          = 458
    #   ft_port         = 8080
    #   ft_metric_port  = 8090
    #   create_instance = true
    # }
    NFIv7HyperOpt = {
      config_path     = "/freqtrade/user_data/config-prod-NFIv7HyperOpt.json"
      cpu             = 2048
      memory          = 458
      ft_port         = 8080
      ft_metric_port  = 8090
      create_instance = true
    }
    NostalgiaForInfinityNext = {
      config_path     = "/freqtrade/user_data/config-prod.json"
      cpu             = 2048
      memory          = 458
      ft_port         = 8080
      ft_metric_port  = 8090
      create_instance = true
    }
  }
  description = "Strategies to run"
}
