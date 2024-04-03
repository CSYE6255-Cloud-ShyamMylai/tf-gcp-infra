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
  name                     = var.vpcs["vpc1"].subnet_1
  ip_cidr_range            = var.vpcs["vpc1"].subnet_1_cidr_range
  network                  = google_compute_network.vpc_network.name
  region                   = var.vpcs["vpc1"].subnet_region
  stack_type               = var.vpcs["vpc1"].stack_type_vpc_network
  private_ip_google_access = true

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


## PRIVATE SERVICE ACCESS 
resource "google_compute_global_address" "private_alloc_vpc" {
  name          = "allocation-range-vpc-peering"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.vpc_network.id
  # address       = "193.255.0.0"
}

resource "google_service_networking_connection" "private_ip_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_alloc_vpc.name]
  # deletion_policy = "ABANDON"
}

resource "google_sql_database_instance" "cloud_sql_instance" {
  provider            = google-beta
  database_version    = var.cloud_sql_instance.database_version
  name                = random_id.cloud_sql_instance_generate_id.hex
  depends_on          = [google_service_networking_connection.private_ip_connection]
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
      ipv4_enabled                                  = var.cloud_sql_instance.ipv4_enabled
      private_network                               = google_compute_network.vpc_network.self_link
      enable_private_path_for_google_cloud_services = true
      # psc_config {
      #   psc_enabled               = var.cloud_sql_instance.psc_enabled
      #   allowed_consumer_projects = [var.projectid]
      # }
    }

    backup_configuration {
      enabled            = var.cloud_sql_instance.backup_enabled
      binary_log_enabled = var.cloud_sql_instance.binary_log_enabled
    }
  }
}


### PRIVATE SERVICE CONNECT
# resource "google_compute_address" "sql_instance_subnet_private_ip" {
#   name         = "${var.subnet_endpoint.prefix}-${google_sql_database_instance.cloud_sql_instance.name}"
#   depends_on   = [google_compute_subnetwork.subnet-2]
#   region       = var.vpcs["vpc1"].subnet_region
#   address_type = var.subnet_endpoint.address_type
#   subnetwork   = var.vpcs["vpc1"].subnet_2
# }

# data "google_sql_database_instance" "sql_instance" {
#   name = google_sql_database_instance.cloud_sql_instance.name
# }

# resource "google_compute_forwarding_rule" "subnet_forwarding_rule" {
#   name                  = "${var.forwarding_rule.prefix}-${google_sql_database_instance.cloud_sql_instance.name}"
#   depends_on            = [google_compute_address.sql_instance_subnet_private_ip]
#   region                = var.vpcs["vpc1"].subnet_region
#   network               = google_compute_network.vpc_network.name
#   ip_address            = google_compute_address.sql_instance_subnet_private_ip.self_link
#   load_balancing_scheme = var.forwarding_rule.load_balancing_scheme
#   target                = data.google_sql_database_instance.sql_instance.psc_service_attachment_link
# }

resource "random_id" "cloud_sql_instance_generate_id" {
  byte_length = 4
  prefix      = var.random_id_prefix
}

resource "random_password" "random_generated_password" {
  length           = var.random_password_generator.length
  override_special = var.random_password_generator.override_special
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
  depends_on = [google_sql_database_instance.cloud_sql_instance, google_service_account.vm_service_account]
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
      echo "DB_HOST=${google_sql_database_instance.cloud_sql_instance.private_ip_address}" >> /opt/webapp/.env
      echo "DB_USERNAME=${google_sql_user.cloud_sql_user.name}">>/opt/webapp/.env
      echo "DB_PASSWORD=${local.generated_password}">>/opt/webapp/.env
      echo "DB_DATABASE=${google_sql_database.cloud_sql_DB.name}">>/opt/webapp/.env
      echo "PORT=3500">>/opt/webapp/.env
  fi
  EOT
}

# resource "google_dns_record_set" "a_record_webapp_vm" {
#   name         = data.google_dns_managed_zone.managed_zone.dns_name
#   depends_on   = [google_compute_instance.vm_instance_using_mi]
#   managed_zone = data.google_dns_managed_zone.managed_zone.name
#   type         = var.dns_record_set.type
#   ttl          = var.dns_record_set.ttl
#   rrdatas      = [google_compute_instance.vm_instance_using_mi.network_interface[0].access_config[0].nat_ip]
# }

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
  account_id   = var.service_account_for_cloud_function.account_id
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
      # DB_HOST         = google_compute_address.sql_instance_subnet_private_ip.address
      DB_HOST     = google_sql_database_instance.cloud_sql_instance.private_ip_address
      DB_USERNAME = google_sql_user.cloud_sql_user.name
      DB_PASSWORD = local.generated_password
      DB_DATABASE = google_sql_database.cloud_sql_DB.name
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

