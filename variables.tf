
variable "aws_region" {
description = "aws region"  
default = "ap-south-1"
}

#bucket name 
variable "bucket_name" {
  description = "unique bucket name"
  type        = string
}

variable "versioning_status" {
  description = "bucket versioning 'Enabled' or 'Disabled'"
  type        = string
  default     = "Disabled"
}

variable "build_path" {
  description = "path of build folder"
  type        = string
}

variable "bucket_permission" {
  description = "bucket permissions for public access , true or false"
  type        = bool
  default     = true
}

variable "enable_cloudfront" {
  description = "to create cloudfront or not "
  type        = bool
  default     = "true"
}
