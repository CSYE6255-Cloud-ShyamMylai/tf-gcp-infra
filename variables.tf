variable "gcp_credentials_file" {
  description = "path to credentials"
}

variable "projectid" {
  description = "projectId for the project"
}
variable "vpcs" {
  description = "List  of VPC Maps"
  type = map(object({
    name                                        = string
    subnet_1                                    = string
    subnet_2                                    = string
    subnet_region                               = string
    subnet_1_cidr_range                         = string
    subnet_2_cidr_range                         = string
    auto_create_subnetworks_flag                = bool
    routing_mode_vpc_network                    = string
    delete_default_routes_on_create_vpc_network = bool
    stack_type_vpc_network                      = string
    vpc_route_name                              = string
    vpc_route_dest_address                      = string
    default_internet_gateway                    = string
  }))
}

variable "projectregion" {
  description = "region for the project"
}
