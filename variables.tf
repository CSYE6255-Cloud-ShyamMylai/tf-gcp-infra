variable "gcp_credentials_file" {
  description = "path to credentials"
}

variable "projectid" {
  description = "projectId for the project"
}

variable "vpc_network_name" {
  description = "name of the vpc network"
}

variable "subnet_1" {
  description = "name of the first subnet (webapp)"
}

variable "subnet_2" {
  description = "name of the second subnet (db)"
}

variable "subnet_region" {
  description = "region of the subnet"
}

variable "subnet_1_cidr_range" {
  description = "cidr range for subnet1"
}

variable "subnet_2_cidr_range" {
  description = "cidr range for subnet2"
}

variable "auto_create_subnetworks_flag" {
  description = "subnetworks flag"
}

variable "routing_mode_vpc_network" {
  description = "region for vpc network"
}

variable "delete_default_routes_on_create_vpc_network" {
  description = "delete default routes on vpc network"
}

variable "stack_type_vpc_network" {
  description = "stack type for vpc network"
}

variable "secondary_ip_range_subnets" {
  description = "secondary ip range for subnet"
}

variable "vpc_route_name" {
  description = "name of the route"
}

# variable "vpc_route_dest_address" {
#   description = "destination address for the route"
# }

variable "default_internet_gateway" {
  description = "default internet gateway"
}
