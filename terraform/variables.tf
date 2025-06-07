variable "region" {
  type    = string
  default = "us-east-1"
}

variable "lambda_function_name" {
  type    = string
  default = "file_processor_${random_id.suffix.hex}"
}
