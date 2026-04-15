config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Les modules internes (non publiés) n'ont pas besoin de déclarer
# required_version / required_providers — c'est le module racine qui le fait.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}
