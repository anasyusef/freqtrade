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
    # ElliotV8 = {
    #   config_path     = "/freqtrade/user_data/config-dev-ElliotV8.json"
    #   cpu             = 2048
    #   memory          = 900
    #   ft_port         = 8080
    #   ft_metric_port  = 8090
    #   create_instance = true
    # }

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

    NASMAO = {
      config_path     = "/freqtrade/user_data/config-dev-NASMAO.json"
      cpu             = 2048
      memory          = 458
      ft_port         = 8080
      ft_metric_port  = 8090
      create_instance = true
    }
    NostalgiaForInfinityNext_Y = {
      config_path     = "/freqtrade/user_data/config-prod-y.json"
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
    
    NostalgiaForInfinityNext_Alb = {
      config_path     = "/freqtrade/user_data/config-prod-alb.json"
      cpu             = 2048
      memory          = 458
      ft_port         = 8080
      ft_metric_port  = 8090
      create_instance = true
    }
  }
  description = "Strategies to run"
}
