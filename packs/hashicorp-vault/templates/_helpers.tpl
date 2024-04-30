////////////////////////
// Allocation | job-name
////////////////////////

[[- define "job_name" -]]
[[ coalesce ( var "job_name" .) (meta "pack.name" .) | quote ]]
[[- end -]]

////////////////////////
// Allocation | region
////////////////////////

[[- define "region" -]]
[[- with (var "region" .) ]]
  region = [[ . | quote ]]
[[- end ]]
[[- end -]]

////////////////////////
// Allocation | Constraints
////////////////////////

[[- define "constraints" -]]
[[- range $idx, $constraint := . ]]

    constraint {
      attribute = [[ $constraint.attribute | quote ]]
      [[ if $constraint.operator -]]
      operator  = [[ $constraint.operator | quote ]]
      [[ end -]]
      value     = [[ $constraint.value | quote ]]
    }

[[- end ]]
[[- end -]]

////////////////////////
// Group | Network
////////////////////////

[[- define "network" ]]
[[- if or (var "network_mode" .) (var "network_ports" .) ]]

    network {
      [[- with var "network_mode" . ]]
      mode = [[ . | quote ]]
      [[- end ]]

      [[- range $idx,$port := (var "network_ports" .) ]]
      
      port [[ $port.label | quote ]] {
        [[- with $port.static ]]
        static = [[ . ]][[ end ]]
        [[- with $port.to ]]
        to = [[ . ]][[ end ]]
      }
      [[- end ]]
    }

[[- end ]]
[[- end -]]

////////////////////////
// Group | Persistence
////////////////////////
// TODO

////////////////////////
// Group | Services
////////////////////////

[[- define "service" ]]
[[- $service := . ]]

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
// Task | Env. Variables
////////////////////////

[[- define "env_vars" ]]
[[- with . ]]

      env {
        [[- range $k, $v := . ]]
        [[ $k ]] = [[ $v | quote ]]
        [[- end ]]
      }

[[- end ]]
[[- end -]]

////////////////////////
// Task | Resources
////////////////////////

[[- define "resources" ]]

      resources {
        cpu        = [[ $.cpu ]]
        memory     = [[ $.memory ]]
        [[- if gt $.memory_max $.memory ]]
        memory_max = [[ $.memory_max ]][[ end ]]
      }

[[- end -]]

////////////////////////
// Task | Templates
////////////////////////

[[- define "templatefile" ]]
[[- range $tpl := . ]]
[[ with $tpl ]]

      template {
        destination = [[ print "local/" $tpl.name | quote ]]
        perms       = "555"
        data = <<-HEREDOC
          [[ $tpl.data | nindent 10 |trim ]]
          HEREDOC
        change_mode = "noop"
      }

[[- end ]]
[[- end ]]
[[- end ]]

////////////////////////
// Task | Mounts
////////////////////////


[[- define "mount" ]]
[[- range $mnt := . ]]
[[- with $mnt ]]

        mount {
          type   = "bind"
          source = "local/[[ $mnt.name ]]"
          target = "[[ $mnt.mountpath ]]/[[ $mnt.name ]]"
        }
[[- end ]]
[[- end ]]
[[- end ]]