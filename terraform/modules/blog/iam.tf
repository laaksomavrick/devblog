resource "aws_iam_openid_connect_provider" "github_provider" {
  count = var.common_tags["Environment"] == "production" ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

// TODO: come back to this at a later date - scope creep with this change

//resource "aws_iam_role" "technoblather_cd_role" {
//  count           = var.common_tags["Environment"] == "production" ? 1 : 0
//  name = "TechnoblatherContinuousDeployment"
//
//  assume_role_policy = jsonencode({
//    Version = "2012-10-17"
//    Statement = [
//      {
//        "Effect": "Allow",
//        "Principal": {
//          "Federated": aws_iam_openid_connect_provider.github_provider.arn
//        },
//        "Action": "sts:AssumeRoleWithWebIdentity",
//        "Condition": {
//          "StringLike": {
//            "token.actions.githubusercontent.com:sub": "repo:${var.github_repo_path}:*"
//          }
//        }
//      }
//    ]
//  })
//
//  tags = var.common_tags
//}
//
//data "aws_iam_policy_document" "technoblather_cd_policy_document" {
//  statement {
//    effect = "Allow"
//    actions = [
//      "s3:*"
//    ]
//    resources = [
//      aws_s3_bucket.www_bucket.arn,
//      "${aws_s3_bucket.www_bucket.arn}/*",
//    ]
//  }
//  statement {
//    effect = "Allow"
//    actions = [
//      "cloudfront:*"
//    ]
//    resources = [
//      aws_cloudfront_distribution.www_s3_distribution.arn
//    ]
//  }
//}
//
//resource "aws_iam_policy" "technoblather_cd_policy" {
//  name   = "TechnoblatherContinuousDeployment"
//  policy = data.aws_iam_policy_document.technoblather_cd_policy_document.json
//}
//
//resource "aws_iam_role_policy_attachment" "technoblather_cd_role_policy_attachment" {
//  role       = aws_iam_role.technoblather_cd_role.name
//  policy_arn = aws_iam_policy.technoblather_cd_policy.arn
//}
//
