////////////////////////
// Allocation
////////////////////////

variable "job_name" {
  description = "The name to use as the job name which overrides using the pack name"
  type        = string
  default     = ""
}

variable "region" {
  description = "The region where jobs will be deployed"
  type        = string
  default     = ""
}

variable "datacenters" {
  description = "A list of datacenters in the region which are eligible for task placement"
  type        = list(string)
  default     = ["*"]
}

variable "ports" {
  type = list(object({
    label  = string
    static = number
    to     = number
  }))

  default = [{
    label  = "http"
    static = 0
    to     = 80
  }]
}

////////////////////////
// Services
////////////////////////

variable "services" {
  description = "N/A"
  
  type = list(object({
    name = string
  }))
  
  default = [{
    name     = "nightscout"
    provider = "nomad"
    port     = "http"
  }]
}

////////////////////////
// Nightscout Task
////////////////////////

variable "task_image_nightscout" {
  description = "N/A"
  type        = string
  default     = "nginx:alpine"
}

variable "task_resources_nightscout" {
  description = "N/A"
  
  type = object({
    cpu        = number
    cpu_strict = bool
    memory     = number
    memory_max = number
  })

  default = {
    cpu        = 100
    cpu_strict = false
    memory     = 64
    memory_max = 256
  }
}

variable "task_env_nightscout" {
  type = map(string)
  default = {
    FOO = "bar"
    BAR = "baz"
  }
}

////////////////////////
// Database Task
////////////////////////

