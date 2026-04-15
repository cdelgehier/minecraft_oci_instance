# Valeurs non-sensibles — les secrets sont dans secrets.tfvars (gitignored)
# Provider OCI : lit ~/.oci/config profil DEFAULT (pas de credentials ici)

# OCIDs publics (visibles dans la console OCI, pas des secrets)
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaatv47i5d4o5zjyqwolrmg2ayvar2zzcwt22esl6wbhv6fbqefdfsa"

region               = "eu-marseille-1"
availability_domain  = "VOGK:EU-MARSEILLE-1-AD-1"
instance_ocpus       = 4
instance_memory_gb   = 24
boot_volume_size_gb  = 50
world_volume_size_gb = 100

subnet_ocid = "ocid1.subnet.oc1.eu-marseille-1.aaaaaaaabpv6d2q4tuskekpvwadqzl75b4gz3s4gn6wfh5csigjlsmsjgosa"

# minecraft_image_ocid : passé via -var au moment du plan/apply
# IMAGE_OCID=$(jq -r '.builds[-1].artifact_id' packer/manifest.json) task tofu:plan
