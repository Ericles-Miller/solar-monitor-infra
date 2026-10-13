data "aws_caller_identity" "current" {}

# O estado tem endereços e ids de recursos: só aceitar acesso por HTTPS.
data "aws_iam_policy_document" "state" {
  statement {
    sid     = "SomenteHTTPS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
