# terraform.tf

terraform {
  required_version = ">= 1.15.7"

  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-pihole"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}