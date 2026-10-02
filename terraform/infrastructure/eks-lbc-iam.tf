locals {
  eks_oidc_issuer = replace(
    aws_eks_cluster.main.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-aws-load-balancer-controller"
  description = "Permissions for the AWS Load Balancer Controller"

  policy = file(
    "${path.module}/policies/aws-load-balancer-controller-v3.4.3.json"
  )

  tags = {
    Project = var.project_name
  }
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
