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

variable "database_reachable_exclusion" {
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
    control.scalingo_no_long_one_off_running,
    control.scalingo_database_not_reachable_on_internet
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
      'L''application ' || name || ' commence par ' || $1 || '.' as reason
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
      'L''application ' || name || ' finit par ' || $1 || '.' as reason
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
        when name = any($1) then 'skip'
        when router_logs then 'ok'
        else 'alarm'
      end as status,
      case
        when not router_logs then 'L''application ' || name || ' n''a pas les logs routeurs activés.'
        else  'L''application ' || name || ' a bien les logs routeurs activés.'
      end as reason
    from
      scalingo_app
    where
      name LIKE '%-production'
  EOT

  param "exclusion" {
    default = var.router_logs_exclusion
  }
}

control "scalingo_no_auto_deploy_on_production" {
  title    = "On ne déploie aucune application de production en auto deploy."
  severity = "critical"
  sql      =  <<-EOT
    with apps_and_link as (
      select
        name,
        owner_username,
        (
          select
            auto_deploy_enabled
          from
            scalingo_scm_repo_link
          where
            app_name = name
        ) as auto_deploy_enabled
      from
        scalingo_app app
      where
        app.name LIKE '%-production'
    )
    select
      name as resource,
      case
        when (name = any($1) or auto_deploy_enabled is null) then 'skip'
        when not auto_deploy_enabled then 'ok'
        else 'alarm'
      end as status,
      case
        when not auto_deploy_enabled then 'L''application ' || name || ' n''est pas en auto deploy.'
        else 'L''application ' || name || ' est en auto deploy.'
      end as reason
    from
      apps_and_link
  EOT

  param "exclusion" {
    default = var.auto_deploy_exclusion
  }
}

control "scalingo_repo_linked_by_app_owner" {
  title    = "Le code de toutes les applications est lié par le compte de leur owner"
  severity = "critical"
  sql      =  <<-EOT
    with apps_and_link as (
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
    )
    select
      name as resource,
      case
        when (linker_username <> owner_username) then 'alarm'
        else 'ok'
      end as status,
      'Le code de l''application ' || name || ' dont le owner est ' || owner_username || ' est lié via le compte  : ' || linker_username || '.' AS reason
    from
      apps_and_link
    where
      linker_username is not null;
  EOT
}

control "scalingo_no_linked_repository_on_production" {
  title    = "Aucun repository n'est lié à une application de production."
  severity = "critical"
  sql      =  <<-EOT
    with apps_and_link as (
      select
        name,
        owner_username,
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
        app.name LIKE '%-production'
    )
    select
      name as resource,
      case
        when (name = any($1)) then 'skip'
        when link is null then 'ok'
        else 'alarm'
      end as status,
      case
        when link is null then 'L''application ' || name || ' n''est pas liée à un repository.'
        else  'L''application ' || name || ' est liée au repository '|| link || '.'
      end as reason
    from
      apps_and_link
  EOT

  param "exclusion" {
    default = var.linked_repository_exclusion
  }
}

control "scalingo_no_deploy_review_apps" {
  title    = "Le déploiement des review-apps automatique doit être désactivé."
  severity = "critical"
  sql      =  <<-EOT
    with apps_and_link as (
      select
        name,
        owner_username,
        (
          select
            deploy_review_apps_enabled
          from
            scalingo_scm_repo_link
          where
            app_name = name
        ) as deploy_review_apps_enabled
      from
        scalingo_app app
      where
        name NOT LIKE '%review-pr%'
    )
    select
      name as resource,
      case
        when (name = any($1) or deploy_review_apps_enabled is null) then 'skip'
        when not deploy_review_apps_enabled then 'ok'
        else 'alarm'
      end as status,
      case
        when deploy_review_apps_enabled then 'L''application ' || name || ' a le déploiement des review apps activé.'
        else 'L''application ' || name || ' n''a pas le déploiement des review apps activé.'
      end as reason
    from
      apps_and_link
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
      app.name LIKE '%-production' and
      addon.provider_id != 'tcp-gateway'
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


control "scalingo_database_not_reachable_on_internet" {
  title    = "Les bases de données ne sont pas accessibles sur l'internet."
  severity = "critical"
  sql      =  <<-EOT
    with apps_and_addons as (
      select
        ad.id as id,
        ad.app_name as app_name
      from
        scalingo_app app
      join
        scalingo_addon ad
      on
        ad.app_name = app.name
      order by
         id
    )

    select
      db.app_name as resource,
      case
        when concat(db.app_name, '_', db.type_name) = any($1) then 'skip'
        when db.publicly_available then 'alarm'
        else 'ok'
      end as status,
      case
        when db.publicly_available then 'L''application ' || db.app_name || ' a la base ' || db.type_name || ' accessible sur internet.'
        else 'L''application ' || db.app_name || ' a la base ' || db.type_name || ' accessible uniquement depuis scalingo.'
      end as reason
    from
      scalingo_database db
    inner join
      apps_and_addons ad
    on
      ad.id = db.addon_id and ad.app_name = db.app_name
  EOT

  param "exclusion" {
    default = var.database_reachable_exclusion
  }
}
