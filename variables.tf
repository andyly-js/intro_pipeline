variable "access_key" {
  description = "Access key of AWS IAM user"
  default     = ""
}
variable "secret_key" {
  description = "Secret key of AWS IAM user"
  default     = ""
}

variable "sns_name" {
  description = "Name of the SNS Topic to be created"
  default     = "my_first_sns"
}

variable "region" {
  description = "Name of the region that the AWS resource will be hosted in"
  default = "eu-west-2"
}

variable "force_destroy" {
  description = "(Optional) A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error"
  type        = string
  default     = true
}

variable "sqs_name" {
  description = "Name of the sqs queue to be created. You can assign any unique name for the Queue"
  default     = "my-first-sqs"
}


variable "account_id" {
  description = "My Account Number"
  default     = "191954872959"
}