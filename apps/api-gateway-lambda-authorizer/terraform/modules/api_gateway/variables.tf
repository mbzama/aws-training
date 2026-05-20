variable "api_name" {
  description = "Name of the HTTP API"
  type        = string
}

variable "description" {
  description = "Description of the HTTP API"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "API stage name"
  type        = string
  default     = "prod"
}

variable "authorizer_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer"
  type        = string
}

variable "authorizer_function_name" {
  description = "Function name of the Lambda authorizer (for permission)"
  type        = string
}

variable "backend_invoke_arn" {
  description = "Invoke ARN of the backend Lambda"
  type        = string
}

variable "backend_function_name" {
  description = "Function name of the backend Lambda (for permission)"
  type        = string
}

variable "authorizer_cache_ttl" {
  description = "Authorizer result cache TTL in seconds (0 to disable)"
  type        = number
  default     = 300
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
