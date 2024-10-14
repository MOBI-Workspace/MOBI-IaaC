#    _____ ______ _____ _______ _____ ______ _____ _____       _______ ______  _____            _   _ _____     _____  _   _  _____   _____  ______ _____ ____  _____  _____   _____ 
#   / ____|  ____|  __ \__   __|_   _|  ____|_   _/ ____|   /\|__   __|  ____|/ ____|     /\   | \ | |  __ \   |  __ \| \ | |/ ____| |  __ \|  ____/ ____/ __ \|  __ \|  __ \ / ____|
#  | |    | |__  | |__) | | |    | | | |__    | || |       /  \  | |  | |__  | (___      /  \  |  \| | |  | |  | |  | |  \| | (___   | |__) | |__ | |   | |  | | |__) | |  | | (___  
#  | |    |  __| |  _  /  | |    | | |  __|   | || |      / /\ \ | |  |  __|  \___ \    / /\ \ | . ` | |  | |  | |  | | . ` |\___ \  |  _  /|  __|| |   | |  | |  _  /| |  | |\___ \ 
#  | |____| |____| | \ \  | |   _| |_| |     _| || |____ / ____ \| |  | |____ ____) |  / ____ \| |\  | |__| |  | |__| | |\  |____) | | | \ \| |___| |___| |__| | | \ \| |__| |____) |
#   \_____|______|_|  \_\ |_|  |_____|_|    |_____\_____/_/    \_\_|  |______|_____/  /_/    \_\_| \_|_____/   |_____/|_| \_|_____/  |_|  \_\______\_____\____/|_|  \_\_____/|_____/ 

##############################################################################################################################################
# Certificate SSL
##############################################################################################################################################
resource "aws_acm_certificate" "mobit_sbox_cert" {
    domain_name       = var.route53_domain_name
    validation_method = "DNS"

    subject_alternative_names = [
        "www.${var.route53_domain_name}",
        "${var.route53_domain_name}",
        "auth.${var.route53_domain_name}",
        "api.${var.route53_domain_name}"
    ]

    tags = var.tags
}
##############################################################################################################################################
# DNS Records for Certificate Validation
##############################################################################################################################################
resource "aws_route53_record" "mobit_sbox_cert_validation" {
    for_each = {
        for dvo in aws_acm_certificate.mobit_sbox_cert.domain_validation_options : dvo.domain_name => {
            name   = dvo.resource_record_name
            type   = dvo.resource_record_type
            value  = dvo.resource_record_value
        }
    }

    zone_id = var.route53_hosted_zone_id
    name    = each.value.name
    type    = each.value.type
    ttl     = 300
    records = [each.value.value]
    
}

##############################################################################################################################################
# Wait for the certificate to be issued and DNS records to be created
##############################################################################################################################################
resource "aws_acm_certificate_validation" "mobit_sbox_cert_validation_complete" {
    certificate_arn         = aws_acm_certificate.mobit_sbox_cert.arn

    validation_record_fqdns = [
        for record in aws_route53_record.mobit_sbox_cert_validation : record.fqdn
    ]
}

#   ______ _____   ____  _   _ _______ ______ _   _ _____  
#  |  ____|  __ \ / __ \| \ | |__   __|  ____| \ | |  __ \ 
#  | |__  | |__) | |  | |  \| |  | |  | |__  |  \| | |  | |
#  |  __| |  _  /| |  | | . ` |  | |  |  __| | . ` | |  | |
#  | |    | | \ \| |__| | |\  |  | |  | |____| |\  | |__| |
#  |_|    |_|  \_\\____/|_| \_|  |_|  |______|_| \_|_____/ 

##############################################################################################################################################
# Get the current AWS Caller Identity
##############################################################################################################################################
data "aws_caller_identity" "current" {}
##############################################################################################################################################
# Bucket for CloudFront origin
##############################################################################################################################################
module "s3_bucket_cloudfront_bucket" {
    source = "terraform-aws-modules/s3-bucket/aws"

