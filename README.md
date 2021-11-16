# Pix & Scalingo compliance

Ceci est un benchmark [Steampipe][] pour vérifier le respect de quelques règles pour nos applications hébergées par [Scalingo][].

Pour jouer ces règles:
1. Installer [Steampipe][]
1. Installer et configurer le plugin scalingo: `steampipe plugin install francois2metz/scalingo`
1. Cloner ce dépot
1. Lancer la commande: `steampipe check benchmark.scalingo`

Pour exclure certaines applications de la vérification des logs routeurs:

    steampipe check benchmark.scalingo --var='router_logs_exclusion=["pix-app", "pix-app2"]'

[steampipe]: https://steampipe.io/
[scalingo]: https://scalingo.com/
