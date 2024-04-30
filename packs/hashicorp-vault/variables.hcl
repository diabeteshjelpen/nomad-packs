////////////////////////
// Allocation
////////////////////////

variable "job_name" {
  description = "The name to use as the job name which overrides using the pack name"
  type        = string
  default     = ""
}

variable "region" {
  description = "The region where jobs will be deployed"
  type        = string
  default     = ""
}

variable "datacenters" {
  description = "A list of datacenters in the region which are eligible for task placement"
  type        = list(string)
  default     = ["*"]
}

variable "constraints" {
  type = list(object({
    attribute = string
    operator  = string
    value     = string
  }))

  default = [{
    attribute = ""
    operator  = "distinct_hosts"
    value     = "true"
  }]
}

variable "network_mode" {
  description = "host | bridge"
  type        = string
  default     = "bridge" # Host?
}

variable "network_ports" {
  type = list(object({
    label  = string
    static = number
    to     = number
  }))

  default = [{
    label  = "api"
    static = 8200
    to     = 8200
  }, {
    label  = "cluster"
    static = 8201
    to     = 8201
  }]
}

variable "deployment_count" {
  description = "N/A"
  type        = number
  default     = 1
}

////////////////////////
// Services
////////////////////////

variable "services" {
  description = "N/A"
  
  type = list(object({
    name     = string
    port     = string
    provider = string

    checks = list(object({
      name     = string
      type     = string
      path     = string
      interval = string
      timeout  = string
    }))
  }))
  
  default = [{
    name     = "vault-server"
    port     = "api"
    provider = "nomad"

    checks = [{
      name     = "vault-api-healthcheck"
      type     = "http"
      path     = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
      interval = "15s"
      timeout  = "5s"
    }]
  }]
}

////////////////////////
// VaultServer Task
////////////////////////

variable "task_image" {
  description = "N/A"
  
  type = object({
    name    = string
    version = string
  })

  default = {
    name    = "hashicorp/vault"
    version = "1.16.2"
  }
 
}

variable "task_resources" {
  description = "N/A"
  
  type = object({
    cpu        = number
    cpu_strict = bool
    memory     = number
    memory_max = number
  })

  default = {
    cpu        = 200
    cpu_strict = false
    memory     = 128
    memory_max = 128 * 2
  }
}

variable "task_env" {
  type = map(string)
  default = {}
}

variable "task_files" {
  type = list(object({
    name      = string
    mountpath = string
    data      = string
  }))
  
  default = [{
    name      = "config.hcl"
    mountpath = ""
    data      = <<-HEREDOC
      ui            = true
      disable_mlock = true
      api_addr      = "http://{{ env "NOMAD_IP_api" }}:8200"
      cluster_addr  = "http://{{ env "NOMAD_IP_cluster" }}:8201"
      
      listener "tcp" {
        tls_disable     = true
        address         = "[::]:8200"
        cluster_address = "[::]:8201"
      }

      storage "raft" {
        performance_multiplier = 5
        path                   = "{{env "NOMAD_ALLOC_DIR" }}/data"

        retry_join = [
        {{- range nomadService "vault-server" }}
          {
            leader_api_addr = "http://{{ .Address }}:{{ .Port }}"
          },
        {{- end }}
        ]
      }
      HEREDOC
  }]
}

variable "task_args" {
  description = "N/A"
  type        = list(string)
  
  default = [
    "server",
    "-config=/local/config.hcl",
  ]
}

////////////////////////
// VaultUnsealer SidecarTask
////////////////////////
// Optionally build/use dedicated image: <REF HERE>

variable "task_enabled_unsealer" {
  description = "N/A"
  type        = bool
  default     = true
}

variable "task_env_unsealer" {
  description = <<-HEREDOC
    Customize task parameters:
    - NOMAD_VAR_PATH
    - CREDENTIALS_FILE
    - CHECK_INITIAL_DELAY
    - CHECK_DELAY
    - VAULT_SECRET_SHARES
    - VAULT_SECRET_THRESHOLD
    HEREDOC
  
  type = map(string)
  
  default = {
    NOMAD_VAR_PATH         = "example/vault"
    CREDENTIALS_FILE       = "/tmp/vault.json"
    CHECK_INITIAL_DELAY    = "10"
    CHECK_DELAY            = "60"
    VAULT_SECRET_SHARES    = "5"
    VAULT_SECRET_THRESHOLD = "3"
  }
}

