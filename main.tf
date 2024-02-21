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
  name                            = var.vpcs["vpc1"].name
  auto_create_subnetworks         = var.vpcs["vpc1"].auto_create_subnetworks_flag
  routing_mode                    = var.vpcs["vpc1"].routing_mode_vpc_network
  delete_default_routes_on_create = var.vpcs["vpc1"].delete_default_routes_on_create_vpc_network
  project                         = var.projectid
}

resource "google_compute_subnetwork" "subnet-1" {
  name          = var.vpcs["vpc1"].subnet_1
  ip_cidr_range = var.vpcs["vpc1"].subnet_1_cidr_range
  network       = google_compute_network.vpc_network.name
  region        = var.vpcs["vpc1"].subnet_region
  stack_type    = var.vpcs["vpc1"].stack_type_vpc_network

}

resource "google_compute_subnetwork" "subnet-2" {
  name          = var.vpcs["vpc1"].subnet_2
  ip_cidr_range = var.vpcs["vpc1"].subnet_2_cidr_range
  network       = google_compute_network.vpc_network.name
  region        = var.vpcs["vpc1"].subnet_region
  stack_type    = var.vpcs["vpc1"].stack_type_vpc_network
}

resource "google_compute_route" "vpc_route" {
  for_each         = var.vpcs
  name             = each.value.vpc_route_name
  network          = google_compute_network.vpc_network.id
  dest_range       = each.value.vpc_route_dest_address
  next_hop_gateway = each.value.default_internet_gateway
}

resource "google_compute_firewall" "vpc_firewall_web" {
  name        = var.firewall_web["name"]
  network     = google_compute_network.vpc_network.id
  description = var.firewall_web["description"]
  direction   = var.firewall_web["direction"]
  priority    = var.firewall_web["priority"]
  allow {
    protocol = var.firewall_web["allow"]["protocol"]
    ports    = var.firewall_web["allow"]["ports"]
  }
  target_tags   = var.firewall_web["target_tags"]
  source_ranges = var.firewall_web["source_ranges"]
}

resource "google_compute_firewall" "vpc_firewall_ssh" {
  name = var.firewall_ssh["name"]
  # for_each    = var.vpcs
  network     = google_compute_network.vpc_network.id
  description = var.firewall_ssh["description"]
  direction   = var.firewall_ssh["direction"]
  priority    = var.firewall_ssh["priority"]
  deny {
    protocol = var.firewall_ssh["deny"]["protocol"]
    ports    = var.firewall_ssh["deny"]["ports"]
  }
  source_ranges = var.firewall_ssh["source_ranges"]
}

#finds the most resent image of the family 
data "google_compute_image" "custom_image" {
  project = var.projectid
  family  = var.image_family
}

resource "google_compute_instance" "vm_instance_using_mi" {
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet-1.id
    access_config {
      network_tier = var.custom_vm_map["network_tier"]
    }
  }
  tags = var.custom_vm_map["tags"]

  machine_type = var.custom_vm_map["machine_type"]
  zone         = var.custom_vm_map["zone"]
  boot_disk {
    device_name = var.custom_vm_map["boost_disk_initilaize_params_size"]
    initialize_params {
      image = data.google_compute_image.custom_image.self_link
      size  = var.custom_vm_map["boost_disk_initilaize_params_size"]
      type  = var.custom_vm_map["boost_disk_initilaize_params_type"]
    }
  }
  name = var.custom_vm_map["vm_name"]
}
