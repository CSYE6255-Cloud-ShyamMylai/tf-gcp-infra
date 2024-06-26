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

variable "blockeverything_for_db" {
  description = "block everything for db"
  type        = any

}

variable "allow_just_tags_for_db" {
  description = "allow just tags for db"
  type        = any

}

variable "dns_managed_zone" {
  description = "dns managed zone"
  type        = string
}


variable "vm_service_account" {
  description = "vm service account details"
  type        = any
}

variable "dns_record_set" {
  description = "dns record set"
  type        = any
}

variable "service_account_constant" {
  description = "service account constant"
  type        = any
  default     = "serviceAccount"
}

variable "pub_sub_topic" {
  description = "pub sub topic"
  type        = any
}


variable "bucket_object_details" {
  description = "bucket object details"
  type        = any

}

variable "service_account_for_cloud_function" {
  description = "service account for cloud function"
  type        = any
}

variable "cloud_function_for_verify_email" {
  description = "cloud function verify email"
  type        = any
}


variable "google_vpc_access_connector" {
  description = "google vpc access connector"
  type        = any

}

variable "google_compute_region_instance_template" {
  description = "google compute instance regional template"
  type        = any
}

variable "google_compute_region_health_check" {
  description = "google compute region health check"
  type        = any
}


variable "google_compute_health_check_firewall" {
  description = "google compute health check firewall"
  type        = any
}


variable "google_compute_region_instance_group_manager" {
  description = "google compute region instance group manager"
  type        = any
}

variable "google_compute_region_autoscaler" {
  description = "google compute region autoscaler"
  type        = any
}

variable "random_password_generator" {
  description = "random password generator"
  type        = any
}

variable "module_load_balancer" {
  description = "module for load balancer initialization"
  type        = any

}

variable "key_ring_details_randomizer" {
  description = "key ring details randomizer"
  type        = any
}

variable "cloud_sql_randomizer" {
  description = "cloud sql randomizer"
  type        = any
}

variable "general_crypto_properties" {
  description = "general crypto properties"
  type        = any
}

variable "cloud_bucket_randomizer" {
  description = "cloud bucket randomizer"
  type        = any
}

variable "cloud_bucket_details" {
  description = "cloud bucket details"
  type        = any
}


variable "cloud_object_details" {
  description = "storage bucket details"
  type        = any
}

variable "vm_instance_randomizer" {
  description = "vm instance randomizer"
  type        = any
}

variable "vpc_peering_details" {
  description = "vpc peering details"
  type        = any
}

variable "storage_service_account_constant" {
  description = "storage service account constant"
  type        = any
  default     = "@gs-project-accounts.iam.gserviceaccount.com"
}

variable "compute_service_account_constant" {
  description = "compute service account constant"
  type        = any
  default     = "@compute-system.iam.gserviceaccount.com"
}

variable "sqladmin_api" {
  description = "sqladmin api"
  type        = any
  default     = "sqladmin.googleapis.com"
}

variable "service_networking_api" {
  description = "service networking api"
  type        = any
  default     = "servicenetworking.googleapis.com"
}
