terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 4.6.0"
    }
  }
}

resource "docker_network" "traefik_public" {
  name   = "traefik-public"
  driver = "overlay"
}
