data "aws_iam_policy_document" "provisioner_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "s3:*",
      "cloudwatch:*",
      "cloudfront:*",
      "cloudtrail:*",
      "logs:*",
      "sns:*",
      "acm:*",
      "route53:*",
      "route53domains:*",
      "autoscaling:Describe*",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:ListServerCertificates",
      "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "oam:ListSinks"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "technoblather_provisioner_policy" {
  name   = "TechnoblatherTerraformProvisionerPolicy"
  policy = data.aws_iam_policy_document.provisioner_policy_document.json
}

data "aws_iam_policy_document" "tf_staging_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.technoblather_terraform_states_bucket.arn
    ]
  }
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${aws_s3_bucket.technoblather_terraform_states_bucket.arn}/${aws_s3_bucket_object.staging_state.id}"
    ]
  }
  statement {
    effect  = "Deny"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${aws_s3_bucket.technoblather_terraform_states_bucket.arn}/${aws_s3_bucket_object.production_state.id}"
    ]
  }
}

data "aws_iam_policy_document" "tf_production_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["s3:ListBucket"]
    resources = [
      aws_s3_bucket.technoblather_terraform_states_bucket.arn
    ]
  }
  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${aws_s3_bucket.technoblather_terraform_states_bucket.arn}/${aws_s3_bucket_object.production_state.id}"
    ]
  }
  statement {
    effect  = "Deny"
    actions = ["s3:GetObject", "s3:PutObject"]
    resources = [
      "${aws_s3_bucket.technoblather_terraform_states_bucket.arn}/${aws_s3_bucket_object.staging_state.id}"
    ]
  }
}

resource "aws_iam_policy" "tf_staging_policy" {
  name   = "TechnoblatherTerraformStagingStatePolicy"
  policy = data.aws_iam_policy_document.tf_staging_policy_document.json
}

resource "aws_iam_policy" "tf_production_policy" {
  name   = "TechnoblatherTerraformProductionPolicy"
  policy = data.aws_iam_policy_document.tf_production_policy_document.json
}

resource "aws_iam_role" "tf_staging_role" {
  name = "TechnoblatherTerraformProvisionerStaging"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = var.administrator_arn
        }
      },
    ]
  })
}

resource "aws_iam_role" "tf_production_role" {
  name = "TechnoblatherTerraformProvisionerProduction"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = var.administrator_arn
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tf_staging_role_policy_attachment" {
  role       = aws_iam_role.tf_staging_role.name
  policy_arn = aws_iam_policy.tf_staging_policy.arn
}

resource "aws_iam_role_policy_attachment" "tf_staging_provisioner_role_policy_attachment" {
  role       = aws_iam_role.tf_staging_role.name
  policy_arn = aws_iam_policy.technoblather_provisioner_policy.arn
}

resource "aws_iam_role_policy_attachment" "tf_production_role_policy_attachment" {
  role       = aws_iam_role.tf_production_role.name
  policy_arn = aws_iam_policy.tf_production_policy.arn
}

resource "aws_iam_role_policy_attachment" "tf_production_provisioner_role_policy_attachment" {
  role       = aws_iam_role.tf_production_role.name
  policy_arn = aws_iam_policy.technoblather_provisioner_policy.arn
}