job [[ template "job_name" . ]] {
  datacenters = [[ var "datacenters" . | toStringList ]]
  type        = "service"

  [[- template "region" . ]]


  group "main" {
    count = [[ var "deployment_count" . ]]
  
    [[- template "constraints" (var "constraints" .) ]]

    restart {
      attempts = 3
      interval = "30m"
      delay    = "120s"
      mode     = "fail"
    }

    // TODO - better persistence ..
    ephemeral_disk {
      size    = 300
      sticky  = true
      migrate = true
    }

    // TODO - replace w/variable
    service {
      provider = "nomad"
      name     = "vault-server"
      port     = "api"

      check {
        name     = "vault-api-healthcheck"
        type     = "http"
        path     = "/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"
        interval = "15s"
        timeout  = "5s"
      }
    }

    [[- template "network" . ]]

    ////////////////////////
    // VaultServer
    ////////////////////////

    task "vault-server" {
      driver = "docker"
      leader = true

      [[- template "resources" ( var "task_resources" . ) ]]
      [[- template "env_vars" ( var "task_env" . ) ]]
      [[- template "templatefile" (var "task_files" .) ]]
      
      config {
        image = [[ print (var "task_image.name" .) ":" (var "task_image.version" .) | quote ]]
        args  = [[ var "task_args" . | toStringList ]]
        
        [[- with (var "cpu_hard_limit" .) ]]
        
        cpu_hard_limit = [[ . ]]
        
        [[- end ]]

        [[- with (var "network_ports" .) ]]
        
        ports = [
          [[- range $idx,$port := . ]]
          [[ $port.label | quote ]],
          [[- end ]]
        ]
        
        [[- end ]]

        [[- template "mount" (var "task_files" .) ]]
      }
    }

    [[- if (var "task_enabled_unsealer" .) ]]

    ////////////////////////
    // AutoUnsealer
    ////////////////////////
    
    task "auto-unsealer" {
      driver = "docker"

      identity { # Nomad Task API > /secrets/api.sock
        env         = true # sets NOMAD_TOKEN
        change_mode = "restart"
      }

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

      restart {
        attempts = 3
        interval = "15m"
        delay    = "30s"
        mode     = "fail"
      }

      resources {
        cpu        = 25
        memory     = 16
        memory_max = 64
      }

      [[- template "env_vars" ( var "task_env_unsealer" . ) ]]
      [[- template "templatefile" (var "task_files_unsealer" .) ]]

      config {
        image   = "alpine:3"
        command = "/usr/local/bin/docker-entrypoint.sh"
        
        [[- template "mount" (var "task_files_unsealer" .) ]]
      }
    }

    [[- end ]]
  }
}
