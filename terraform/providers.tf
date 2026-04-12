terraform {
  backend "s3" {
    bucket         = "hebrewsapp-497162053259-ap-southeast-1-an"
    key            = "dev/terraform.tfstate" # Path inside the bucket
    region         = "ap-southeast-1"
    encrypt        = true
    # Optional: Add dynamodb_table = "terraform-lock" later to prevent 
    # two people from running terraform at the same time.
  }
}
