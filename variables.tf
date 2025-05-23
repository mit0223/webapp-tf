variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be 12 digits."
  }
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "Invalid AWS Region format."
  }
}

variable "container_image_tag" {
  description = "Tag of the container image to deploy"
  type        = string
  default     = "latest"
}

variable "github_repository_owner" {
  description = "Owner of the GitHub repository where the container image is stored (e.g., your GitHub username or organization name)"
  type        = string
  validation {
    condition     = length(var.github_repository_owner) > 0
    error_message = "GitHub repository owner must be provided."
  }
}

variable "container_image_name" {
  description = "Name of the container image in GitHub Container Registry"
  type        = string
  default     = "webapp-tf" # デフォルトのイメージ名を指定
   validation {
    condition     = length(var.container_image_name) > 0
    error_message = "Container image name must be provided."
  }
}

variable "mfa_serial" {
  description = "ARN of the MFA device for AWS authentication. e.g., arn:aws:iam::ACCOUNT_ID:mfa/USER_NAME"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:mfa/.+$", var.mfa_serial)) || var.mfa_serial == ""
    error_message = "Invalid MFA Serial ARN format. Leave empty if not using MFA for this specific operation (not recommended for production)."
  }
  default = "" # 環境変数で設定されていない場合は空文字とし、MFAなしで試行する（非推奨）
}
