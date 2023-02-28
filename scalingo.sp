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

variable "auto_deploy_exclusion" {
  type    = list(string)
  default = [""]
}

variable "linked_repository_exclusion" {
  type    = list(string)
  default = [""]
}

variable "deploy_review_apps_exclusion" {
  type    = list(string)
  default = [""]
}

variable "log_drain_exclusion" {
  type    = list(string)
  default = [""]
}

variable "log_drain_addon_exclusion" {
  type    = list(string)
  default = [""]
}

benchmark "scalingo" {
  title    = "Scalingo"
  children = [
    control.scalingo_app_name_prefix,
    control.scalingo_app_name_suffix,
    control.scalingo_app_owner,
    control.scalingo_router_logs_are_activated_on_production,
    control.scalingo_no_auto_deploy_on_production,
    control.scalingo_no_linked_repository_on_production,
    control.scalingo_repo_linked_by_app_owner,
    control.scalingo_no_deploy_review_apps,
    control.scalingo_log_drain_on_production,
    control.scalingo_log_drain_on_production_addon,
    control.scalingo_no_long_one_off_running
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

control "scalingo_no_auto_deploy_on_production" {
  title    = "On ne déploie aucune application de production en auto deploy."
  severity = "critical"
  sql      =  <<-EOT
    select
      app.name as resource,
      case
        when (name = any($1) OR app.name NOT LIKE '%-production') then 'skip'
        when not srl.auto_deploy_enabled then 'ok'
        else 'alarm'
      end as status,
      case
        when app.name NOT LIKE '%-production' then 'L''application ' || app.name || ' n''est pas de la production.'
        when not srl.auto_deploy_enabled then 'L''application ' || app.name || ' n''est pas en auto deploy.'
        else  'L''application ' || app.name || ' est en auto deploy depuis '|| srl.scm_type || ':' || srl.owner || '/ '|| srl.repo ||' sur la branche '|| srl.branch ||'.'
      end as reason
    from
      scalingo_scm_repo_link srl
    join
      scalingo_app app on app.id = srl.app_id
  EOT

  param "exclusion" {
    default = var.auto_deploy_exclusion
  }
}

control "scalingo_repo_linked_by_app_owner" {
  title    = "Le code de toutes les applications est lié par le compte de leur owner"
  severity = "critical"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when (linker_username <> owner_username) then 'alarm'
        else 'ok'
      end as status,
      'Le code de l''application ' || name || ' dont le owner est ' || owner_username || ' est lié via le compte  : ' || linker_username || '.' AS reason
    from
      (
        select
          name,
          owner_username,
          (
            select
              linker_username
            from
              scalingo_scm_repo_link
            where
              app_name = name
          ) as linker_username
        from
          scalingo_app app
      ) AS app_with_repo_link
      WHERE app_with_repo_link.linker_username IS NOT NULL
      ;
  EOT
}

control "scalingo_no_linked_repository_on_production" {
  title    = "Aucun repository n'est lié à une application de production."
  severity = "critical"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name = any($1) then 'skip'
        when link is null then 'ok'
        else 'alarm'
      end as status,
      case
        when link IS NULL then 'L''application ' || name || ' n''est pas liée à un repository.'
        else  'L''application ' || name || ' est liée au repository '|| link || '.'
      end as reason
    from
      (
        select
          name,
          (
            select
              scm_type || ':' || owner || '/' || repo
            from
              scalingo_scm_repo_link
            where
              app_name = name
          ) as link
        from
          scalingo_app app
        where
          name LIKE '%-production'
      ) as app_with_repo_link
  EOT

  param "exclusion" {
    default = var.linked_repository_exclusion
  }
}

control "scalingo_no_deploy_review_apps" {
  title    = "Le déploiement des review-apps automatique doit être désactivé."
  severity = "critical"
  sql      =  <<-EOT
    select
      app.name as resource,
      case
        when name = any($1) then 'skip'
        when not srl.deploy_review_apps_enabled then 'ok'
        else 'alarm'
      end as status,
      case
        when srl.deploy_review_apps_enabled then 'L''application ' || app.name || ' a le déploiement des review apps activé.'
        else 'L''application ' || app.name || ' n''a pas le déploiement des review apps activé.'
      end as reason
    from
      scalingo_scm_repo_link srl
    join
      scalingo_app app on app.id = srl.app_id
  EOT

  param "exclusion" {
    default = var.deploy_review_apps_exclusion
  }
}

control "scalingo_log_drain_on_production" {
  title    = "Les applications de production ont un log drain."
  severity = "medium"

  sql      =  <<-EOT
    select
      app.name as resource,
      case
        when app.name = any($1) then 'skip'
        when sld.url IS NULL then 'alarm'
        else 'ok'
      end as status,
      case
        when sld.url IS NULL then 'L''application ' || app.name || ' n''a pas de log drain.'
        else 'L''application ' || app.name || ' a un log drain.'
      end as reason
    from
      scalingo_app app
    left join
      scalingo_log_drain sld on app.name = sld.app_name
    where
      app.name LIKE '%-production'
  EOT

  param "exclusion" {
    default = var.log_drain_exclusion
  }
}

control "scalingo_log_drain_on_production_addon" {
  title    = "Les addons de production ont un log drain."
  severity = "medium"

  sql      =  <<-EOT
    select
      app.name as resource,
      case
        when concat(app.name, '_', addon.provider_id) = any($1) then 'skip'
        when sld.url IS NULL then 'alarm'
        else 'ok'
      end as status,
      case
        when sld.url IS NULL then 'L''addon ' || addon.provider_name || ' de l''application ' || app.name || ' n''a pas de log drain.'
        else 'L''addon ' || addon.provider_name || ' de l''application ' || app.name || ' a un log drain.'
      end as reason
    from
      scalingo_app app
    join
      scalingo_addon addon on addon.app_name = app.name
    left join
      scalingo_log_drain_addon sld on addon.id = sld.id and sld.app_name = addon.app_name
    where
      app.name LIKE '%-production'
  EOT

  param "exclusion" {
    default = var.log_drain_addon_exclusion
  }
}

control "scalingo_no_long_one_off_running" {
  title    = "Aucun one-off ne tourne depuis plus de 24h."
  severity = "medium"

  sql      =  <<-EOT
    select
      c.label as resource,
      case
        when c.created_at < (current_timestamp - interval '1' day) then 'alarm'
        else 'ok'
      end as status,
      'Le container ' || c.label || ' de l''application ' || app.name || ' tourne depuis ' || age(now(), c.created_at) || '.' as reason
    from
      scalingo_app app
    join
      scalingo_container c on c.app_name = app.name
    where
      c.type = 'one-off'
  EOT
}
