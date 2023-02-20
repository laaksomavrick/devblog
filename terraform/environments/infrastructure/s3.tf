resource "aws_s3_bucket" "technoblather_terraform_states_bucket" {
  bucket = var.tfstate_bucket
}

resource "aws_s3_bucket_ownership_controls" "technoblather_terraform_states_bucket_ownership_controls" {
  bucket = aws_s3_bucket.technoblather_terraform_states_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_object" "production_state" {
  bucket = aws_s3_bucket.technoblather_terraform_states_bucket.bucket
  key    = var.production_tfstate_key
}
resource "aws_s3_bucket_object" "staging_state" {
  bucket = aws_s3_bucket.technoblather_terraform_states_bucket.bucket
  key    = var.staging_tfstate_key
}
