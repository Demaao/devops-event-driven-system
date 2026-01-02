# General AWS settings
variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

# Networking 
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR for public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR for public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  description = "CIDR for private subnet 1 (EKS nodes)"
  type        = string
  default     = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR for private subnet 2 (EKS nodes)"
  type        = string
  default     = "10.0.12.0/24"
}

# EKS Configuration
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "devops-eks-cluster"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default = "t3.medium"
}

variable "eks_node_count" {
  description = "Fixed number of EKS worker nodes"
  type        = number
  default     = 2
}

# Application Settings
variable "producer_service_url" {
  description = "URL of the producer service endpoint"
  type        = string
}
