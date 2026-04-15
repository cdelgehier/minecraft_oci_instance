# Serveur Minecraft sur OCI — Gratuit pour toujours

Ce projet déploie un serveur Minecraft **Paper** sur Oracle Cloud Infrastructure (OCI) **Always Free tier** — 4 CPU ARM, 24 GB RAM, 200 GB de stockage, **zéro centime par mois**.

L'infrastructure est entièrement automatisée :
- **Packer** construit une image VM pré-configurée (Java 21, Paper MC, backups, monitoring)
- **OpenTofu** (alternative open-source à Terraform) déploie et gère l'infra OCI
- **Restic** sauvegarde le monde toutes les 6 heures dans OCI Object Storage
- **Tailscale** sécurise l'accès SSH sans exposer le port 22 à Internet

---

## Ce que tu vas obtenir

- Serveur Minecraft Paper 1.21.x sur VM ARM 4 vCPU / 24 GB RAM
- IP publique fixe (ne change pas même après un redéploiement)
- Sauvegardes automatiques toutes les 6h (rétention 7 jours / 4 semaines / 3 mois)
- Accès SSH sécurisé via Tailscale
- Volume monde indépendant de la VM (recréer la VM ne détruit pas le monde)

---

## Prérequis

### 1. Créer un compte OCI