resource "google_compute_region_instance_template" "custom_vm_template" {
  name         = var.google_compute_region_instance_template.name
  machine_type = var.google_compute_region_instance_template.machine_type
  disk {
    source_image = data.google_compute_image.custom_image.self_link
  }
  metadata_startup_script = <<EOT
  #!/bin/bash
  if [ -e "/opt/webapp/.env" ]; then
      echo "File already exists"
  else
      echo "DB_HOST=${google_sql_database_instance.cloud_sql_instance.private_ip_address}" >> /opt/webapp/.env
      echo "DB_USERNAME=${google_sql_user.cloud_sql_user.name}">>/opt/webapp/.env
      echo "DB_PASSWORD=${local.generated_password}">>/opt/webapp/.env
      echo "DB_DATABASE=${google_sql_database.cloud_sql_DB.name}">>/opt/webapp/.env
      echo "PORT=3500">>/opt/webapp/.env
  fi
  EOT
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet-1.id
    access_config {
      network_tier = var.google_compute_region_instance_template.network_interface.access_config.network_tier
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = var.google_compute_region_instance_template.service_account.scopes
  }
  #provide the tags of vm instance 
  tags = var.google_compute_region_instance_template.tags
}

resource "google_compute_region_health_check" "health_check" {
  name                = var.google_compute_region_health_check.name
  description         = var.google_compute_region_health_check.description
  check_interval_sec  = var.google_compute_region_health_check.check_interval_sec
  timeout_sec         = var.google_compute_region_health_check.timeout_sec
  unhealthy_threshold = var.google_compute_region_health_check.unhealthy_threshold
  healthy_threshold   = var.google_compute_region_health_check.healthy_threshold
  region              = var.projectregion

  http_health_check {
    port               = var.google_compute_region_health_check.http_health_check.port
    request_path       = var.google_compute_region_health_check.http_health_check.request_path
    port_specification = var.google_compute_region_health_check.http_health_check.port_specification
  }
  log_config {
    enable = var.google_compute_region_health_check.log_config.enable
  }
}


resource "google_compute_firewall" "default_heathcheck_firewall" {
  name          = var.google_compute_health_check_firewall.name
  network       = google_compute_network.vpc_network.id
  source_ranges = var.google_compute_health_check_firewall.source_ranges
  # destination_ranges = [google_compute_subnetwork.subnet-3.ip_cidr_range]
  target_tags = var.google_compute_health_check_firewall.target_tags
  #provide target tags of webapp subnet
  allow {
    protocol = var.google_compute_health_check_firewall.allow.protocol
    ports    = var.google_compute_health_check_firewall.allow.ports
  }
}


resource "google_compute_region_instance_group_manager" "group_manager" {
  name       = var.google_compute_region_instance_group_manager.name
  depends_on = [google_compute_region_instance_template.custom_vm_template, google_compute_region_health_check.health_check]
  lifecycle {
    replace_triggered_by = [google_compute_region_instance_template.custom_vm_template, google_compute_region_health_check.health_check]
  }
  base_instance_name               = var.google_compute_region_instance_group_manager.base_instance_name
  region                           = var.projectregion
  description                      = var.google_compute_region_instance_group_manager.description
  distribution_policy_zones        = var.google_compute_region_instance_group_manager.distribution_policy_zones
  distribution_policy_target_shape = var.google_compute_region_instance_group_manager.distribution_policy_target_shape
  auto_healing_policies {
    initial_delay_sec = var.google_compute_region_instance_group_manager.auto_healing_policies.initial_delay_sec
    health_check      = google_compute_region_health_check.health_check.self_link
  }
  version {
    name              = var.google_compute_region_instance_group_manager.version.name
    instance_template = google_compute_region_instance_template.custom_vm_template.self_link
  }
  # this port is used for load balancer health check 
  named_port {
    name = var.google_compute_region_instance_group_manager.named_port.name
    port = var.google_compute_region_instance_group_manager.named_port.port
  }
}

