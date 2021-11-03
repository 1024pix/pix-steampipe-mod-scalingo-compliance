# Pix & Scalingo compliance

Ceci est un benchmark [Steampipe][] pour vérifier le respect de quelques rêgles pour nos applications hébergé par [Scalingo][].

Pour jouer ces rêgles:
1. Installer [Steampipe][]
1. Installer et configurer le plugin scalingo: `steampipe plugin install francois2metz/scalingo`
1. Cloner ce dépot
1. Lancer la commande: `steampipe check benchmark.scalingo`

[steampipe]: https://steampipe.io/
[scalingo]: https://scalingo.com/
