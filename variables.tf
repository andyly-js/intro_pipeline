variable "access_key" {
        description = "Access key of AWS IAM user"
}
variable "secret_key" {
        description = "Secret key of AWS IAM user"
}


variable "sns_name" {
        description = "Name of the SNS Topic to be created"
        default = "my_first_sns"
}

variable "account_id" {
        description = "My Account Number"
        default = "191954872959"
}