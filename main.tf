terraform {
  required_providers {
    google = {
      source  = "hashicorp/google",
      version = ">=4.51.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta",
      version = ">=4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.gcp_credentials_file)
  project     = var.projectid
  region      = var.projectregion
}

provider "google-beta" {
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
  allow {
    protocol = var.firewall_ssh["deny"]["protocol"]
    ports    = var.firewall_ssh["deny"]["ports"]
  }
  source_ranges = var.firewall_ssh["source_ranges"]
}

### PRIVATE SERVICE ACCESS 
# resource "google_compute_global_address" "private_alloc_vpc" {
#   name          = "allocation-range-vpc-peering"
#   purpose       = "VPC_PEERING"
#   address_type  = "INTERNAL"
#   prefix_length = 24
#   network       = google_compute_network.vpc_network.id
#   # address       = "193.255.0.0"
# }

# resource "google_service_networking_connection" "private_ip_connection" {
#   network                 = google_compute_network.vpc_network.id
#   service                 = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.private_alloc_vpc.name]
# }

resource "google_sql_database_instance" "cloud_sql_instance" {
  provider            = google-beta
  database_version    = "MYSQL_8_0"
  name                = random_id.cloud_sql_instance_generate_id.hex
  # depends_on =[google_service_networking_connection.private_ip_connection]
  deletion_protection = false
  project = var.projectid
  region  = var.projectregion

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 100
    ip_configuration {
      ipv4_enabled = false
      # private_network = google_compute_network.vpc_network.self_link
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.projectid]
      }
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
}


### PRIVATE SERVICE CONNECT
resource "google_compute_address" "sql_instance_subnet_private_ip" {
  name         = "psc-compute-address-${google_sql_database_instance.cloud_sql_instance.name}"
  depends_on   = [google_compute_subnetwork.subnet-2]
  region       = "us-central1"
  address_type = "INTERNAL"
  subnetwork   = var.vpcs["vpc1"].subnet_2 # Replace value with the name of the subnet here.
  # address      = "193.1.254.110"   # Replace value with the IP address to reserve.
}

data "google_sql_database_instance" "sql_instance" {
  name = google_sql_database_instance.cloud_sql_instance.name
}

resource "google_compute_forwarding_rule" "subnet_forwarding_rule" {
  name                  = "psc-forwarding-rule-${google_sql_database_instance.cloud_sql_instance.name}"
  depends_on            = [google_compute_address.sql_instance_subnet_private_ip]
  region                = "us-central1"
  network               = google_compute_network.vpc_network.name
  ip_address            = google_compute_address.sql_instance_subnet_private_ip.self_link
  load_balancing_scheme = ""
  target                = data.google_sql_database_instance.sql_instance.psc_service_attachment_link
}

resource "random_id" "cloud_sql_instance_generate_id" {
  byte_length = 4
  prefix      = "cloud-sql-instance"
}

resource "random_password" "random_generated_password" {
  length = 16
}

locals {
  generated_password = random_password.random_generated_password.result
}

resource "google_sql_database" "cloud_sql_DB" {
  name     = "webapp"
  instance = google_sql_database_instance.cloud_sql_instance.name
}

resource "google_sql_user" "cloud_sql_user" {
  depends_on = [random_password.random_generated_password, google_sql_database_instance.cloud_sql_instance]
  name       = "webapp"
  instance   = google_sql_database_instance.cloud_sql_instance.name
  password   = local.generated_password
}


# # CUSTOM IMAGE -> vm instance
#finds the most resent image of the family 
data "google_compute_image" "custom_image" {
  project = var.projectid
  family  = var.image_family
}


resource "google_compute_instance" "vm_instance_using_mi" {
  depends_on = [google_sql_user.cloud_sql_user,google_compute_address.sql_instance_subnet_private_ip]
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
  name                    = var.custom_vm_map["vm_name"]
  metadata_startup_script = <<EOT
  #!/bin/bash
  if [ -e "/opt/webapp/.env" ]; then
      echo "File already exists"
  else
      echo "DB_HOST=${google_compute_address.sql_instance_subnet_private_ip.address}" >> /opt/webapp/.env
      echo "DB_USERNAME=${google_sql_user.cloud_sql_user.name}">>/opt/webapp/.env
      echo "DB_PASSWORD=${google_sql_user.cloud_sql_user.password}">>/opt/webapp/.env
      echo "DB_DATABASE=${google_sql_database.cloud_sql_DB.name}">>/opt/webapp/.env
      echo "PORT=3500">>/opt/webapp/.env
  fi
  EOT
}
      # echo "DB_HOST=${google_sql_database_instance.cloud_sql_instance.ip_address[0].ip_address}" >> /opt/webapp/.env
