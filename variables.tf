variable "region" {
  default = "ap-northeast-1"
}
variable "configs" {
  type = object({
    ProtectedZeus      = string
    Combined_NFIv7_SMA = string
    NFI7HO2            = string
  })
  description = "Strategies to run, and in which environment"
  default = {
    ProtectedZeus      = "/freqtrade/user_data/config-prod.json"
    Combined_NFIv7_SMA = "/freqtrade/user_data/config-dev-Combined_NFIv7_SMA.json"
    NFI7HO2            = "/freqtrade/user_data/config-dev-NFI7HO2.json"
  }
}
