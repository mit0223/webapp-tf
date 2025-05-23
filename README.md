# webapp-tf: Terraform ECS Deployment

This repository contains Terraform code to deploy a web application to AWS ECS (Elastic Container Service) using Fargate. The application is served via an Application Load Balancer (ALB).

## Prerequisites

- An AWS account.
- A GitHub account.
- Docker installed locally if you need to build and push a container image (this example assumes a public image on GitHub Container Registry).

## Setup

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd webapp-tf
```

### 2. Configure GitHub Codespaces Secrets and Variables

This project is designed to be used with GitHub Codespaces. You need to configure the following secrets and variables in your repository settings (`Settings > Secrets and variables > Codespaces` or `Settings > Secrets and variables > Actions` if you plan to use GitHub Actions for deployment, though this guide focuses on manual deployment from Codespaces):

**Repository Secrets:**

- `AWS_ACCESS_KEY_ID`: Your AWS access key ID.
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key.
- `TF_VAR_mfa_serial`: (Optional but Recommended) The ARN of your MFA device (e.g., `arn:aws:iam::123456789012:mfa/your-username`). If you don't set this, MFA will be skipped if the `mfa_serial` variable in `variables.tf` has an empty default or is not prompted for.

**Repository Variables (for Codespaces):**

- `TF_VAR_aws_account_id`: Your 12-digit AWS Account ID.
- `TF_VAR_aws_region`: The AWS region where you want to deploy the resources (e.g., `ap-northeast-1`).
- `TF_VAR_github_repository_owner`: The owner of the GitHub repository where your container image is stored (e.g., your GitHub username or organization name).
- `TF_VAR_container_image_name`: The name of your container image in GitHub Container Registry (e.g., `my-web-app`). Defaults to `webapp-tf` if not set.
- `TF_VAR_container_image_tag`: The tag of the container image to deploy (e.g., `latest`, `v1.0.0`). Defaults to `latest` if not set.

**Note:** Environment variables prefixed with `TF_VAR_` are automatically picked up by Terraform as input variables.

### 3. Open in GitHub Codespaces

Click the "Code" button on your repository page and select "Open with Codespaces". Create a new codespace or open an existing one.

The dev container will be built with Terraform, AWS CLI, Docker, and necessary VS Code extensions. The `postCreateCommand` in `devcontainer.json` also installs `aws-mfa` for handling MFA authentication.

## Deployment Steps

Once your Codespace is ready and you have configured the secrets and variables:

1.  **Authenticate with AWS (MFA):**

    If you have configured `TF_VAR_mfa_serial`, you will need to get temporary credentials using your MFA device. Open a terminal in VS Code:

    ```bash
    aws-mfa --profile default --device YOUR_MFA_SERIAL_ARN
    ```
    Replace `YOUR_MFA_SERIAL_ARN` with your actual MFA serial ARN (e.g., `arn:aws:iam::123456789012:mfa/your-username`). You will be prompted to enter your OTP (One-Time Password) from your MFA device. This command will update your `~/.aws/credentials` file with temporary session credentials.

    If you haven't set `TF_VAR_mfa_serial` or the `mfa_serial` variable is empty, Terraform will attempt to authenticate using the configured `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` directly. **This is not recommended for production environments.**

2.  **Initialize Terraform:**

    In the VS Code terminal, navigate to the directory containing the Terraform files (the root of this repository) and run:

    ```bash
    terraform init
    ```

3.  **Review the Plan:**

    See what resources Terraform will create:

    ```bash
    terraform plan
    ```
    If you did not use `aws-mfa` and `TF_VAR_mfa_serial` is set, Terraform might prompt for the MFA token here if the `mfa_serial` variable is not empty in your `variables.tf` and no valid session token is found. However, the `aws-mfa` approach is generally smoother.

4.  **Apply the Configuration:**

    Deploy the resources:

    ```bash
    terraform apply
    ```
    Terraform will again show the plan and ask for confirmation. Type `yes` to proceed.

    If MFA is required and a token wasn't provided via `aws-mfa` or a previous prompt, you'll be asked for your OTP here.

5.  **Access Your Application:**

    Once the apply is complete, Terraform will output the DNS name of the Application Load Balancer (`alb_dns_name`). Open this URL in your web browser to access your deployed application.

    ```
    Outputs:

    alb_dns_name = "webapp-tf-alb-xxxxxxxxxxxxxx.ap-northeast-1.elb.amazonaws.com"
    ecs_cluster_name = "webapp-tf-cluster"
    ecs_service_name = "webapp-tf-service"
    ```

## Cleaning Up

To remove all the resources created by Terraform:

1.  **Authenticate with AWS (MFA)** if your session has expired, as described in Step 1 of Deployment.
2.  Run the destroy command:

    ```bash
    terraform destroy
    ```
    Type `yes` when prompted for confirmation.

## Terraform Files

-   `main.tf`: Defines the AWS resources (VPC, Subnets, IGW, Route Tables, Security Groups, ALB, ECS Cluster, ECS Task Definition, ECS Service, IAM Roles).
-   `variables.tf`: Declares input variables, their types, descriptions, default values, and validation rules. These are populated by environment variables (`TF_VAR_*`).
-   `outputs.tf`: Defines the outputs that will be displayed after a successful `terraform apply`.
-   `.devcontainer/devcontainer.json`: Configuration for the development container in GitHub Codespaces.

## Assumed IAM Role

The Terraform AWS provider is configured to assume the IAM role named `CdkDeployer`.
```hcl
provider "aws" {
  # ...
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/CdkDeployer"
  }
  # ...
}
```
Ensure this role exists in your AWS account and has the necessary permissions to create and manage all the resources defined in the Terraform configuration (ECS, EC2 (for ALB/VPC), IAM, S3 for backend (if you add one), CloudWatch Logs, etc.).

## Container Image

The ECS Task Definition is configured to pull a public container image from GitHub Container Registry:
```hcl
  container_definitions = jsonencode([
    {
      name      = "webapp-tf-container"
      image     = "ghcr.io/${var.github_repository_owner}/${var.container_image_name}:${var.container_image_tag}"
      // ...
      portMappings = [
        {
          containerPort = 8080 // Your application's port
          hostPort      = 8080
        }
      ]
    }
  ])
```
Make sure your container image is:
1. Publicly accessible on `ghcr.io`.
2. Exposes port `8080` (or update the `containerPort` and target group port accordingly).
3. The `TF_VAR_github_repository_owner`, `TF_VAR_container_image_name`, and `TF_VAR_container_image_tag` variables are correctly set in your Codespaces settings to point to your image.