variable "task_files_unsealer" {
  type = list(object({
    name      = string
    mountpath = string
    data      = string
  }))
  
  default = [{
    name      = "docker-entrypoint.sh"
    mountpath = "/usr/local/bin"
    data = <<-HEREDOC
      #!/usr/bin/env ash
      set +x -eu -o pipefail

      # 1. Checks Vault Status
      # 2. If Vault not initialized, initialize & store credentials in Nomad Variable (base64-encoded)
      # 3. If Vault sealed, get credentials from Nomad Variable & Unseal
      # 4. Fail/restart if endpoint(s) unavailable
      # NOTE: Intentionally prints secrets to console. Replace 'tee' with '>' to avoid

      ########################
      ## Environment
      ########################

      nomad_var_path=$$${NOMAD_VAR_PATH:-testing/vault/data}
      init_delay=$$${CHECK_INITIAL_DELAY:-"15"}
      delay=$$${CHECK_DELAY:-"15"}
      vault_addr=$$${VAULT_ADDR:-"http://127.0.0.1:8200"}
      shares=$$${VAULT_SECRET_SHARES:-5}
      threshold=$$${VAULT_SECRET_THRESHOLD:-3}
      credentials_file=$$${CREDENTIALS_FILE:-"/tmp/vault.json"}

      ########################
      ## Functions
      ########################

      log() {
        printf "[%s] %s\n" "$(date -u)" "$1"
      }

      vault_check() {
        log "Checking Vault status"
        status=$(curl -X GET -sL $vault_addr/v1/sys/health)
      }

      vault_init() {
        log "Initializing Vault"
        local data="{\"secret_shares\": $shares, \"secret_threshold\": $threshold}"

        curl -sL --retry 5 \
          -X PUT \
          -H "Content-Type: application/json" \
          $vault_addr/v1/sys/init -d "$data"|tee $credentials_file
        
        nomad_write
      }

      vault_unseal() {
        log "Unsealing Vault"
        
        # Always refresh local credentials-file from Nomad Variable data
        nomad_read
        
        # Unseal w/the min. required keys
        for i in $( seq 0 $(($threshold-1)) ); do
          local data={\"key\":\"$(cat $credentials_file|jq -r ".keys[($i)]")\"}
          
          curl -sL --retry 5 \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            $vault_addr/v1/sys/unseal 
        done
      }

      nomad_write() {
        log "Writing init-secrets to Nomad Variable (base64-encoded)"
        
        # This seems OK, but isn't working: jq -n --argjson Items $(cat /vault.json) '$ARGS.named'
        data="{\"Items\": { \"data\": \"$(cat $credentials_file|base64 -w0)\"}}"
        
        # Req. Nomad Workload Identity
        curl -sL --retry 5 \
          -X PUT \
          -H "Authorization: Bearer $NOMAD_TOKEN" \
          --unix-socket $NOMAD_SECRETS_DIR/api.sock \
          -d "$data" \
          localhost/v1/var/$nomad_var_path
      }

      nomad_read() {
        log "Writing Vault credentials from Nomad Variable to local file"
        
        # Req. Nomad Workload Identity
        curl -sL --retry 5 \
          -X GET \
          -H "Authorization: Bearer $NOMAD_TOKEN" \
          --unix-socket $NOMAD_SECRETS_DIR/api.sock \
          localhost/v1/var/$nomad_var_path | jq '.Items.data' | base64 -d | jq | tee $credentials_file
      }

      ########################
      ## OS Requirements
      ########################
      
      apk --no-cache add curl jq

      ########################
      ## Run
      ########################
      
      # Allow Vault to start
      sleep $init_delay

      status=

      while true; do
        vault_check
          
        if [ $(echo $status|jq -r ".initialized") = "false" ]; then
          log "Vault is not initialized"
          vault_init
        fi

        if [ $(echo $status|jq -r ".sealed") = "true" ]; then
        log "Vault is sealed"
          vault_unseal
        fi

        echo
        log ".::.::..::.::..::.::..::.::..::.::..::.::..::.::."
        log ".::.::. Time Until Next Check: $delay seconds .::.::."
        log ".::.::..::.::..::.::..::.::..::.::..::.::..::.::."
        echo
        
        sleep $delay
      done
      HEREDOC
  }]
}
