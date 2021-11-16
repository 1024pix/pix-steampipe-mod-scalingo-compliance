benchmark "scalingo" {
  title    = "Scalingo"
  children = [
    control.scalingo_app_name_start_with_pix,
    control.scalingo_app_name_end_with_type,
    control.scalingo_app_owner_must_be_pix,
    control.scalingo_router_logs_are_activated_on_production
  ]
}

control "scalingo_app_name_start_with_pix" {
  title    = "Le nom de l'application Scalingo commence par pix-"
  severity = "medium"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when starts_with(name, 'pix-') then 'ok'
        else 'alarm'
      end as status,
      case
        when starts_with(name, 'pix-') then 'L''aplication ' || name || ' commence par pix-'
        else  'L''application ' || name || ' ne commence pas par pix-.'
      end as reason
    from
      scalingo_app
  EOT
}

control "scalingo_app_name_end_with_type" {
  title    = "Le nom de l'application Scalingo finis par son type."
  severity = "medium"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name SIMILAR TO '%-(production|review|integration|recette|sandbox|preview|pr[0-9]+)' then 'ok'
        else 'alarm'
      end as status,
      case
        when name SIMILAR TO '%-(production|review|integration|recette|sandbox|preview|pr[0-9]+)' then 'L''aplication ' || name || ' finit par production/review/integration/recette/sandbox/preview/pr'
        else  'L''application ' || name || ' ne finit pas par -production/review/integration/recette/sandbox/preview/pr.'
      end as reason
    from
      scalingo_app
  EOT
}

control "scalingo_app_owner_must_be_pix" {
  title    = "Le propriétaire de l'application doit être pix-dev ou pix-prod."
  severity = "critical"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when owner_username IN ('pix-dev', 'pix-prod') then 'ok'
        else 'alarm'
      end as status,
      case
        when owner_username NOT IN ('pix-dev', 'pix-prod') then 'L''aplication ' || name || ' n''a pas le bon propriétaire ' || owner_username || '.'
        else  'L''application ' || name || ' appartient bien a ' || owner_username || '.'
      end as reason
    from
      scalingo_app
  EOT
}

control "scalingo_router_logs_are_activated_on_production" {
  title    = "Les logs routeur sont activé en production."
  severity = "high"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name NOT LIKE '%-production' then 'skip'
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
}
