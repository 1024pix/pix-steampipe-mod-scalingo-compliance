# Pix & Scalingo compliance

Ceci est un benchmark [Steampipe][] pour vérifier le respect de quelques règles pour nos applications hébergées par [Scalingo][].

## Installation

### Steampipe
https://steampipe.io/downloads


### Plugin scalingo

Installer 
```shell
steampipe plugin install francois2metz/scalingo
```

Configurer en ajoutant le `aggregator connection` 
https://hub.steampipe.io/plugins/francois2metz/scalingo#multi-account-connections

```shell
vi ~/.steampipe/config/scalingo.spc
``` 

### Repo
Cloner ce repo: 
```shell
git clone git@github.com:1024pix/pix-steampipe-mod-scalingo-compliance.git
```

Configurer le plugin
```shell
❯ cat ~/.steampipe/config/scalingo.spc
connection "scalingo" {
plugin = "francois2metz/scalingo"

    # API token for your scalingo instance (required).
    # Get it on: https://dashboard.scalingo.com/account/tokens
    token = "<TOKEN>" 

    # Regions
    # By default the scalingo plugin will only use the osc-fr1 region
    regions = ["osc-fr1", "osc-secnum-fr1"]
}
``` 


## Exécution

Lancer la commande
`steampipe check benchmark.scalingo`

## Développement

### Client local
Pour utiliser votre IDE favori
```shell
steampipe service start --foreground --show-password
```
Vous obtenez
```shell
  Connection string:  postgres://steampipe:ece6_47e2_a473@localhost:9193/steampipe
```

### Exécution brève
Pour ne voir que les erreurs
```shell
steampipe check --output=brief benchmark.scalingo
```

### Exclusion
Pour exclure certaines applications 

Exemple:
- logs routeurs:
- applications `pix-app` et `pix-app2`
- 
```shell
steampipe check benchmark.scalingo --var='router_logs_exclusion=["pix-app", "pix-app2"]'
```

### Exécuter un seul control
Pour n'exécuter qu'un seul control
```shell
steampipe query
> control.scalingo_no_linked_repository_on_production
```

[steampipe]: https://steampipe.io/
[scalingo]: https://scalingo.com/
