terraform {
  required_version = ">= 1.15.7"

  cloud {
    organization = "softcraft"

    workspaces {
      name = "homenet-openclaw"
    }
  }

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {
  context = "murpheux-scarlet"
}

provider "tls" {}
provider "local" {}
