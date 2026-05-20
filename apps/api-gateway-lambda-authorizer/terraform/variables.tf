variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "lambda-authorizer"
}

# -------------------------------------------------------
# Lambda deployment packages
# -------------------------------------------------------

variable "authorizer_s3_key" {
  description = "S3 key for the authorizer Lambda zip (e.g. builds/authorizer-v1.0.0.zip)"
  type        = string
  default     = "builds/authorizer.zip"
}

variable "backend_s3_key" {
  description = "S3 key for the backend Lambda zip (e.g. builds/backend-v1.0.0.zip)"
  type        = string
  default     = "builds/backend.zip"
}

# -------------------------------------------------------
# JWT / Authorizer settings
# -------------------------------------------------------
variable "jwt_secret" {
  description = "HMAC secret for JWT verification (min 32 chars recommended)"
  type        = string
  sensitive   = true
}

variable "jwt_algorithm" {
  description = "JWT signing algorithm (HS256, HS384, HS512, RS256, RS384, RS512)"
  type        = string
  default     = "HS256"

  validation {
    condition     = contains(["HS256", "HS384", "HS512", "RS256", "RS384", "RS512"], var.jwt_algorithm)
    error_message = "jwt_algorithm must be one of: HS256, HS384, HS512, RS256, RS384, RS512."
  }
}

variable "jwt_issuer" {
  description = "Expected JWT issuer claim (leave empty to skip validation)"
  type        = string
  default     = ""
}

variable "jwt_audience" {
  description = "Expected JWT audience claim (leave empty to skip validation)"
  type        = string
  default     = ""
}

variable "allowed_scopes" {
  description = "Comma-separated list of required scopes (leave empty to skip validation)"
  type        = string
  default     = ""
}

variable "authorizer_cache_ttl" {
  description = "Authorizer result cache TTL in seconds (0 to disable)"
  type        = number
  default     = 300
}

# -------------------------------------------------------
# API Gateway
# -------------------------------------------------------

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

# -------------------------------------------------------
# Misc
# -------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
