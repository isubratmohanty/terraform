# Input variable: server port
variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = "8080"
}

# Input variable: S3 bucket name
variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique."
  default     = "terraform-state-my-bucket"
}

# Input variable for current iam role version
variable "current_version" {
  description = "current version of IAM role "
  default     = "2012-10-17"
}