resource "google_compute_region_autoscaler" "auto_scaling_policy" {
  name       = var.google_compute_region_autoscaler.name
  depends_on = [google_compute_region_instance_group_manager.group_manager]
  lifecycle {
    replace_triggered_by = [google_compute_region_instance_group_manager.group_manager]
  }
  target = google_compute_region_instance_group_manager.group_manager.id

  autoscaling_policy {
    max_replicas    = var.google_compute_region_autoscaler.autoscaling_policy.max_replicas
    min_replicas    = var.google_compute_region_autoscaler.autoscaling_policy.min_replicas
    cooldown_period = var.google_compute_region_autoscaler.autoscaling_policy.cooldown_period
    cpu_utilization {
      target = var.google_compute_region_autoscaler.autoscaling_policy.cpu_utilization.target
      ## change this to 0.05
    }
  }
}


## Load Balancer 
module "gce-lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = ">= 9.0"

  project           = var.projectid
  name              = var.module_load_balancer.name
  network           = google_compute_network.vpc_network.name
  depends_on        = [google_compute_region_instance_group_manager.group_manager, google_compute_region_autoscaler.auto_scaling_policy, google_compute_network.vpc_network]
  firewall_networks = [google_compute_network.vpc_network.name]

  backends = {
    default = {
      port                            = var.module_load_balancer.backends.default.port
      protocol                        = var.module_load_balancer.backends.default.protocol
      port_name                       = var.module_load_balancer.backends.default.port_name
      timeout_sec                     = var.module_load_balancer.backends.default.timeout_sec
      enable_cdn                      = var.module_load_balancer.backends.default.enable_cdn
      connection_draining_timeout_sec = var.module_load_balancer.backends.default.connection_draining_timeout_sec
      session_affinity                = var.module_load_balancer.backends.default.session_affinity

      health_check = {
        request_path        = var.module_load_balancer.backends.default.health_check.request_path
        port                = var.module_load_balancer.backends.default.health_check.port
        check_interval_sec  = var.module_load_balancer.backends.default.health_check.check_interval_sec
        timeout_sec         = var.module_load_balancer.backends.default.health_check.timeout_sec
        unhealthy_threshold = var.module_load_balancer.backends.default.health_check.unhealthy_threshold
        healthy_threshold   = var.module_load_balancer.backends.default.health_check.healthy_threshold
        logging             = var.module_load_balancer.backends.default.health_check.logging
      }

      log_config = {
        enable      = var.module_load_balancer.backends.default.log_config.enable
        sample_rate = var.module_load_balancer.backends.default.log_config.sample_rate
      }

      groups = [
        {
          # Each node pool instance group should be added to the backend.
          group                 = google_compute_region_instance_group_manager.group_manager.instance_group
          balancing_mode        = var.module_load_balancer.backends.default.groups[0].balancing_mode
          max_rate_per_instance = var.module_load_balancer.backends.default.groups[0].max_rate_per_instance
          max_utilization       = var.module_load_balancer.backends.default.groups[0].max_utilization
          capacity_scaler       = var.module_load_balancer.backends.default.groups[0].capacity_scaler
        }
      ]
      iap_config = {
        enable = var.module_load_balancer.backends.default.iap_config.enable
      }
    }
  }
  http_forward                    = var.module_load_balancer.http_forward
  https_redirect                  = var.module_load_balancer.https_redirect
  managed_ssl_certificate_domains = var.module_load_balancer.managed_ssl_certificate_domains
  ssl                             = var.module_load_balancer.ssl
  target_tags                     = var.module_load_balancer.target_tags
}


resource "google_dns_record_set" "a_record_webapp_lb" {
  name       = data.google_dns_managed_zone.managed_zone.dns_name
  depends_on = [module.gce-lb-http]

  managed_zone = data.google_dns_managed_zone.managed_zone.name
  type         = var.dns_record_set.type
  ttl          = var.dns_record_set.ttl
  rrdatas      = [module.gce-lb-http.external_ip]
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
  # target_tags   = var.firewall_web["target_tags"]
  # source_ranges = var.firewall_web["source_ranges"]
  source_ranges      = [module.gce-lb-http.external_ip]
  destination_ranges = [var.vpcs["vpc1"].subnet_1_cidr_range]
}
