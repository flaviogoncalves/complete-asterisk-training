```{=latex}
\frontmatter
```

## Copyright {.unnumbered}

*Asterisk Guide* — Deuxième édition (Asterisk 22 LTS)

Copyright © 2006–2026 Flavio E. Gonçalves. Tous droits réservés.

Aucune partie de ce livre ne peut être reproduite, stockée dans un système de recherche documentaire ou transmise sous quelque forme ou par quelque moyen que ce soit sans le consentement écrit préalable de l'auteur, à l'exception de brefs extraits utilisés dans des critiques publiées.

**Édition :** Deuxième édition.

> **[author TODO]** Attribuer un nouvel ISBN pour la 2e édition (ne pas réutiliser le 9781796396973 de la 1re édition) et définir la date de publication avant l'impression.

Bon nombre des désignations utilisées par les fabricants et les vendeurs pour distinguer leurs produits sont revendiquées comme des marques commerciales. Lorsque ces désignations apparaissent dans ce livre et que l'auteur était au courant d'une revendication de marque, elles ont été imprimées en majuscules ou avec une majuscule initiale. Asterisk, Digium, IAX et DUNDi sont des marques commerciales de Sangoma Technologies (Digium a été acquis par Sangoma en 2018 ; Asterisk est désormais sponsorisé par Sangoma).

Bien que toutes les précautions aient été prises lors de la préparation de ce livre, l'auteur n'assume aucune responsabilité pour les erreurs ou omissions, ni pour les dommages résultant de l'utilisation des informations contenues dans le présent document.

## Préface {.unnumbered}

Ce livre est destiné à toute personne souhaitant apprendre à installer et configurer un PBX (Private Branch Exchange) basé sur Asterisk 22 LTS. Asterisk est une plateforme de téléphonie open source qui fait le pont entre la VoIP et les canaux TDM traditionnels.

Il s'agit de la cinquième génération d'un ouvrage qui a vu le jour sous le nom de *Asterisk Configuration Guide*. Le contenu est issu du travail que j'ai effectué pour préparer la certification Digium dCAP en 2006 — que j'ai obtenue dès la première tentative — et il a été enseigné à plus d'un millier d'étudiants depuis.

Le concept de PBX open source est révolutionnaire. Pendant des décennies, la téléphonie a été dominée par une poignée d'entreprises vendant des systèmes propriétaires coûteux. Asterisk a redonné ce pouvoir aux utilisateurs : des fonctionnalités autrefois économiquement inaccessibles — CTI (computer-telephony integration), IVR (interactive voice response), ACD (automatic call distribution), voicemail, et bien plus encore — sont désormais disponibles pour quiconque dispose d'une machine Linux et de la volonté d'apprendre.

Ce livre ne fera pas de vous un gourou par lui-même — aucun livre ne le peut — mais à la fin de votre lecture, vous serez capable de construire et d'exploiter un véritable PBX doté de fonctionnalités avancées. Le livre dispose d'un complément — des travaux pratiques et un cours en ligne — sur **VoIP School Blackbelt** (<https://voip.school>).

## Audience {.unnumbered}

Ce livre est destiné aux lecteurs qui découvrent Asterisk. Je suppose que vous êtes à l'aise avec Linux — le shell, un éditeur de texte et l'administration système de base. Vous pouvez suivre les exercices sur un poste de travail Linux si cela est plus simple pour l'apprentissage, et une machine virtuelle convient parfaitement pour les laboratoires (attendez-vous à une qualité vocale légèrement inférieure). Pour les systèmes en production, je ne recommande pas d'exécuter Asterisk dans un environnement de bureau ou au sein d'une VM aux ressources limitées. Une certaine familiarité avec les réseaux IP, la Voice over IP (VoIP) et les concepts de téléphonie de base sera utile.

## Quoi de neuf dans la deuxième édition {.unnumbered}

La deuxième édition est une modernisation complète pour **Asterisk 22 LTS** (publiée en 2024,
prise en charge jusqu'en octobre 2028). Les changements majeurs :

- **PJSIP est le seul canal SIP.** `chan_sip` a été supprimé dans Asterisk 21 et n'existe
  pas dans la version 22. Chaque exemple SIP utilise désormais PJSIP (`pjsip.conf`) ; le contenu
  hérité de `sip.conf` est conservé uniquement comme référence de migration.
- **Direction de Sangoma.** Digium a été acquis par Sangoma en 2018 ; le projet est désormais
  développé et sponsorisé par Sangoma, et le texte reflète cela tout au long de l'ouvrage.
- **Trois nouveaux chapitres.** *WebRTC with Asterisk* (téléphones par navigateur via WSS/DTLS-SRTP),
  *SIP trunking, DID & the PSTN*, et *Deployment, monitoring & scaling*.
- **Un laboratoire reproductible.** Chaque configuration et commande du livre est vérifiée
  par rapport à un laboratoire Docker Asterisk 22 que vous pouvez exécuter vous-même.
- **Fonctionnalités modernisées.** ConfBridge remplace l'ancienne conférence MeetMe, ARI est
  introduit aux côtés de AMI/AGI, PJSIP Realtime (Sorcery) est couvert, et les chapitres sur
  l'installation, la sécurité et les CDR ont été mis à jour.
- **Une nouvelle structure.** Le livre est désormais organisé en quatre parties — Foundations,
  Channels & Connectivity, Dialplan & Call Features, et Integration & Operations.

## À propos de l'auteur {.unnumbered}

Flavio E. Gonçalves est né en 1966 au Brésil. Il porte un vif intérêt à
l'informatique depuis l'obtention de son premier PC en 1983, et a obtenu un diplôme d'ingénieur en 1989
avec une spécialisation en conception et fabrication assistées par ordinateur. Il est le PDG de SipPulse au
Brésil, une entreprise dédiée aux SoftSwitch, SBC et aux PBX multi-locataires.

Au cours de sa carrière, il a obtenu une longue liste de certifications — Novell MCNE/MCNI, Microsoft
MCSE/MCT, Cisco CCSP/CCNP/CCDP, et Asterisk dCAP parmi celles-ci. Il a commencé à écrire sur les logiciels open source car il pense que la méthode structurée avec laquelle les certifications enseignaient autrefois leur contenu est un excellent moyen d'apprendre, et il s'est appuyé sur plus de 25 ans d'expérience dans l'enseignement pour écrire en tenant compte de la manière dont les gens apprennent réellement, plutôt que d'un point de vue purement technique.

Flavio est père de deux enfants et vit à Florianópolis, au Brésil — l'un des plus
beaux endroits au monde — où il passe son temps libre à faire du surf et de la voile.

## Feedback, crédits et formation {.unnumbered}

Je m'efforce de trouver et d'éliminer les erreurs, mais certaines passent toujours entre les mailles du filet. Si vous trouvez quelque chose d'incorrect, veuillez m'en informer et j'agirai en conséquence.

Ce livre est également utilisé comme support de formation. Si vous souhaitez l'utiliser dans votre propre centre de formation, ou suivre le cours en ligne et les travaux pratiques associés, visitez **VoIP School Blackbelt** sur <https://voip.school> ou envoyez un e-mail à <flavio@voip.school>.

**Crédits.** Conception de la couverture : Karla Braga. Relecteurs : Luis F. Gonçalves, Guilherme Goes (dCAP) et des correcteurs professionnels. Mes remerciements vont également aux nombreux étudiants dont les retours au fil des années ont façonné ce matériel, ainsi qu'à ma famille pour son soutien.

```{=latex}
\cleardoublepage
```
