############################################################################################################
# Variables globales
############################################################################################################
variable "aws_region" {
    description = "Región de AWS"
}

variable "tags" {
    description = "Tags for the rg"
    type        = map(string)
}

variable "aws_account_id" {
    description = "ID de la cuenta de AWS"
}

variable "ecr_part" {
    description = "Parte del nombre del ECR"
}
############################################################################################################
# Variables globales para lambdas
############################################################################################################
variable "lambda_handler" {
    description = "Handler de la función Lambda"
}

variable "lambda_runtime" {
    description = "Runtime de la función Lambda"
}

variable "environment" {
    description = "Ambiente (dev, test, main)"
}
############################################################################################################
# Variables globales para s3
############################################################################################################
variable "acl" {
    description = "ACL for the S3 bucket"
    type        = string
    default     = "private"
}

variable "block_public_acls" {
    description = "Block public ACLs"
    type        = bool
    default     = true
}

variable "block_public_policy" {
    description = "Block public bucket policy"
    type        = bool
    default     = true
}

variable "ignore_public_acls" {
    description = "Ignore public ACLs"
    type        = bool
    default     = true
}

variable "restrict_public_buckets" {
    description = "Restrict public bucket access"
    type        = bool
    default     = true
}

variable "sse_algorithm" {
    description = "The server-side encryption algorithm to use"
    type        = string
    default     = "AES256"
}

variable "bucket_key_enabled" {
    description = "Enable the bucket key for server-side encryption"
    type        = bool
    default     = true
}

variable "versioning_enabled" {
    description = "Enable versioning for the S3 bucket"
    type        = bool
    default     = false
}
############################################################################################################
# Variables para lambda queries
############################################################################################################
variable "lambda_name_query" {
    description = "Nombre de la función Lambda"
}

variable "lambda_description_query" {
    description = "Descripción de la función Lambda"
}

variable "source_path_query" {
    description = "Ruta local del código fuente de la Lambda"
}


variable "lambda_role_name_query" {
    description = "Nombre del rol de la función Lambda"
}
############################################################################################################
# Variables para lambda Commands
############################################################################################################
variable "lambda_name_commands" {
    description = "Nombre de la función Lambda"
}

variable "lambda_description_commands" {
    description = "Descripción de la función Lambda"
}

variable "source_path_commands" {
    description = "Ruta local del código fuente de la Lambda"
}

variable "lambda_role_name_commands" {
    description = "Nombre del rol de la función Lambda"
}
############################################################################################################
# Variables para lambda Bedrock
############################################################################################################
variable "lambda_name_bedrock" {
    description = "Nombre de la función Lambda"
}

variable "lambda_description_bedrock" {
    description = "Descripción de la función Lambda"
}

variable "source_path_bedrock" {
    description = "Ruta local del código fuente de la Lambda"
}

variable "lambda_role_name_bedrock" {
    description = "Nombre del rol de la función Lambda"
}
############################################################################################################
# Variables para layer
############################################################################################################
variable "layer_name" {
    description = "Nombre del Layer"
}

variable "layer_description" {
    description = "Descripción del Layer"
}

variable "compatible_runtimes" {
    description = "Runtimes compatibles con el Layer"
    type        = list(string)
}

variable "layer_source_path" {
    description = "Ruta del código fuente del Layer"
}
############################################################################################################
# Variables para los buckets de S3
############################################################################################################
variable "cloudfront_bucket" {
    description = "The name of the S3 bucket for CloudFront"
    type        = string
}

variable "bedrock_model_bucket" {
    description = "The name of the S3 bucket for the Bedrock model"
    type        = string
}
############################################################################################################
# Variables para dynamodb
############################################################################################################
variable "dynamodb_table_name" {
    description = "Nombre de la tabla de DynamoDB"
}
############################################################################################################
# Variables para el API Gateway
############################################################################################################
variable "api_gateway_name_bedrock" {
    description = "Nombre del API Gateway"
}
############################################################################################################
# Variables para el image Registry
############################################################################################################
variable "image_registry_name_query" {
    description = "Nombre del Image Registry para la Lambda de queries"
}

variable "image_registry_name_commands" {
    description = "Nombre del Image Registry para la Lambda de commands"
}

variable "image_registry_name_bedrock" {
    description = "Nombre del Image Registry para la Lambda de Bedrock"
}
############################################################################################################
# Variables para el Certificate SSL
############################################################################################################
variable "route53_domain_name" {
    description = "Nombre del dominio de Route53"
}

variable "route53_hosted_zone_id" {
    description = "ID de la zona de Route53"
}
############################################################################################################
# Variables para CloudFront
############################################################################################################
variable "oac_name" {
    description = "Nombre del OAC"
}