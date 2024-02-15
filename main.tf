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
  region      = var.projectregion
}
resource "google_compute_network" "vpc_network" {
  for_each                        = var.vpcs
  name                            = each.value.name
  auto_create_subnetworks         = each.value.auto_create_subnetworks_flag
  routing_mode                    = each.value.routing_mode_vpc_network
  delete_default_routes_on_create = each.value.delete_default_routes_on_create_vpc_network
  project                         = var.projectid
}

resource "google_compute_subnetwork" "subnet-1" {
  for_each      = var.vpcs
  name          = each.value.subnet_1
  ip_cidr_range = each.value.subnet_1_cidr_range
  network       = google_compute_network.vpc_network[each.key].id
  region        = each.value.subnet_region
  stack_type    = each.value.stack_type_vpc_network
}

resource "google_compute_subnetwork" "subnet-2" {
  for_each      = var.vpcs
  name          = each.value.subnet_2
  ip_cidr_range = each.value.subnet_2_cidr_range
  network       = google_compute_network.vpc_network[each.key].id
  region        = each.value.subnet_region
  stack_type    = each.value.stack_type_vpc_network
}

resource "google_compute_route" "vpc_route" {
  for_each         = var.vpcs
  name             = each.value.vpc_route_name
  network          = google_compute_network.vpc_network[each.key].id
  dest_range       = each.value.vpc_route_dest_address
  next_hop_gateway = each.value.default_internet_gateway
}
