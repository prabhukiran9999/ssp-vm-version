variable "alb_name" {
  description = "Name of the internal alb"
  default     = "default"
  type        = string
}
variable "app_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  default     = 8080
}
variable "health_check_path" {
  default = "/"
}
variable "service_names" {
  description = "List of service names to use as subdomains"
  default     = ["ssp-vm", "startup-app-vm"]
  type        = list(string)
}
# variable "target_env" {
#   description = "AWS workload account env (e.g. dev, test, prod, sandbox, unclass)"
# }
variable "common_tags" {
  description = "Common tags for created resources"
  default = {
    Application = "Startup Sample"
  }
}