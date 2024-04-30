////////////////////////
// allocation - job-name
////////////////////////

[[- define "job_name" -]]
[[ coalesce ( var "job_name" .) (meta "pack.name" .) | quote ]]
[[- end -]]

////////////////////////
// allocation - region
////////////////////////

[[ define "region" -]]
[[- if var "region" . -]]
  region = "[[ var "region" . ]]"
[[- end -]]
[[- end -]]

////////////////////////
// allocation - constraints
////////////////////////

[[ define "constraints" -]]
[[ range $idx, $constraint := . ]]
  constraint {
    attribute = [[ $constraint.attribute | quote ]]
    [[ if $constraint.operator -]]
    operator  = [[ $constraint.operator | quote ]]
    [[ end -]]
    value     = [[ $constraint.value | quote ]]
  }
[[ end -]]
[[- end -]]

////////////////////////
// services
////////////////////////

[[ define "service" -]]
[[ $service := . ]]
      service {
        name = [[ $service.service_name | quote ]]
        port = [[ $service.service_port_label | quote ]]
        tags = [[ $service.service_tags | toStringList ]]
        provider = [[ $service.service_provider | quote ]]
        [[- if $service.upstreams ]]
        connect {
          sidecar_service {
            proxy {
              [[- range $upstream := $service.upstreams ]]
              upstreams {
                destination_name = [[ $upstream.name | quote ]]
                local_bind_port  = [[ $upstream.port ]]
              }
              [[- end ]]
            }
          }
        }
        [[- end ]]
        check {
          type     = [[ $service.check_type | quote ]]
          [[- if $service.check_path]]
          path     = [[ $service.check_path | quote ]]
          [[- end ]]
          interval = [[ $service.check_interval | quote ]]
          timeout  = [[ $service.check_timeout | quote ]]
        }
      }
[[- end ]]

////////////////////////
// task - env_vars
////////////////////////

[[ define "env_vars" -]][[ range $k, $v := . ]]
      [[ $k ]] = [[ $v | quote ]]
[[- end ]][[ end ]]

////////////////////////
// task - resources
////////////////////////

[[ define "resources" -]]
[[- $resources := . ]]
      resources {
        cpu    = [[ $resources.cpu ]]
        memory = [[ $resources.memory ]]
      }
[[- end ]]
