variable "gcp_credentials_file" {
  description = "path to credentials"
}

variable "projectid" {
  description = "projectId for the project"
}
variable "vpcs" {
  description = "vpc network details"
  # type = map(any)
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

variable "custom_vm_map" {
  description = "custom instance map"
  type        = any
}

variable "firewall_ssh" {
  description = "firewall ssh"
  type        = any
}

variable "firewall_web" {
  description = "firewall web"
  type        = any
}

variable "most_recent_image" {
  description = "most recent image"
  type        = string
  default     = "csye6255packer-dev-assignment04"
}
variable "image_family" {
  default     = "csye6255packer-dev"
  description = "The family of images to filter"
}

variable "subnet_endpoint" {
  description = "subnet endpoint"
  type        = any
}

variable "database_name" {
  description = "database name"
  type        = string
}

variable "database_username" {
  description = "database user name"
  type        = string
}

variable "random_id_prefix" {
  description = "random id prefix"
  type        = string
}

variable "cloud_sql_instance" {
  description = "cloud sql instance"
  type        = any
}

variable "forwarding_rule" {
  description = "forwarding rule"
  type        = any
}
