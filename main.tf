provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# The configuration for the `remote` backend.
terraform {
  backend "remote" {
    # The name of your Terraform Cloud organization.
    organization = "broc"

    # The name of the Terraform Cloud workspace to store Terraform state files in.
    workspaces {
      name = "intro-pipeline"
    }
  }
}

resource "aws_s3_bucket" "source" {
  bucket        = "source-intro"
  force_destroy = var.force_destroy

}

resource "aws_s3_bucket" "datalake" {
  bucket        = "datalake-intro"
  force_destroy = var.force_destroy
}

# Creating a bucket to hold lambda?
resource "aws_s3_bucket" "lambda_funcs" {
  bucket        = "lambda-funcs-intro"
  force_destroy = var.force_destroy
}

resource "aws_s3_object" "lambda_func_file" {
  bucket = aws_s3_bucket.lambda_funcs.id
  key    = "move-from-source-to-datalake"
  source = "move_file.py.zip"
}


resource "aws_sns_topic" "my_first_sns_topic" {
  name = var.sns_name
}

resource "aws_s3_bucket_notification" "bucket_notification" {

  bucket = aws_s3_bucket.source.id

  topic {
    topic_arn = aws_sns_topic.topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

resource "aws_sns_topic" "topic" {
  name = "s3-event-notification-topic"

  policy = <<POLICY
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:s3-event-notification-topic",
        "Condition":{
            "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.source.arn}"}
        }
    }]
}
POLICY
}

resource "aws_sns_topic_policy" "my_sns_topic_policy" {
  arn    = aws_sns_topic.my_first_sns_topic.arn
  policy = data.aws_iam_policy_document.my_custom_sns_policy_document.json
}

data "aws_iam_policy_document" "my_custom_sns_policy_document" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"

      values = [
        var.account_id,
      ]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.my_first_sns_topic.arn,

    ]

    sid = "__default_statement_ID"
  }
}


resource "aws_sqs_queue" "my_first_sqs" {
  name = var.sqs_name
}

resource "aws_sqs_queue_policy" "my_sqs_policy" {
  queue_url = aws_sqs_queue.my_first_sqs.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.my_first_sqs.arn}"
    }
  ]
}
POLICY
}

resource "aws_sns_topic_subscription" "sns_updates_sqs_target" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.my_first_sqs.arn
}


# AWS Lamdba setup 

data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_dir  = "${path.module}/python"
  output_path = "move_file.py.zip"
}


resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": 
      [
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
        ]
        ,
      "Resource": "${aws_sqs_queue.my_first_sqs.arn}",
      "Effect": "Allow"
   }, 
   {
    "Action":["s3:ListBucket",
              "s3:GetObject",
              "s3:GetObjectTagging",
              "s3:PutObject",
              "s3:PutObjectTagging",
              "s3:PutObjectAcl"],
    "Effect": "Allow",
    "Resource": [
      "${aws_s3_bucket.datalake.arn}",
      "${aws_s3_bucket.source.arn}",
      "${aws_s3_bucket.datalake.arn}/*",
       "${aws_s3_bucket.source.arn}/*"
      ]
   },
  {"Effect": "Allow",
  "Action": [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ],
  "Resource": ["arn:aws:logs:*:*:*"]
  } 
 ]
}
EOF
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "terraform_function_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_lambda_function" "terraform_function" {
  filename         = "move_file.py.zip"
  function_name    = "move-from-source-to-datalake"
  handler          = "move_file.handler"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.9"
  depends_on       = [aws_iam_role_policy_attachment.terraform_function_role]
  source_code_hash = filebase64sha256("move_file.py.zip")
}

resource "aws_lambda_event_source_mapping" "sqs_trigger_lambda" {
  event_source_arn = aws_sqs_queue.my_first_sqs.arn
  function_name    = aws_lambda_function.terraform_function.arn
}
