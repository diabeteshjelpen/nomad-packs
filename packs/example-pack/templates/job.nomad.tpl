job [[ template "job_name" . ]] {
  datacenters = [[ var "datacenters" . | toStringList ]]
  type        = "service"

  [[ template "region" . ]]

  group "app" {
    count = 1

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    task "main" {
      driver = "docker"
      leader = true

[[- with ( var "task_env" . ) ]]

      env {
      [[- template "env_vars" . ]]
      }
[[- end ]]
      
      config {
        image = [[ var "task_image" . | quote ]]
      }
    }
  }
}
