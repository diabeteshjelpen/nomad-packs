app {
  url = "https://www.vaultproject.io/"
}

pack {
  name    = "hashicorp-vault"
  version = "0.1.0"
  
  description = <<-HEREDOC
    A pack for deploying Vauly on Nomad.
    Includes an optional sidecar-task for automatic intialization
    & unsealing of Vault. Init credentials are stored as Nomad Variable.
    HEREDOC
}
