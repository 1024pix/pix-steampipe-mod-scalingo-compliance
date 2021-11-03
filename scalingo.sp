benchmark "scalingo" {
  title    = "Scalingo"
  children = [
    control.scalingo_app_name_start_with_pix,
    control.scalingo_app_name_end_with_type
  ]
}

control "scalingo_app_name_start_with_pix" {
  title    = "Le nom des applications Scalingo commencent par pix-"
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
  title    = "Le nom des applications Scalingo finissent par leur type."
  severity = "medium"
  sql      =  <<-EOT
    select
      name as resource,
      case
        when name SIMILAR TO '%-(production|review|integration|recette|sandbox|preview|pr[0-9]+)' then 'ok'
        else 'alarm'
      end as status,
      case
        when  name SIMILAR TO '%-(production|review|integration|recette|sandbox|preview|pr[0-9]+)' then 'L''aplication ' || name || ' finit par production/review/integration/recette/sandbox/preview/pr'
        else  'L''application ' || name || ' ne finit pas par -production/review/integration/recette/sandbox/preview/pr.'
      end as reason
    from
      scalingo_app
  EOT
}
