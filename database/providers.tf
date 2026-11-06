# providers.tf

# Swarm manager: services, secrets, the overlay network, and scarlet's local volumes.
provider "docker" {
  context = "murpheux-scarlet"
}

# Worker daemons, used only to create node-local data volumes on those nodes.
provider "docker" {
  alias   = "gru"
  context = "murpheux-gru"
}

provider "docker" {
  alias   = "cass"
  context = "murpheux-cass"
}
