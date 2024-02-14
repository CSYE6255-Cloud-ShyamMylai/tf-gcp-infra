terraform {
  required_providers {
    google = {
      source  = "hashicorp/google",
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.gcp_credentials_file)
  project     = var.projectid
  region      = var.subnet_region

}
resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_network_name
  auto_create_subnetworks         = var.auto_create_subnetworks_flag
  routing_mode                    = var.routing_mode_vpc_network
  delete_default_routes_on_create = var.delete_default_routes_on_create_vpc_network
}

resource "google_compute_subnetwork" "subnet-1" {
  name               = var.subnet_1
  ip_cidr_range      = var.subnet_1_cidr_range
  network            = google_compute_network.vpc_network.id
  region             = var.subnet_region
  secondary_ip_range = var.secondary_ip_range_subnets
  stack_type         = var.stack_type_vpc_network
}

resource "google_compute_subnetwork" "subnet-2" {
  name               = var.subnet_2
  ip_cidr_range      = var.subnet_2_cidr_range
  network            = google_compute_network.vpc_network.id
  region             = var.subnet_region
  secondary_ip_range = var.secondary_ip_range_subnets
  stack_type         = var.stack_type_vpc_network
}

# resource "google_compute_route" "vpc_route" {
#   name             = var.vpc_route_name
#   network          = google_compute_network.vpc_network.id
#   dest_range       = var.subnet_1_cidr_range
#   next_hop_gateway = var.default_internet_gateway
# }