    bucket = var.cloudfront_bucket

    block_public_acls    = var.block_public_acls
    block_public_policy  = var.block_public_policy
    ignore_public_acls   = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets

    server_side_encryption_configuration = {
        rule = {
        apply_server_side_encryption_by_default = {
            sse_algorithm = var.sse_algorithm
        }
        bucket_key_enabled = var.bucket_key_enabled
        }
    }

    versioning = {
        enabled = var.versioning_enabled
    }

    tags = var.tags
}

##############################################################################################################################################
# Policy for CloudFront bucket
##############################################################################################################################################
resource "aws_s3_bucket_policy" "cloudfront_policy" {
    bucket = var.cloudfront_bucket

    policy = <<POLICY
{
    "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "AllowCloudFrontServicePrincipal",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudfront.amazonaws.com"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${var.cloudfront_bucket}/*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.this.id}"
                }
            }
        }
    ]
}
POLICY
}

##############################################################################################################################################
# CloudFront Origin Access Control (OAC)
##############################################################################################################################################
resource "aws_cloudfront_origin_access_control" "mobit_sbox_oac" {
    name                              = var.oac_name
    origin_access_control_origin_type = "s3"
    signing_behavior                  = "always"
    signing_protocol                  = "sigv4"
    description                       = "OAC for accessing MOBI bucket securely"
}

##############################################################################################################################################
# CloudFront distribution with OAC
##############################################################################################################################################
resource "aws_cloudfront_distribution" "this" {

    aliases = [
        "www.${var.route53_domain_name}",
        "${var.route53_domain_name}"
    ]

    comment             = "CloudFront for MOBI"
    enabled             = true
    is_ipv6_enabled     = true
    price_class         = "PriceClass_All"
    retain_on_delete    = false
    wait_for_deployment = false

    origin {
        domain_name              = "${var.cloudfront_bucket}.s3.amazonaws.com"
        origin_id                = "s3_origin"
        origin_access_control_id = aws_cloudfront_origin_access_control.mobit_sbox_oac.id  # Usar OAC
    }

    default_cache_behavior {
        target_origin_id       = "s3_origin"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods        = ["GET", "HEAD", "OPTIONS"]
        cached_methods         = ["GET", "HEAD"]
        compress               = true

        # Utilizar la política de caché recomendada por AWS para S3
        cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized

        # Origin request policy para reenviar headers, cookies, y query strings si es necesario
        origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"  # Managed-OriginRequestPolicy-S3
    }

    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }

    viewer_certificate {
        acm_certificate_arn      = aws_acm_certificate.mobit_sbox_cert.arn
        ssl_support_method       = "sni-only"
        minimum_protocol_version = "TLSv1.2_2021"
    }

    default_root_object = "index.html"

    tags = var.tags

    http_version = "http2and3"

    depends_on = [aws_acm_certificate.mobit_sbox_cert]
    
}

##############################################################################################################################################
# DNS Records (Alias) for CloudFront
##############################################################################################################################################
resource "aws_route53_record" "www_alias" {
    zone_id = var.route53_hosted_zone_id
    name    = "www.${var.route53_domain_name}"
    type    = "A"

    alias {
        name                   = aws_cloudfront_distribution.this.domain_name
        zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
        evaluate_target_health = false
    }

    depends_on = [aws_cloudfront_distribution.this] 
}

resource "aws_route53_record" "root_alias" {
    zone_id = var.route53_hosted_zone_id
    name    = "${var.route53_domain_name}"
    type    = "A"

    alias {
        name                   = aws_cloudfront_distribution.this.domain_name
        zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
        evaluate_target_health = false
    }

    depends_on = [aws_cloudfront_distribution.this]  # Dependencia de la distribución de CloudFront
}

#   ____          _____ _  ________ _   _ _____  
#  |  _ \   /\   / ____| |/ /  ____| \ | |  __ \ 
#  | |_) | /  \ | |    | ' /| |__  |  \| | |  | |
#  |  _ < / /\ \| |    |  < |  __| | . ` | |  | |
#  | |_) / ____ \ |____| . \| |____| |\  | |__| |
#  |____/_/    \_\_____|_|\_\______|_| \_|_____/ 

##############################################################################################################################################
# Lambda functions
##############################################################################################################################################

# modulo lambda_function_bedrock
module "lambda_function_bedrock" {
    source = "terraform-aws-modules/lambda/aws"

    function_name = var.lambda_name_bedrock
    description   = var.lambda_description_bedrock

    create_package = false

    image_uri    = "${var.aws_account_id}.${var.ecr_part}/${var.image_registry_name_bedrock}:latest"
    package_type = "Image"

    role_name = var.lambda_role_name_bedrock
    tags = var.tags

    depends_on = [module.ecr_lambda_bedrock]
}

# modulo lambda_function_query
module "lambda_function_query" {
    source = "terraform-aws-modules/lambda/aws"

    function_name = var.lambda_name_query
    description   = var.lambda_description_query
    create_package = false

    image_uri    = "${var.aws_account_id}.${var.ecr_part}/${var.image_registry_name_query}:latest"
    package_type = "Image"

    role_name = var.lambda_role_name_query
    tags = var.tags

    depends_on = [module.ecr_lambda_query]
}

# modulo lambda_function_commands
module "lambda_function_commands" {
    source = "terraform-aws-modules/lambda/aws"

    function_name = var.lambda_name_commands
    description   = var.lambda_description_commands

    create_package = false

    image_uri    = "${var.aws_account_id}.${var.ecr_part}/${var.image_registry_name_commands}:latest"
    package_type = "Image"

    role_name = var.lambda_role_name_commands
    tags = var.tags

    depends_on = [module.ecr_lambda_commands]
}

##############################################################################################################################################
# IAM roles and policies for Lambda functions
##############################################################################################################################################

# role de lambda-query
data "aws_iam_role" "lambda_role_query" {
    name = var.lambda_role_name_query
    depends_on = [ module.lambda_function_query ]
}

# role lambda-commands
data "aws_iam_role" "lambda_role_commands" {
    name = var.lambda_role_name_commands
    depends_on = [ module.lambda_function_commands ]
}

# role lambda-bedrock
data "aws_iam_role" "lambda_role_bedrock" {
    name = var.lambda_role_name_bedrock
    depends_on = [ module.lambda_function_bedrock ]
}

##############################################################################################################################################
# ECR repositories for Lambda functions
##############################################################################################################################################

# Módulo para el repositorio de ECR de la lambda de Bedrock
module "ecr_lambda_bedrock" {
    source = "terraform-aws-modules/ecr/aws"

    repository_name = var.image_registry_name_bedrock

    repository_image_tag_mutability = "MUTABLE"

    repository_lifecycle_policy = jsonencode({
        rules = [
        {
            rulePriority = 1,
            description  = "Always keep latest image",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["latest"],
            countType     = "imageCountMoreThan",
            countNumber   = 1
            },
            action = {
            type = "expire"
            }
        },
        {
            rulePriority = 2,
            description  = "Keep last 30 images with tag v",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["v"],
            countType     = "imageCountMoreThan",
            countNumber   = 30
            },
            action = {
            type = "expire"
            }
        }
        ]
    })
    tags = var.tags
}

# Módulo para el repositorio de ECR de la lambda de Query
module "ecr_lambda_query" {
    source = "terraform-aws-modules/ecr/aws"

    repository_name = var.image_registry_name_query

    repository_image_tag_mutability = "MUTABLE"

    repository_lifecycle_policy = jsonencode({
        rules = [
        {
            rulePriority = 1,
            description  = "Always keep latest image",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["latest"],
            countType     = "imageCountMoreThan",
            countNumber   = 1
            },
            action = {
            type = "expire"
            }
        },
        {
            rulePriority = 2,
            description  = "Keep last 30 images with tag v",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["v"],
            countType     = "imageCountMoreThan",
            countNumber   = 30
            },
            action = {
            type = "expire"
            }
        }
        ]
    })

    tags = var.tags
}

# Módulo para el repositorio de ECR de la lambda de Commands
module "ecr_lambda_commands" {
    source = "terraform-aws-modules/ecr/aws"

    repository_name = var.image_registry_name_commands

    repository_image_tag_mutability = "MUTABLE"

    repository_lifecycle_policy = jsonencode({
        rules = [
        {
            rulePriority = 1,
            description  = "Always keep latest image",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["latest"],
            countType     = "imageCountMoreThan",
            countNumber   = 1
            },
            action = {
            type = "expire"
            }
        },
        {
            rulePriority = 2,
            description  = "Keep last 30 images with tag v",
            selection = {
            tagStatus     = "tagged",
            tagPrefixList = ["v"],
            countType     = "imageCountMoreThan",
            countNumber   = 30
            },
            action = {
            type = "expire"
            }
        }
        ]
    })

    tags = var.tags
}

##############################################################################################################################################
# S3 bucket for Bedrock model
##############################################################################################################################################

# Módulo para el bucket de Bedrock
module "s3_bucket_bedrock_model" {
    source = "terraform-aws-modules/s3-bucket/aws"

    bucket = var.bedrock_model_bucket

    block_public_acls    = var.block_public_acls
    block_public_policy  = var.block_public_policy
    ignore_public_acls   = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets

    server_side_encryption_configuration = {
        rule = {
        apply_server_side_encryption_by_default = {
            sse_algorithm = var.sse_algorithm
        }
        bucket_key_enabled = var.bucket_key_enabled
        }
    }

    versioning = {
        enabled = var.versioning_enabled
    }

    tags = var.tags
}

##############################################################################################################################################
# Permissions for Lambda functions on S3 bucket
##############################################################################################################################################

# Permisos de lectura sobre el bucket s3_bucket_bedrock_model para lambda-bedrock
resource "aws_iam_policy" "lambda_bedrock_s3_read_policy" {
    name        = "${var.lambda_name_bedrock}-s3-read-policy"
    description = "Permite lectura en el bucket S3 para la función Lambda de bedrock."

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid      = "AllowS3ReadAccess",
            Effect   = "Allow",
            Action   = [
                "s3:GetObject"
            ],
            Resource = "${module.s3_bucket_bedrock_model.s3_bucket_arn}/*"
        }
        ]
    })

    depends_on = [ data.aws_iam_role.lambda_role_bedrock ]

    tags = var.tags
}

# Adjuntar la política al rol de lambda-bedrock para el bucket s3_bucket_bedrock_model
resource "aws_iam_role_policy_attachment" "lambda_bedrock_s3_read_attachment" {
    role       = data.aws_iam_role.lambda_role_bedrock.name
    policy_arn = aws_iam_policy.lambda_bedrock_s3_read_policy.arn
}

##############################################################################################################################################
# DynamoDB table for Lambda functions
##############################################################################################################################################

# Módulo para la tabla de DynamoDB
module "dynamodb_table" {
    source   = "terraform-aws-modules/dynamodb-table/aws"

    name     = var.dynamodb_table_name
    hash_key = "PK"
    range_key = "SK"

    attributes = [
        {
            name = "PK" 
            type = "S"
        },
        {
            name = "SK"
            type = "S"
        }
    ]

    tags = var.tags
}

##############################################################################################################################################
# Permissions for Lambda functions on DynamoDB table
##############################################################################################################################################
resource "aws_iam_policy" "lambda_query_dynamodb_read_policy" {
    name        = "${var.lambda_name_query}-dynamodb-read-policy"
    description = "Permite lectura en la tabla de DynamoDB para la función Lambda de consultas."

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action   = [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
            ]
            Effect   = "Allow"
            Resource = module.dynamodb_table.dynamodb_table_arn
        }
        ]
    })
    depends_on = [ module.dynamodb_table, data.aws_iam_role.lambda_role_query ]

    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_query_dynamodb_read_attachment" {
    role       = data.aws_iam_role.lambda_role_query.name
    policy_arn = aws_iam_policy.lambda_query_dynamodb_read_policy.arn
}

resource "aws_iam_policy" "lambda_commands_dynamodb_write_policy" {
    name        = "${var.lambda_name_commands}-dynamodb-write-policy"
    description = "Permite escritura en la tabla de DynamoDB para la función Lambda de comandos."

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action   = [
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem"
            ]
            Effect   = "Allow"
            Resource = module.dynamodb_table.dynamodb_table_arn
        }
        ]
    })

    depends_on = [ module.dynamodb_table, data.aws_iam_role.lambda_role_commands ]

    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_commands_dynamodb_write_attachment" {
    role       = data.aws_iam_role.lambda_role_commands.name
    policy_arn = aws_iam_policy.lambda_commands_dynamodb_write_policy.arn
}

resource "aws_iam_policy" "lambda_bedrock_invoke_policy" {
    name        = "${var.lambda_name_bedrock}-bedrock-invoke-policy"
    description = "Permite invocar modelos de Amazon Bedrock para la función Lambda de bedrock."

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
        {
            Sid      = "AllowInvokeBedrockModel",
            Effect   = "Allow",
            Action   = "bedrock:InvokeModel",
            Resource = "*"
        }
        ]
    })

    depends_on = [ data.aws_iam_role.lambda_role_bedrock ]

    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_bedrock_invoke_attachment" {
    role       = data.aws_iam_role.lambda_role_bedrock.name
    policy_arn = aws_iam_policy.lambda_bedrock_invoke_policy.arn
}

#            _____ _____    _____       _______ ________          __ __     __
#      /\   |  __ \_   _|  / ____|   /\|__   __|  ____\ \        / /\\ \   / /
#     /  \  | |__) || |   | |  __   /  \  | |  | |__   \ \  /\  / /  \\ \_/ / 
#    / /\ \ |  ___/ | |   | | |_ | / /\ \ | |  |  __|   \ \/  \/ / /\ \\   /  
#   / ____ \| |    _| |_  | |__| |/ ____ \| |  | |____   \  /\  / ____ \| |   
#  /_/    \_\_|   |_____|  \_____/_/    \_\_|  |______|   \/  \/_/    \_\_|    

# Crear la API Gateway REST API
resource "aws_api_gateway_rest_api" "rest_api" {
    name        = var.api_gateway_name_bedrock
    description = "REST API for Bedrock Lambda"

    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

# Crear el recurso proxy "/{proxy+}"
resource "aws_api_gateway_resource" "proxy_resource" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
    path_part   = "{proxy+}"
}

# Método ANY para el recurso raíz "/"
resource "aws_api_gateway_method" "any_root" {
    rest_api_id   = aws_api_gateway_rest_api.rest_api.id
    resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
    http_method   = "ANY"
    authorization = "NONE"
}

# Método OPTIONS para el recurso raíz "/"
resource "aws_api_gateway_method" "options_root" {
    rest_api_id   = aws_api_gateway_rest_api.rest_api.id
    resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
    http_method   = "OPTIONS"
    authorization = "NONE"
}

# Respuesta para el método OPTIONS en el recurso raíz "/"
resource "aws_api_gateway_method_response" "options_root_response" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_rest_api.rest_api.root_resource_id
    http_method = "OPTIONS"
    status_code = "200"

    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
    }
}

# Método ANY para el recurso proxy "/{proxy+}"
resource "aws_api_gateway_method" "any_proxy" {
    rest_api_id   = aws_api_gateway_rest_api.rest_api.id
    resource_id   = aws_api_gateway_resource.proxy_resource.id
    http_method   = "ANY"
    authorization = "NONE"
}

# Método OPTIONS para el recurso proxy "/{proxy+}"
resource "aws_api_gateway_method" "options_proxy" {
    rest_api_id   = aws_api_gateway_rest_api.rest_api.id
    resource_id   = aws_api_gateway_resource.proxy_resource.id
    http_method   = "OPTIONS"
    authorization = "NONE"
}

# Respuesta para el método OPTIONS en el recurso proxy "/{proxy+}"
resource "aws_api_gateway_method_response" "options_proxy_response" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    resource_id = aws_api_gateway_resource.proxy_resource.id
    http_method = "OPTIONS"
    status_code = "200"

    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin"  = true
        "method.response.header.Access-Control-Allow-Methods" = true
        "method.response.header.Access-Control-Allow-Headers" = true
    }
}

# Integración de Lambda para el método ANY en el recurso raíz "/"
resource "aws_api_gateway_integration" "lambda_proxy_integration_root" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_rest_api.rest_api.root_resource_id
    http_method             = aws_api_gateway_method.any_root.http_method
    integration_http_method = "POST"  # AWS_PROXY siempre usa POST como método de integración
    type                    = "AWS_PROXY"
    uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${module.lambda_function_bedrock.lambda_function_arn}/invocations"
}

# Integración de Lambda para el método ANY en el recurso proxy "/{proxy+}"
resource "aws_api_gateway_integration" "lambda_proxy_integration_proxy" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.proxy_resource.id
    http_method             = aws_api_gateway_method.any_proxy.http_method
    integration_http_method = "POST"
    type                    = "AWS_PROXY"
    uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${module.lambda_function_bedrock.lambda_function_arn}/invocations"
}

# Integración de MOCK para el método OPTIONS en el recurso raíz "/"
resource "aws_api_gateway_integration" "lambda_proxy_integration_options_root" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_rest_api.rest_api.root_resource_id
    http_method             = aws_api_gateway_method.options_root.http_method
    integration_http_method = "POST"
    type                    = "MOCK"
}

# Integración de MOCK para el método OPTIONS en el recurso proxy "/{proxy+}"
resource "aws_api_gateway_integration" "lambda_proxy_integration_options_proxy" {
    rest_api_id             = aws_api_gateway_rest_api.rest_api.id
    resource_id             = aws_api_gateway_resource.proxy_resource.id
    http_method             = aws_api_gateway_method.options_proxy.http_method
    integration_http_method = "POST"
    type                    = "MOCK"
}

# Crear el deployment de la API
resource "aws_api_gateway_deployment" "api_deployment" {
    rest_api_id = aws_api_gateway_rest_api.rest_api.id
    stage_name  = "dev" 

    # Trigger para redeploy cuando hay cambios en la configuración de la API
    triggers = {
        redeployment = sha1(jsonencode([
        aws_api_gateway_method.any_root.id,
        aws_api_gateway_method.options_root.id,
        aws_api_gateway_method.any_proxy.id,
        aws_api_gateway_method.options_proxy.id,
        ]))
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_api_gateway_stage" "api_stage" {
    rest_api_id   = aws_api_gateway_rest_api.rest_api.id
    deployment_id = aws_api_gateway_deployment.api_deployment.id
    stage_name    = "dev"

    variables = {
        "ENV" = "dev"
    }

    tags = {
        Name = "API Stage dev"
        Env  = "dev"
    }
}

resource "aws_lambda_permission" "allow_api_gateway" {
    statement_id  = "AllowAPIGatewayInvoke"
    action        = "lambda:InvokeFunction"
    function_name = module.lambda_function_bedrock.lambda_function_arn
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_api_gateway_rest_api.rest_api.execution_arn}/*/*"
}


