resource "aws_iam_policy" "this" {
  name = "gitlab-runner-role-assume"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Action": [
          "sts:AssumeRole"
        ],
        "Resource": [
          "arn:aws:iam::${account_id}:role/build-*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "this" {
  name               = "gitlab-runner"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::${account_id}:oidc-provider/${cluster-endpoint-without-https}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
           "StringEquals": {
             "oidc.eks.${region}.amazonaws.com/id/${account_id}:aud": "sts.amazonaws.com",
             "oidc.eks.${region}.amazonaws.com/id/${account_id}:sub": "system:serviceaccount:${gitlab-runner-namespace}:${gitlab-runner-service-account-name}"
           }
         }
       }
    ]
  })
  description        = "Use by gitlab-runner pod"
}

resource "aws_iam_role_policy_attachment" "this" {
  depends_on = [aws_iam_role.this, aws_iam_policy.this]

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}