variable "app_name_prefix" {
  type    = string
  default = "pix-"
}

variable "app_name_suffix" {
  type    = string
  default = "-(production|review|integration|recette|sandbox|preview|pr[0-9]+)"
}

variable "app_owners" {
  type    = list(string)
  default = ["pix-dev", "pix-prod"]
}

variable "router_logs_exclusion" {
  type    = list(string)
  default = [""]
}

benchmark "scalingo" {
  title    = "Scalingo"
  children = [
    control.scalingo_app_name_prefix,
    control.scalingo_app_name_suffix,
    control.scalingo_app_owner,
    control.scalingo_router_logs_are_activated_on_production
  ]
}

control "scalingo_app_name_prefix" {
  title    = "Le nom de l'application Scalingo a le bon préfixe."
  severity = "medium"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name SIMILAR TO $1 || '%' then 'ok'
        else 'alarm'
      end as status,
      case
        when name SIMILAR TO $1 || '%' then 'L''application ' || name || ' commence par ' || $1 || '.'
        else  'L''application ' || name || ' ne commence pas par ' || $1 || '.'
      end as reason
    from
      scalingo_app
  EOT

  param "prefix" {
    default = var.app_name_prefix
  }
}

control "scalingo_app_name_suffix" {
  title    = "Le nom de l'application Scalingo a le bon suffixe."
  severity = "medium"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name SIMILAR TO '%' || $1 then 'ok'
        else 'alarm'
      end as status,
      case
        when name SIMILAR TO '%' || $1 then 'L''application ' || name || ' finit par ' || $1 || '.'
        else  'L''application ' || name || ' ne finit pas par ' || $1 || '.'
      end as reason
    from
      scalingo_app
  EOT

  param "suffix" {
    default = var.app_name_suffix
  }
}

control "scalingo_app_owner" {
  title    = "Le propriétaire de l'application est normalisé."
  severity = "critical"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when owner_username = any($1) then 'ok'
        else 'alarm'
      end as status,
      'Le propriétaire de l''application ' || name || ' est ' || owner_username || '.' as reason
    from
      scalingo_app
  EOT

  param "owners" {
    default = var.app_owners
  }
}

control "scalingo_router_logs_are_activated_on_production" {
  title    = "Les logs routeur sont activé en production."
  severity = "high"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when (name = any($1) OR name NOT LIKE '%-production') then 'skip'
        when router_logs then 'ok'
        else 'alarm'
      end as status,
      case
        when name NOT LIKE '%-production' then 'L''application ' || name || ' n''est pas de la production.'
        when not router_logs then 'L''application ' || name || ' n''a pas les logs routeurs activés.'
        else  'L''application ' || name || ' a bien les logs routeurs activés.'
      end as reason
    from
      scalingo_app
  EOT

  param "exclusion" {
    default = var.router_logs_exclusion
  }
}
