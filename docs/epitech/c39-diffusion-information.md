# C39 - Diffusion des informations dans l'equipe

## Competence visee

Diffuser les informations au sein de l'equipe avec les moyens mis a disposition
par l'entreprise, en respectant la politique de securite du client, afin que
chaque membre comprenne ses missions, y compris en cas de besoins particuliers
lies a une situation de handicap.

## Contexte Elyrii

Elyrii est un projet de fin d'etudes Epitech realise par une equipe etudiante
multidisciplinaire. Le projet combine une application mobile Flutter, un backend
TypeScript/Hono, un module IA et une documentation technique MkDocs.

Les canaux principaux de diffusion etaient :

- Discord, pour les reunions, les echanges en temps reel, les points de
  synchronisation et les decisions rapides.
- GitHub Issues, pour formaliser le backlog, les bugs et les taches.
- GitHub Pull Requests, pour partager les changements, demander des retours,
  tracer les validations et centraliser les remarques techniques.
- Documentation MkDocs/README, pour garder les informations stables :
  architecture, installation, CI/CD, choix techniques et limites connues.

## Organisation de la diffusion

### Discord

Discord a ete utilise comme canal de coordination quotidien :

- reunions vocales ou distancielles ;
- messages ecrits pour les decisions importantes ;
- partage de liens vers les issues, PR, branches et builds ;
- repartition rapide des sujets entre mobile, backend, IA, integration et
  documentation ;
- recaps apres reunion pour garder une trace lisible par les absents.

A completer avec les captures :

- nom des salons utilises : `#...`, `#...`, `#...` ;
- rythme des reunions : hebdomadaire, bi-hebdomadaire, avant les jalons, etc. ;
- exemple de recap avec decisions, responsables et echeances ;
- exemple de message urgent ou de synchronisation en temps reel.

### GitHub

GitHub servait de trace durable et verifiable. Les issues decrivaient les
missions ou incidents, puis les PR diffusaient la solution proposee a l'equipe.

Elements observables au 2 juillet 2026 :

- depot public `elyrii-epitech/Elyrii` ;
- environ 98 pull requests et 112 issues referencees par GitHub Search ;
- branches `main` et `dev` visibles comme protegees via l'API des branches ;
- workflow de developpement documente : GitFlow, lint, tests, commits
  conventionnels, PR avec reviewers et CI ;
- CI GitHub Actions pour mobile, backend, IA et documentation.

Exemples de PR exploitables :