1. Va sur [oracle.com/cloud/free](https://www.oracle.com/cloud/free/) → **Start for Free**
2. Remplis nom, pays, email valide
3. **Choisis ta home region avec soin — c'est irréversible** (voir ci-dessous)
4. Saisis une vraie carte bancaire (pas prépayée, pas virtuelle) — Oracle ne débite pas en Always Free
5. Confirme ton email

> **Dès ta première connexion à la console OCI**, crée une alerte budget :
> Console → hamburger → **Billing & Cost Management** → **Budgets** → Create
> Montant : **$1/mois**, alerte à **100%** → c'est ton filet de sécurité.

#### Choix de la région — attention

Les instances ARM A1.Flex sont souvent saturées dans les régions populaires.

| Bonne disponibilité | À éviter (saturées) |
|---|---|
| `us-phoenix-1` (US West Phoenix) | `eu-frankfurt-1` |
| `us-sanjose-1` (US West San Jose) | `ap-tokyo-1` |
| `eu-marseille-1` (France South) | `sa-saopaulo-1` |
| `eu-stockholm-1` (Sweden Central) | `us-ashburn-1` |
| `ap-sydney-1` (Australia) | `eu-paris-1` |

> Pour un serveur en Europe avec des amis français : `eu-marseille-1` ou `eu-stockholm-1`.

#### Si tu tombes sur "Out of Capacity"

OCI libère des ressources A1.Flex régulièrement — réessaie avec ce script :

```bash
# Adapte le compartment_ocid et l'availability-domain à ta config
while true; do
  STATUS=$(oci compute compute-capacity-report create \
    --compartment-id $(grep compartment_ocid tofu/terraform.tfvars | awk -F'"' '{print $2}') \
    --availability-domain "VOGK:EU-MARSEILLE-1-AD-1" \
    --shape-availabilities '[{"instanceShape":"VM.Standard.A1.Flex","instanceShapeConfig":{"ocpus":4,"memoryInGBs":24}}]' \
    --query 'data."shape-availabilities"[0]."availability-status"' --raw-output 2>/dev/null)
  echo "$(date): $STATUS"
  [ "$STATUS" = "AVAILABLE" ] && break
  sleep 600   # réessaie toutes les 10 minutes
done
```

### 2. Installer les outils

| Outil | Version | Installation (macOS) |
|---|---|---|
| [OpenTofu](https://opentofu.org/docs/intro/install/) | ≥ 1.10 | `brew install opentofu` |
| [Packer](https://developer.hashicorp.com/packer/install) | ≥ 1.11 | `brew install packer` |
| [go-task](https://taskfile.dev/installation/) | ≥ 3 | `brew install go-task` |
| [OCI CLI](https://docs.oracle.com/fr-fr/iaas/Content/API/SDKDocs/cliinstall.htm) | ≥ 3 | `brew install oci-cli` |
| [jq](https://jqlang.github.io/jq/) | ≥ 1.6 | `brew install jq` |
| [Tailscale](https://tailscale.com/download) | latest | `brew install tailscale` |

> Sur Linux (Ubuntu/Debian) : remplace `brew install X` par les instructions officielles de chaque outil.

---

## Installation pas à pas

### Étape 1 — Cloner le projet

```bash
git clone https://github.com/<ton-user>/minecraft_oci_instance.git
cd minecraft_oci_instance
task setup   # installe les pre-commit hooks
```

### Étape 2 — Configurer OCI CLI

```bash
oci setup config
# Réponds aux questions :
#   - region : eu-marseille-1 (ou ta région)
#   - génère une clé RSA → enregistre dans ~/.oci/
```

Ensuite ajoute la clé publique dans la console OCI :
**Identity & Security** → **Users** → ton utilisateur → **API Keys** → **Add API Key** → colle le contenu de `~/.oci/oci_api_key_public.pem`

Vérifie que l'auth fonctionne :
```bash
oci iam region list --output table
```

### Étape 3 — Créer le réseau OCI (une seule fois)

Le réseau est créé avant Packer car la VM de build a besoin d'un subnet. Note les OCIDs retournés.

```bash
# Récupère ton tenancy OCID (visible dans la console OCI → hamburger → Tenancy)
TENANCY_ID="ocid1.tenancy.oc1..aaaa..."

# 1. Compartiment
COMPARTMENT_ID=$(oci iam compartment create \
  --compartment-id $TENANCY_ID \
  --name minecraft \
  --description "Minecraft server resources" \
  --query 'data.id' --raw-output)

# 2. VCN
VCN_ID=$(oci network vcn create \
  --compartment-id $COMPARTMENT_ID \
  --cidr-block "10.0.0.0/16" \
  --display-name "minecraft-vcn" \
  --dns-label "minecraftvcn" \
  --query 'data.id' --raw-output)

# 3. Internet Gateway
IGW_ID=$(oci network internet-gateway create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --display-name "minecraft-igw" \
  --is-enabled true \
  --query 'data.id' --raw-output)

# 4. Route par défaut → IGW
RT_ID=$(oci network route-table list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' --raw-output)
oci network route-table update --rt-id $RT_ID --force \
  --route-rules "[{\"cidrBlock\":\"0.0.0.0/0\",\"networkEntityId\":\"$IGW_ID\"}]"

# 5. Security list (ouvre SSH + Minecraft)
SL_ID=$(oci network security-list list \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --query 'data[0].id' --raw-output)
oci network security-list update --security-list-id $SL_ID --force \
  --ingress-security-rules '[
    {"protocol":"6","source":"0.0.0.0/0","tcpOptions":{"destinationPortRange":{"min":22,"max":22}},"isStateless":false,"description":"SSH"},
    {"protocol":"6","source":"0.0.0.0/0","tcpOptions":{"destinationPortRange":{"min":25565,"max":25565}},"isStateless":false,"description":"Minecraft Java"},
    {"protocol":"1","source":"0.0.0.0/0","icmpOptions":{"type":3,"code":4},"isStateless":false,"description":"ICMP Path MTU"}
  ]' \
  --egress-security-rules '[{"protocol":"all","destination":"0.0.0.0/0","isStateless":false}]'

# 6. Subnet public (adapte --availability-domain à ta région)
SUBNET_ID=$(oci network subnet create \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID \
  --cidr-block "10.0.0.0/24" \
  --display-name "minecraft-subnet-public" \
  --dns-label "public" \
  --availability-domain "VOGK:EU-MARSEILLE-1-AD-1" \
  --prohibit-public-ip-on-vnic false \
  --query 'data.id' --raw-output)

echo "COMPARTMENT_ID = $COMPARTMENT_ID"
echo "SUBNET_ID      = $SUBNET_ID"
```

> Pour trouver l'identifiant de ton availability domain :
> `oci iam availability-domain list --query 'data[*].name' --output table`

### Étape 4 — Générer une clé SSH

```bash
ssh-keygen -t ed25519 -C "minecraft-oci" -f ~/.ssh/minecraft_oci
# La clé publique sera dans ~/.ssh/minecraft_oci.pub
```

### Étape 5 — Créer le bucket de state OpenTofu

```bash
# Remplace $COMPARTMENT_ID par la valeur de l'étape 3
oci os bucket create \
  --compartment-id $COMPARTMENT_ID \
  --name minecraft-tofu-state \
  --versioning Enabled

# Récupère le namespace (tu en auras besoin pour backend.tf)
oci os ns get --query 'data' --raw-output
# → exemple : axsr3mx7ucse
```

Génère une **Customer Secret Key** (accès S3-compatible pour le backend) :
Console OCI → icône profil (haut à droite) → **My profile** → **Customer Secret Keys** → **Generate Secret Key**

Note l'Access Key ID et la Secret Key affichés (la Secret Key n'est visible qu'une seule fois).

### Étape 6 — Créer une auth key Tailscale

1. Va sur [admin.tailscale.com](https://admin.tailscale.com) → **Settings** → **Keys**
2. **Generate auth key** — coche **Reusable** et **Ephemeral**
3. Note la clé : `tskey-auth-XXXX-XXXX`

### Étape 7 — Configurer les paramètres Packer

Édite `packer/minecraft.pkrvars.hcl` et remplace les OCIDs par les tiens :

```hcl
region              = "eu-marseille-1"   # ta région
availability_domain = "VOGK:EU-MARSEILLE-1-AD-1"   # adapte à ta région

compartment_ocid = "<COMPARTMENT_ID de l'étape 3>"
subnet_ocid      = "<SUBNET_ID de l'étape 3>"
```

### Étape 8 — Configurer les secrets OpenTofu

```bash
cp tofu/secrets.tfvars.example tofu/secrets.tfvars
```

Édite `tofu/secrets.tfvars` :

```hcl
# Clé SSH publique (étape 4)
ssh_public_key = "ssh-ed25519 AAAA... minecraft-oci"

# Customer Secret Key OCI (étape 5)
s3_access_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
s3_secret_key = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Mot de passe RCON (choisis quelque chose de fort)
rcon_password = "UnMotDePasseFort!"

# Auth key Tailscale (étape 6)
tailscale_auth_key = "tskey-auth-XXXXXXXXXXXX-XXXXXXXXXXXX"

# Mot de passe du repo restic (note-le bien, tu en auras besoin pour restaurer)
restic_password = "UnAutreMotDePasseFort!"
```

Édite également `tofu/terraform.tfvars` avec tes OCIDs :

```hcl
compartment_ocid    = "<COMPARTMENT_ID>"
subnet_ocid         = "<SUBNET_ID>"
availability_domain = "VOGK:EU-MARSEILLE-1-AD-1"
# ...
```

### Étape 9 — Configurer le backend OpenTofu

Édite `tofu/backend.tf` avec ton namespace et ta région (récupérés à l'étape 5) :

```hcl
backend "s3" {
  bucket   = "minecraft-tofu-state"
  key      = "terraform.tfstate"
  region   = "eu-marseille-1"
  endpoint = "https://<NAMESPACE>.compat.objectstorage.<REGION>.oraclecloud.com"
  # exemple : https://axsr3mx7ucse.compat.objectstorage.eu-marseille-1.oraclecloud.com

  skip_region_validation      = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  force_path_style            = true
}
```

```bash
task tofu:init-remote
```

### Étape 10 — Construire l'image Packer

Packer crée une image VM OCI avec tout pré-installé : Java 21 Temurin, Paper MC, node_exporter, Tailscale, restic, fail2ban, UFW.

```bash
task packer:validate   # vérifie le template (~30 secondes)
task packer:build      # ~15-20 minutes → génère packer/manifest.json
```

> Packer crée une VM temporaire, y installe tout via Ansible, fait un snapshot, puis détruit la VM. À la fin tu as une image réutilisable dans OCI.

### Étape 11 — Déployer le serveur

```bash
# Récupère l'OCID de l'image construite
IMAGE_OCID=$(jq -r '.builds[-1].artifact_id' packer/manifest.json)

# Affiche le plan (sans rien modifier)
IMAGE_OCID=$IMAGE_OCID task tofu:plan

# Déploie !
IMAGE_OCID=$IMAGE_OCID task tofu:apply

# Affiche l'IP et la commande SSH
task tofu:output
```

L'output ressemble à :
```
instance_public_ip = "82.70.234.197"
minecraft_connect  = "82.70.234.197:25565"
ssh_command        = "ssh -i ~/.ssh/minecraft_oci ubuntu@82.70.234.197"
```

### Étape 12 — Attendre le démarrage complet

Le premier boot prend 3-5 minutes (montage du volume, init restic, démarrage des services).

```bash
# Attendre la fin du cloud-init
ssh -i ~/.ssh/minecraft_oci ubuntu@<IP> "sudo cloud-init status --wait && echo OK"

# Vérifier que Minecraft tourne
ssh -i ~/.ssh/minecraft_oci ubuntu@<IP> "sudo systemctl status minecraft --no-pager"
```

---

## Se connecter à Minecraft

Dans le **launcher Minecraft Java Edition** :

1. **Multiplayer** → **Add Server**
2. Server Address : `<IP_publique>:25565`
3. **Join Server**

> Via Tailscale (si tu es dans le même réseau Tailscale que le serveur) : utilise l'adresse `minecraft-oci`.

---

## Opérations courantes

### Statut du serveur

```bash
ssh ubuntu@<IP> "sudo systemctl status minecraft --no-pager"
```

### Voir les logs en direct

```bash
ssh ubuntu@<IP> "sudo journalctl -u minecraft -n 100 -f"
```

### Redémarrer le serveur

```bash
ssh ubuntu@<IP> "sudo systemctl restart minecraft"
```

### Console RCON — envoyer des commandes Minecraft

```bash
ssh ubuntu@<IP> "sudo rcon-cli --host localhost --port 25575 --password '<rcon_password>'"
```

Commandes utiles depuis la console RCON :
```
list                          # joueurs connectés
whitelist add NomDuJoueur     # ajouter à la whitelist
whitelist remove NomDuJoueur  # retirer de la whitelist
op NomDuJoueur                # donner les droits opérateur
deop NomDuJoueur              # retirer les droits opérateur
gamemode creative NomDuJoueur # changer le mode de jeu
time set day                  # passer le temps à jour
weather clear                 # météo claire
say Bonjour tout le monde     # message dans le chat
stop                          # arrêt propre du serveur
```

### Modifier server.properties

```bash
ssh ubuntu@<IP> "sudo nano /opt/minecraft/server/server.properties"
ssh ubuntu@<IP> "sudo systemctl restart minecraft"
```

Paramètres utiles :
```properties
difficulty=normal            # peaceful, easy, normal, hard
max-players=20               # nombre max de joueurs simultanés
view-distance=10             # distance de rendu (réduis si lag)
pvp=true                     # combat joueur vs joueur
online-mode=true             # false = comptes non-officiels acceptés
white-list=false             # true = whitelist activée (joueurs autorisés uniquement)
motd=Mon Serveur Minecraft   # texte affiché dans la liste de serveurs
```

---

## Sauvegardes

Les sauvegardes sont automatiques — le monde est sauvegardé toutes les 6 heures dans OCI Object Storage.

### Voir les snapshots disponibles

```bash
ssh ubuntu@<IP> "sudo bash -c 'set -a && . /etc/minecraft/backup.env && set +a && restic snapshots'"
```

### Déclencher une sauvegarde manuelle

```bash
ssh ubuntu@<IP> "sudo systemctl start minecraft-backup.service && sudo journalctl -u minecraft-backup -f"
```

### Restaurer un snapshot

```bash
# 1. Lister les snapshots
ssh ubuntu@<IP> "sudo bash -c 'set -a && . /etc/minecraft/backup.env && set +a && restic snapshots'"

# 2. Arrêter le serveur
ssh ubuntu@<IP> "sudo systemctl stop minecraft"

# 3. Restaurer (remplace <SNAPSHOT_ID> par l'ID du snapshot voulu, ex: f00d753a)
ssh ubuntu@<IP> "sudo bash -c 'set -a && . /etc/minecraft/backup.env && set +a && \
  restic restore <SNAPSHOT_ID> --target / --include /opt/minecraft/server'"

# 4. Redémarrer
ssh ubuntu@<IP> "sudo systemctl start minecraft"
```

---

## Mettre à jour Paper MC

```bash
# Depuis ta machine locale
NEW_VERSION="1.21.4"
ssh ubuntu@<IP> "sudo bash -c '
  BUILD=\$(curl -s \"https://api.papermc.io/v2/projects/paper/versions/$NEW_VERSION\" | jq -r \".builds[-1]\")
  curl -fL \"https://api.papermc.io/v2/projects/paper/versions/$NEW_VERSION/builds/\$BUILD/downloads/paper-$NEW_VERSION-\$BUILD.jar\" \
    -o /opt/minecraft/server/paper.jar
  chown minecraft:minecraft /opt/minecraft/server/paper.jar
  systemctl restart minecraft
'"
```

---

## Recréer la VM (monde préservé)

Le volume bloc contenant le monde est protégé par `prevent_destroy = true` dans OpenTofu.
Détruire et recréer la VM ne supprime **pas** le monde.

```bash
# Construire une nouvelle image si besoin
task packer:build

# Redéployer (réutilise le volume monde existant)
IMAGE_OCID=$(jq -r '.builds[-1].artifact_id' packer/manifest.json) task tofu:apply
```

> Pour vraiment tout supprimer (monde compris), mets d'abord `prevent_destroy = false` dans
> `tofu/modules/storage/main.tf`, puis `task tofu:destroy`.

---

## Résolution de problèmes

### Le serveur ne démarre pas après le premier boot

```bash
# Voir les logs cloud-init (initialisation au premier démarrage)
ssh ubuntu@<IP> "sudo cat /var/log/cloud-init-output.log | tail -50"
# Voir les logs systemd
ssh ubuntu@<IP> "sudo journalctl -u minecraft -n 50"
```

### Le volume monde n'est pas monté

```bash
ssh ubuntu@<IP> "lsblk"          # vérifie si /dev/sdb est présent
ssh ubuntu@<IP> "sudo mount -a"  # monte les volumes du fstab
ssh ubuntu@<IP> "df -h /opt/minecraft/server"
```

### Whitelist activée et personne ne peut se connecter

```bash
ssh ubuntu@<IP> "sudo rcon-cli --host localhost --port 25575 --password '<pass>' 'whitelist off'"
```

### Vérifier les sauvegardes

```bash
ssh ubuntu@<IP> "sudo journalctl -u minecraft-backup -n 30"
ssh ubuntu@<IP> "sudo systemctl status minecraft-backup.timer"
```

---

## Structure du projet

```
minecraft_oci_instance/
├── packer/                         # Construction de l'image VM OCI
│   ├── minecraft.pkr.hcl           # Template Packer principal
│   ├── minecraft.pkrvars.hcl       # Paramètres (région, OCIDs, version MC...)
│   └── files/
│       ├── minecraft_install.yml   # Playbook Ansible (Java, Paper, services...)
│       └── server.properties       # Config Minecraft par défaut
├── tofu/                           # Infrastructure as Code
│   ├── modules/
│   │   ├── compute/                # VM A1.Flex + IP fixe + cloud-init
│   │   └── storage/                # Volume monde + bucket backups
│   ├── terraform.tfvars            # Paramètres non-secrets
│   ├── secrets.tfvars              # Secrets (gitignored — ne jamais commiter)
│   └── secrets.tfvars.example      # Modèle à copier pour créer secrets.tfvars
└── Taskfile.yml                    # Toutes les commandes disponibles
```

---

## Commandes disponibles

```bash
task --list              # voir toutes les commandes disponibles

task packer:validate     # valider le template Packer
task packer:build        # construire l'image OCI (~15 min)

task tofu:init-remote    # initialiser avec backend OCI Object Storage
task tofu:validate       # valider la configuration
task tofu:plan           # voir les changements sans les appliquer
task tofu:apply          # déployer l'infrastructure
task tofu:output         # afficher l'IP et la commande SSH
task tofu:destroy        # tout supprimer (confirmation interactive)

task lint                # vérifier la qualité du code
task fmt                 # formater les fichiers HCL
```

---

## Coût estimé

| Ressource | Limite Always Free | Usage |
|---|---|---|
| Instance A1.Flex 4 OCPU / 24 GB | 4 OCPU + 24 GB inclus | **0 €/mois** |
| Block volume monde (100 GB) | 200 GB total inclus | **0 €/mois** |
| Object Storage backups | 20 GB inclus | **0 €/mois** |
| Outbound transfer | 10 GB/mois inclus | **0 €/mois** |
| **Total** | | **0 €/mois** |

> Configure l'alerte budget $1/mois dans la console OCI dès le début — c'est gratuit et ça te prévient immédiatement si tu dépasses les limites Always Free.
