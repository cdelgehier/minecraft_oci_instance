terraform {
  backend "s3" {
    # OCI Object Storage S3-compatible endpoint
    bucket = "minecraft-tofu-state"
    key    = "minecraft/terraform.tfstate"
    region = "eu-marseille-1"

    endpoint = "https://axsr3mx7ucse.compat.objectstorage.eu-marseille-1.oraclecloud.com"

    # Désactive les fonctionnalités AWS non-disponibles sur OCI
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true

    # Credentials fournis via env vars AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
    # (exportés automatiquement par le Taskfile depuis tofu/secrets.tfvars)
  }
}