| Preuve | Ce que cela montre pour C39 |
| --- | --- |
| [PR #210](https://github.com/elyrii-epitech/Elyrii/pull/210) - merge frontend integration | Description detaillee, changements par domaine, checklist, tests manuels, absence de secrets dans le diff. |
| [PR #206](https://github.com/elyrii-epitech/Elyrii/pull/206) - polish frontend mascot customization | Diffusion d'un lot fonctionnel avec validation locale et CI mobile. |
| [PR #139](https://github.com/elyrii-epitech/Elyrii/pull/139) - mobile documentation and CI/CD | Mise a jour de la documentation et des workflows pour partager les procedures de build/test. |
| [PR #118](https://github.com/elyrii-epitech/Elyrii/pull/118) - documentation, CI et outils locaux | Ajout README, docs IA/backend, Docker Compose, workflows ; commentaire demandant que la CI/CD fonctionne. |
| [PR #211](https://github.com/elyrii-epitech/Elyrii/pull/211) - v2.0.0 | Remarques automatiques CodeQL/Codex sur securite, visibles dans la discussion PR. |

Exemples d'issues exploitables :

| Preuve | Ce que cela montre pour C39 |
| --- | --- |
| [#174](https://github.com/elyrii-epitech/Elyrii/issues/174) - Implement Mood Tracking Persistence | Mission fonctionnelle associee a une livraison concrete. |
| [#178](https://github.com/elyrii-epitech/Elyrii/issues/178) - integration tests login -> dashboard -> mood tracking | Diffusion d'une attente de validation transverse. |
| [#180](https://github.com/elyrii-epitech/Elyrii/issues/180) - connect Dashboard stats to /user/stats API | Clarification d'une mission frontend/backend. |
| [#196](https://github.com/elyrii-epitech/Elyrii/issues/196) - lora weight check | Suivi d'une tache IA ciblee. |
| [#198](https://github.com/elyrii-epitech/Elyrii/issues/198) - weight merging | Suivi d'une tache IA liee a la livraison du modele. |

### Documentation

La documentation complete les canaux synchrones :

- le README expose la vision projet, l'architecture, les commandes
  d'installation et le workflow de developpement ;
- `docs/mobile/ci-cd.md` documente les workflows Flutter, les commandes locales,
  les artefacts et les limites connues ;
- `mkdocs.yml` publie une documentation structuree avec navigation mobile,
  serveur et IA ;
- les workflows generent ou deploient la documentation mobile, backend et IA.

## Respect de la securite

Les informations diffusees ont ete encadrees par des regles de securite :

- pas de secrets, tokens, mots de passe ou donnees personnelles dans Discord,
  les issues ou les PR ;
- utilisation de GitHub Secrets pour les variables sensibles de CI/CD ;
- validation par PR et CI avant integration sur `dev` ou `main` ;
- branches `main` et `dev` protegees ;
- separation entre informations techniques partageables et donnees utilisateur
  sensibles, d'autant plus importante car Elyrii traite du bien-etre et de
  conversations personnelles ;
- captures d'ecran de soutenance a anonymiser si elles contiennent noms,
  emails, tokens, URLs internes ou discussions privees.

Preuves techniques dans le depot :

- README : workflow de developpement, PR avec reviewers et CI.
- `.github/workflows/backend-build.yml` : variables sensibles lues depuis
  `secrets.*`.
- `docs/mobile/architecture.md` : stockage securise des tokens et points de
  securite restants.
- PR #211 : alertes CodeQL/Codex discutees dans une PR ouverte.

## Prise en compte de besoins particuliers

Le fonctionnement Discord + GitHub + documentation permet de ne pas dependre
uniquement de l'oral :

- les decisions importantes sont reformulees a l'ecrit ;
- les taches restent consultables de maniere asynchrone dans GitHub ;
- les PR expliquent le contexte, les changements et les validations ;
- la documentation structuree permet a une personne absente, fatiguee ou ayant
  besoin de plus de temps de relire les consignes ;
- les supports ecrits peuvent etre lus par des outils d'assistance ;
- les consignes peuvent etre reprises avec des listes, titres courts et liens
  directs vers les PR/issues.

A completer selon la realite de l'equipe :

- une personne avait-elle un besoin particulier connu ?
- avez-vous active les sous-titres, enregistrements, compte-rendus ou un rythme
  asynchrone specifique ?
- avez-vous adapte les reunions : horaires, duree, pauses, support ecrit avant
  ou apres ?

S'il n'y avait pas de besoin particulier identifie, l'argument defensable est :
le dispositif etait inclusif par conception, car les informations essentielles
etaient disponibles a l'ecrit et de maniere asynchrone.

## Trame orale possible

Pour Elyrii, j'ai diffuse les informations de deux manieres complementaires.
D'abord, Discord servait au temps reel : reunions vocales, messages rapides,
partage de liens vers les PR et recap des decisions. Ensuite, GitHub servait de
trace officielle : les issues decrivaient les missions, les PR centralisaient les
changements, les tests, les validations et les retours.

Pour garantir la comprehension de l'equipe, je reformulais les decisions en
actions concretes : branche ou issue concernee, responsable, objectif attendu,
criteres de validation et lien vers la PR. Les informations durables etaient
ensuite consolidees dans le README et la documentation MkDocs, notamment les
procedures de CI/CD, l'architecture mobile, backend et IA.

La securite etait prise en compte en evitant de partager des secrets ou donnees
personnelles dans Discord/GitHub, en utilisant GitHub Secrets pour la CI, des PR
avec verification et des branches protegees. Comme Elyrii traite de sujets de
bien-etre et de conversations sensibles, j'ai veille a distinguer les donnees
techniques partageables des donnees utilisateur.

Enfin, le dispositif etait compatible avec des besoins particuliers : une
personne ne dependait pas uniquement de l'oral, car les decisions, taches et
validations etaient disponibles par ecrit dans Discord, GitHub et la
documentation. Cela permettait aussi aux absents ou aux personnes ayant besoin de
plus de temps de reprendre les informations apres la reunion.

## Captures et preuves a preparer

- Capture Discord de la liste des salons, avec noms des salons utiles.
- Capture d'un message d'annonce ou de preparation de reunion.
- Capture d'un compte-rendu de reunion avec decisions et taches.
- Capture d'un echange Discord qui renvoie vers une issue ou une PR GitHub.
- Capture d'une PR detaillee, idealement #210 ou #206.
- Capture d'une issue de mission, par exemple #174, #178 ou #180.
- Capture des checks CI GitHub Actions sur une PR.
- Capture de la protection des branches `main` et `dev`, si accessible.
- Capture d'une regle ou pratique securite : secrets, absence de credentials,
  message de rappel, ou PR avec checklist "pas de secrets".
- Capture d'un support ecrit accessible : README, documentation MkDocs ou recap.

## References verifiees dans le depot

- `README.md` : presentation du projet, stack, workflow de developpement,
  contribution et regle PR avec CI.
- `docs/mobile/ci-cd.md` : detail des workflows Flutter, commandes locales et
  artefacts.
- `docs/mobile/architecture.md` : stockage securise, points de securite et tests.
- `docs/ai/index.md` : considerations de confidentialite et limitation de
  conservation des conversations.
- `mkdocs.yml` : publication d'une documentation structuree et lien vers le repo
  GitHub.

## Questions restantes

1. Quels etaient les salons Discord exacts et leur usage ?
2. Quel etait le rythme reel des reunions ?
3. Est-ce que vous faisiez systematiquement un recap ecrit apres reunion ?
4. Quelle politique de securite etait explicitement appliquee par l'equipe ou le
   client/ecole ?
5. Une situation de handicap ou un besoin particulier a-t-il ete identifie dans
   l'equipe ?
6. Quelles captures peux-tu fournir sans exposer de secrets ni de donnees
   personnelles ?
