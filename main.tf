terraform {
  required_providers {
    google = {
      source  = "hashicorp/google",
      version = ">=5.21.0"
    }

    google-beta = {
      source  = "hashicorp/google-beta",
      version = ">=4.51.0"
    }

    archive = {
      source  = "hashicorp/archive",
      version = ">=2.4.2"
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
  provider         = google-beta
  database_version = var.cloud_sql_instance.database_version
  name             = random_id.cloud_sql_instance_generate_id.hex
  # depends_on =[google_service_networking_connection.private_ip_connection]
  deletion_protection = false
  project             = var.projectid
  region              = var.projectregion

  settings {
    tier              = var.cloud_sql_instance.tier
    edition           = var.cloud_sql_instance.edition
    availability_type = var.cloud_sql_instance.availability_type
    disk_type         = var.cloud_sql_instance.disk_type
    disk_size         = var.cloud_sql_instance.disk_size
    ip_configuration {
      ipv4_enabled = var.cloud_sql_instance.ipv4_enabled
      # private_network = google_compute_network.vpc_network.self_link
      # enable_private_path_for_google_cloud_services = true 
      psc_config {
        psc_enabled               = var.cloud_sql_instance.psc_enabled
        allowed_consumer_projects = [var.projectid]
      }
    }

    backup_configuration {
      enabled            = var.cloud_sql_instance.backup_enabled
      binary_log_enabled = var.cloud_sql_instance.binary_log_enabled
    }
  }
}


### PRIVATE SERVICE CONNECT
resource "google_compute_address" "sql_instance_subnet_private_ip" {
  name         = "${var.subnet_endpoint.prefix}-${google_sql_database_instance.cloud_sql_instance.name}"
  depends_on   = [google_compute_subnetwork.subnet-2]
  region       = var.vpcs["vpc1"].subnet_region
  address_type = var.subnet_endpoint.address_type
  subnetwork   = var.vpcs["vpc1"].subnet_2
}

data "google_sql_database_instance" "sql_instance" {
  name = google_sql_database_instance.cloud_sql_instance.name
}

resource "google_compute_forwarding_rule" "subnet_forwarding_rule" {
  name                  = "${var.forwarding_rule.prefix}-${google_sql_database_instance.cloud_sql_instance.name}"
  depends_on            = [google_compute_address.sql_instance_subnet_private_ip]
  region                = var.vpcs["vpc1"].subnet_region
  network               = google_compute_network.vpc_network.name
  ip_address            = google_compute_address.sql_instance_subnet_private_ip.self_link
  load_balancing_scheme = var.forwarding_rule.load_balancing_scheme
  target                = data.google_sql_database_instance.sql_instance.psc_service_attachment_link
}

resource "random_id" "cloud_sql_instance_generate_id" {
  byte_length = 4
  prefix      = var.random_id_prefix
}

resource "random_password" "random_generated_password" {
  length = 5
}

locals {
  generated_password = random_password.random_generated_password.result
}

resource "terraform_data" "trigger_vm_creation_on_password_change" {
  input = local.generated_password
}
resource "google_sql_database" "cloud_sql_DB" {
  name     = var.database_name
  instance = google_sql_database_instance.cloud_sql_instance.name
}

resource "google_sql_user" "cloud_sql_user" {
  depends_on = [random_password.random_generated_password, google_sql_database_instance.cloud_sql_instance]
  name       = var.database_username
  instance   = google_sql_database_instance.cloud_sql_instance.name
  password   = local.generated_password
}


# # CUSTOM IMAGE -> vm instance
#finds the most resent image of the family 
data "google_compute_image" "custom_image" {
  project = var.projectid
  family  = var.image_family
}

data "google_dns_managed_zone" "managed_zone" {
  name = var.dns_managed_zone
}

### serrvice account 
resource "google_service_account" "vm_service_account" {
  account_id   = var.vm_service_account.account_id
  display_name = var.vm_service_account.display_name
  project      = var.projectid
}

resource "google_compute_instance" "vm_instance_using_mi" {
  depends_on = [google_sql_database_instance.cloud_sql_instance, google_compute_address.sql_instance_subnet_private_ip, google_service_account.vm_service_account]
  lifecycle {
    replace_triggered_by = [google_sql_database_instance.cloud_sql_instance]
  }
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
  allow_stopping_for_update = true # allow the instance to be stopped for update
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = var.vm_service_account.scopes
  }

  name                    = var.custom_vm_map["vm_name"]
  metadata_startup_script = <<EOT
  #!/bin/bash
  if [ -e "/opt/webapp/.env" ]; then
      echo "File already exists"
  else
      echo "DB_HOST=${google_compute_address.sql_instance_subnet_private_ip.address}" >> /opt/webapp/.env
      echo "DB_USERNAME=${google_sql_user.cloud_sql_user.name}">>/opt/webapp/.env
      echo "DB_PASSWORD=${local.generated_password}">>/opt/webapp/.env
      echo "DB_DATABASE=${google_sql_database.cloud_sql_DB.name}">>/opt/webapp/.env
      echo "PORT=3500">>/opt/webapp/.env
  fi
  EOT
}

resource "google_dns_record_set" "a_record_webapp_vm" {
  name         = data.google_dns_managed_zone.managed_zone.dns_name
  depends_on   = [google_compute_instance.vm_instance_using_mi]
  managed_zone = data.google_dns_managed_zone.managed_zone.name
  type         = var.dns_record_set.type
  ttl          = var.dns_record_set.ttl
  rrdatas      = [google_compute_instance.vm_instance_using_mi.network_interface[0].access_config[0].nat_ip]
}

resource "google_project_iam_binding" "binding_loggin_adming_to_serviceaccount" {
  project = var.projectid
  role    = var.vm_service_account.logging_role
  members = [
    "${var.service_account_constant}:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_project_iam_binding" "binding_montironing_metric_writer_to_serviceaccount" {
  project = var.projectid
  role    = var.vm_service_account.monitoring_role
  members = [
    "${var.service_account_constant}:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_project_iam_binding" "binding_service_control_to_serviceaccount" {
  project = var.projectid
  role    = var.vm_service_account.pubsub_publisher_role
  members = ["${var.service_account_constant}:${google_service_account.vm_service_account.email}"]
}


resource "google_pubsub_topic" "verify_email" {
  name                       = var.pub_sub_topic.name
  message_retention_duration = var.pub_sub_topic.message_retention_duration
  project                    = var.projectid
}


resource "random_id" "bucket_prefix" {
  byte_length = 8
}

### storage bucket 

data "google_storage_bucket" "storage_bucket_of_cloud_function" {
  name = var.bucket_object_details.bucket_name
}

data "google_storage_bucket_object" "storage_bucket_object_of_cloud_function" {
  bucket = data.google_storage_bucket.storage_bucket_of_cloud_function.name
  name   = var.bucket_object_details.object_file_name
}

resource "google_service_account" "service_account_for_cloud_function" {
  account_id   =  var.service_account_for_cloud_function.account_id
  display_name = var.service_account_for_cloud_function.display_name
  project      = var.projectid
}

resource "google_cloudfunctions2_function" "cloud_function_for_verify_email" {
  name        = var.cloud_function_for_verify_email.name
  description = var.cloud_function_for_verify_email.description
  location    = var.projectregion
  build_config {
    runtime     = var.cloud_function_for_verify_email.build_config.runtime
    entry_point = var.cloud_function_for_verify_email.build_config.entry_point
    source {
      storage_source {
        bucket = data.google_storage_bucket.storage_bucket_of_cloud_function.name
        object = data.google_storage_bucket_object.storage_bucket_object_of_cloud_function.name
      }
    }
  }

  event_trigger {
    trigger_region        = var.cloud_function_for_verify_email.event_trigger.trigger_region
    event_type            = var.cloud_function_for_verify_email.event_trigger.event_type
    pubsub_topic          = google_pubsub_topic.verify_email.id
    retry_policy          = var.cloud_function_for_verify_email.event_trigger.retry_policy
    service_account_email = google_service_account.service_account_for_cloud_function.email
  }

  service_config {
    service                          = var.cloud_function_for_verify_email.service_config.service
    available_memory                 = var.cloud_function_for_verify_email.service_config.available_memory
    max_instance_request_concurrency = var.cloud_function_for_verify_email.service_config.max_instance_request_concurrency
    environment_variables = {
      MAILGUN_API_KEY = var.cloud_function_for_verify_email.service_config.environment_variables.MAILGUN_API_KEY,
      MAILGUN_DOMAIN  = var.cloud_function_for_verify_email.service_config.environment_variables.MAILGUN_DOMAIN,
      DB_HOST         = google_compute_address.sql_instance_subnet_private_ip.address
      DB_USERNAME     = google_sql_user.cloud_sql_user.name
      DB_PASSWORD     = local.generated_password
      DB_DATABASE     = google_sql_database.cloud_sql_DB.name
    }
    max_instance_count            = var.cloud_function_for_verify_email.service_config.max_instance_count
    service_account_email         = google_service_account.service_account_for_cloud_function.email
    available_cpu                 = var.cloud_function_for_verify_email.service_config.available_cpu
    ingress_settings              = var.cloud_function_for_verify_email.service_config.ingress_settings
    vpc_connector                 = google_vpc_access_connector.serverless_function_connector.name
    vpc_connector_egress_settings = var.cloud_function_for_verify_email.service_config.vpc_connector_egress_settings
  }
}

### IAM BINDING FOR CLOUD RUN SERVICE ACCOUNT 
resource "google_project_iam_binding" "binding_cloud_function_to_service_account_service_run_invoker" {
  project = var.projectid
  role    = var.service_account_for_cloud_function.invoker_role
  members = [
    "${var.service_account_constant}:${google_service_account.service_account_for_cloud_function.email}",
  ]
}
resource "google_project_iam_binding" "binding_cloud_function_to_service_account_service_sql_client" {
  project = var.projectid
  role    = var.service_account_for_cloud_function.cloudsql_role
  members = ["${var.service_account_constant}:${google_service_account.service_account_for_cloud_function.email}"]
}

resource "google_vpc_access_connector" "serverless_function_connector" {
  name          = var.google_vpc_access_connector.name
  region        = var.projectregion
  project       = var.projectid
  network       = google_compute_network.vpc_network.name
  ip_cidr_range = var.google_vpc_access_connector.ip_cidr_range
}
