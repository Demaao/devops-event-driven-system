# Terraform & AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region
}


# Networking
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "devops-vpc"
  }
}

# Internet Gateway for public access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "eu-central-1b"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}


# IAM Roles for EKS
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM role for EKS worker nodes
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ])

  role       = aws_iam_role.eks_node_role.name
  policy_arn = each.value
}

# EKS Cluster & Node Group
resource "aws_eks_cluster" "eks" {
  name     = var.eks_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id,
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "eks-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn

 subnet_ids = [
  aws_subnet.public_1.id,
  aws_subnet.public_2.id
]

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = var.eks_node_count
    min_size     = var.eks_node_count
    max_size     = var.eks_node_count
  }
}
# IAM role shared by Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda-s3-kafka-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# CloudWatch logs for Lambda
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda triggered by S3 uploads
resource "aws_lambda_function" "s3_to_kafka" {
  function_name = "s3-to-kafka"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.10"
  handler       = "lambda_function.lambda_handler"

  filename         = "${path.module}/../lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda.zip")

  environment {
    variables = {
      PRODUCER_SERVICE_URL = "http://a647a891625b14003ae393dfa59a00db-1029740823.eu-central-1.elb.amazonaws.com/produce"
    }
  }
}


resource "aws_s3_bucket" "ingestion_bucket" {
  bucket = "devops-ingestion-bucket-${random_id.suffix.hex}"
}
resource "random_id" "suffix" {
  byte_length = 4
}
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_kafka.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.ingestion_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.ingestion_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_to_kafka.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
# Lambda triggered by API Gateway
resource "aws_lambda_function" "api_to_kafka" {
  function_name = "api-to-kafka"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.10"
  handler       = "lambda_api.lambda_handler"

  filename         = "${path.module}/../lambda/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda.zip")

  environment {
    variables = {
       PRODUCER_SERVICE_URL = "http://a647a891625b14003ae393dfa59a00db-1029740823.eu-central-1.elb.amazonaws.com/produce"
  }
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Security group for Lambda to access Kafka in EKS"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = "devops-event-api"
}
resource "aws_api_gateway_resource" "products" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "products"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_to_kafka.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  depends_on = [
    aws_api_gateway_integration.products_lambda,
    aws_api_gateway_integration.orders_lambda,
    aws_api_gateway_integration.suppliers_lambda
  ]
}
resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id  = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
}

resource "aws_iam_policy" "lambda_s3_read_policy" {
  name = "lambda-s3-read-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.ingestion_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_read_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_read_policy.arn
}

# Resources: products /orders /suppliers
resource "aws_api_gateway_method" "products_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.products.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "products_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.products.id
  http_method             = aws_api_gateway_method.products_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_to_kafka.invoke_arn
}


resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "orders_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_to_kafka.invoke_arn
}

resource "aws_api_gateway_resource" "suppliers" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "suppliers"
}

resource "aws_api_gateway_method" "suppliers_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.suppliers.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "suppliers_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.suppliers.id
  http_method             = aws_api_gateway_method.suppliers_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api_to_kafka.invoke_arn
}
