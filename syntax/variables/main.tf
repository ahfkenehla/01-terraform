provider "local" {
}

variable "number_example" {
	description = "An example of a number variable in Terraform"
	type = number
	default = 42
}

output "number_example" {
	value = var.number_example 
}
