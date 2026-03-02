# Terraform with AWS

After running into some issues with GCP, I decided to take a quick detour from the course to learn Terraform using AWS by following the [Terraform Course](https://github.com/sidpalas/devops-directive-terraform-course) by Sid from DevOps Directive.


## Getting Started

### Install Terraform (Homebrew on macOS)

```shell
brew install terraform
```
### Create AWS user and assign permissions*
1. Create non-root AWS user
2. Create user group and select policies to attach to group
    - AmazonDynamoDBFullAccess
    - AmazonEC2FullAccess
    - AmazonRDSFullAccess
    - AmazonRoute53FullAccess
    - AmazonS3FullAccess
    - IAMFullAccess
3. Save Access key + secret key for configuring AWS CLI

### Install and configure AWS CLI v2 (macOS)

1. Install AWS CLI v2 
```shell
curl "https://awscli.amazonaws.com/AWSCLIV2-2.0.30.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```
2. Configure AWS CLI
```shell
aws configure
```
- When prompted, enter the access key and secret access key from the created non-root AWS user, along with default region and output format. For example:
```shell
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

## Terraform Overview
In this section (`02-terraform-overview`), we will use Terraform to provision an EC2 instance on AWS.

### Create configuration files
In a new directory (ex. `02-terraform-overview`), we'll write our configuration files. 

The `terraform {}` block within the `terraform.tf` file configures Terraform and specifies that we are using AWS as a provider.

```hcl
# terraform.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}
```

The `provider {}` block within the `main.tf` file configures our provider settings. In this case, we set the region that AWS should create the resources in. 

The `resource {}` block outlines the components we want to include in the infrastructure. 

```hcl
# main.tf

provider "aws" {
  region = "us-west-1"
}

resource "aws_instance" "example" {
  ami           = "ami-072028e29f8a73b88"
  instance_type = "t3.micro"                    # AWS Free Tier eligible

  tags = {
    Name = "learn-terraform"
  }
}
```
- We declare the resource type (`aws_instance`) and resource name (`example`), which will form the unique resource address for the resource in our configuration.
- The `ami` argument specifies which machine image to use.
- The `instance_type` argument specifies the configuration of the virtual server. 
- The  `tags` argument sets the EC2 instance's name

We can ensure that the configuration files are properly formatted according to HashiCorp's recommended style by running the following command in the terminal:

```shell
terraform fmt
```

Any modified files will be printed in the terminal.

### Create infrastructure

To begin, we must initialize our Terraform workspace. While in the working directory (ex. `02-terraform-overview`), enter the following command in the terminal:
```shell
terraform init
```
Terraform will download and install the providers defined in the configuration files into the current directory.

The configuration can be validated with the following command:
```shell
terraform validate
```

With `terraform apply`, Terraform will create an execution plan for making changes to the infrastructure.

```shell
terraform apply
```

You will be able to review the plan and confirm the changes before they are applied. Once you approve the changes by entering `yes`, Terraform will perform the actions.

Once completed, we'll see the following message in the terminal:

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

After applying the configuration, we'll see that Terraform created a `terraform.tfstate` file in the current directory. The state file keeps a snapshot of the current infrastructure and compares it to the configuration files to determine what changes are needed to reach the desired state. 

By default, the state file is stored locally. Because it can contain sensitive information, such as passwords or security keys, the state file should be stored securely. In addition, add `*.tfstate` and `.terraform/` to your `.gitignore`.

We can view our new EC2 instance by navigating to the EC2 console in AWS (make sure that the region matches the one set in the configuration file). We can also list the resources in the Terraform workspace's state with:

```shell
terraform state list
```
### Destroy infrastructure
To avoid unexpected AWS costs, always destroy the resources when finished:

```shell
terraform destroy
```

Enter `yes` to confirm Terraform's plan to destroy all resources. When we return to the EC2 console, we should see that the instance is no longer running and is terminated.

## Basic Terraform Usage

As previously mentioned, the state file is stored locally by default. While this may be suitable for personal projects, the recommended approach for team environments and production workloads is to store it remotely. Using a remote backend (ex. Terraform Cloud or AWS S3) to store state files allows us to encrypt sensitive data, collaborate with other engineers, and automate infrastructure deployment.

Christiana Shedrack has a helpful article called [Managing Terraform State with AWS S3 and Native Locking](https://medium.com/@christianashedrack/managing-terraform-state-with-aws-s3-remote-backend-a-complete-guide-3fcd8c22adef) that provides additional information on how Terraform state management works, as well as a walkthrough for setting up a remote backend with AWS S3.

In this section (`03-basic-usage`), we'll setup a remote backend using AWS S3 to store our state files.

The following steps will involve making changes to the configuration files. You can use the `config-files.md` [file](./03-basic-usage/config-files.md) to check that your files are matching at each step or copy and paste.

### Provision S3 bucket
In a new directory (ex. `03-basic-usage`), we will create new configuration files.

To create an AWS S3 bucket, we'll add the following resources to our `main.tf` file:

```hcl
# main.tf

provider "aws" {
  region = "us-west-1"
}


resource "aws_s3_bucket" "ln_tf_state" {
  bucket        = "ln-tfbackend-bucket" # REPLACE (bucket names must be globally unique)
  force_destroy = true
}


resource "aws_s3_bucket_versioning" "ln_tf_bucket_versioning" {
  bucket = aws_s3_bucket.ln_tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "ln_tf_state_crypto_conf" {
  bucket = aws_s3_bucket.ln_tf_state.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

- This provisions a S3 bucket that can delete all objects so that the bucket can be destroyed without error (not recommended outside of this learning project). 
- We also enable versioning on the bucket, which preserves old versions of each object so that they can be recovered in the event of accidental overwrites or deletions.
- Finally, we secure our data with AES-256 encryption.

> Note: The course mentions provisioning a DynamoDB table as well, which would be used to lock the state file. Doing so allows only one person to modify the state file at a time, which helps avoid conflicts. With Terraform 1.10+, however, S3 now has built-in locking. Therefore, DynamoDB is not needed for this project.

Our `terraform.tf` file should be the same one as from the Terraform Overview section.

```hcl
# terraform.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}
```

Provision the S3 bucket by running the following commands:
1. `terraform init`
2. `terraform plan`
3. `terraform apply`

### AWS remote backend

We'll update the `terraform.tf` file to include `backend {}` block within the `terraform block`:

```hcl
# terraform.tf

terraform {
  required_providers {
    # [...]
  }

  backend "s3" {
    bucket       = "ln-tfbackend-bucket"
    key          = "tf-infra/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
    encrypt      = true
  }

  required_version = ">= 1.2"
}
```
- We specify the S3 bucket that we want to use for the remote backend
- We enable S3 state locking
- We enable server-side encryption of the state and lock files

When we rerun `terraform init`, Terraform will recognize that we are no longer using a local backend and have configured a remote one:

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.
  ```

Enter `yes` to copy the state file to the S3 bucket.

When we navigate to the S3 console, we should see a `terraform.tf` object within our bucket.

### Delete resources

Running `terraform destroy` while connected to the remote backend can cause some errors as Terraform will no longer be able to save the state to the now destroyed S3 bucket where we stored our `terraform.tfstate` file. We will need to pull the latest state from our remote backend and revert to using a local backend before destroying everything.

Before running `terraform destroy`:
 1. Run the following to download the state file from the remote backend

```hcl
terraform state pull > terraform.tfstate
```

 2. Comment out the `backend {}` block in the `terraform.tf` file to switch back to using local backend
 3. Run `terraform init -migrate-state`
 4. Run `terraform destroy`

## Variables and Outputs

### Variable Types

**Input variables** parameterize a Terraform configuration, allowing users to customize behavior without changing the source code. They are declared using the `variable {}` block and can be referenced using `var.<name>`.

```hcl
variable "instance_type" {
  description = "ec2 instance type"
  type = string
  default = "t3.micro"
}
```

**Local variables** assign a name to an expression's result, allowing that result to be used multiple times within a module to avoid repetition and improve readability. They are declared using the `locals {}` block and can be referenced using `local.<name>`.

```hcl
locals {
  service_name = "My Service"
  owner = "My Company"
}
```

**Output variables** function like return values in programming languages, allowing you to expose data about the resources you create. They can be used to print values after running `terraform apply` or be consumed elsewhere in a configuration file. They are declared using the `output {}` block and can be called using `terraform output <variable>`.

```hcl
output "instance_ip_addr" {
  value = aws_instance.instance.public_ip
}
```

### Setting input variables

Terraform uses the following order of precedence when assigning a value to a variable:

1. Command line using `-var` or `-var-file` parameters
2. `*.auto.tfvars` file
3. `terraform.tfvars` file
4. `TF_VAR_<name>` environment variables
5. `default` value in the `variable {}` block

### Types and Validation

Variables can hold a variety of value types:

| Primitive Types | Complex Types |
| -               | -             |
| string          | list          |
| number          | set           |
| bool            | map           |
|                 | object        |
|                 | tuple         |

Type checking happens automatically and custom conditions can be enforced.

### Managing sensitive data

Variables can be marked as sensitive by adding the `sensitive` argument to `variable {}` or `output {}` blocks. 

```hcl
variable "database_password" {
  description = "Password for the database instance"
  type        = string
  sensitive   = true
}
```

We can pass the variable at runtime. For example:

```shell
terraform apply -var="database_password=S3CR3T_P455W0RD"
```

Doing so causes Terraform to redact those values from the CLI output. 

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

database_password = (sensitive value)
```

Variables can also be passed to `terraform apply` with:
- `TF_VAR_<variable>`
- `var` (retrieved from secret manager at runtime)

We can also use an external secret store, such as AWS Secrets Manager.

### Variables Demo

`04-variables-and-outputs` contains the configuration and variable files for an infrastructure that features an EC2 and Amazon Relational Database Service (RDS) instance inside of a custom virtual private cloud (VPC). The architecture and code is based on this [Medium article](https://medium.com/strategio/using-terraform-to-create-aws-vpc-ec2-and-rds-instances-c7f3aa416133) by Matt Little.

![Architecture diagram](https://miro.medium.com/v2/resize:fit:720/format:webp/1*Oxp7FZT4Z9RWqpnJn-hHqw.png)

*Image courtesy of [Matt Little](https://github.com/dispact/terraform-custom-vpc)*

We can access the EC2 instance via SSH. From there, we'll be able to connect to the Postgres database.

The `.gitignore` file was updated to include the following:

```gitignore
# gitignore

# Terraform 
*.tfvars

# SSH keys
.ssh
*.pem
*.pub
```
#### Secrets file and environment variable

Create a `terraform.tfvars` file to assign values to our database input variables:

```hcl
# terraform.tfvars
db_name       = "mydb"
db_user       = "root"
my_ip         = "<your_ip_address>"
```

Set the environment variable for `db_pass` by running the following command in the terminal:
```shell
export TF_VAR_db_pass="SecretPassword1"
```

#### Creating SSH key pair

To securely connect to our "web server" EC2 instance via SSH, we'll need to generate a key pair. In our project directory (ex. `04-variables-and-outputs`), enter the following commands into the terminal:

```shell
# Generate authentication keys for SSH
ssh-keygen -t rsa -b 4096 -m PEM -f .ssh/ec2_kp

# Convert private key to .pem filetype
openssl rsa -in .ssh/ec2_kp -out .ssh/ec2_kp.pem

# Make the private key read-only for key owner
chmod 400 .ssh/ec2_kp.pem
```
In `main.tf`, we'll import the public key into AWS

```hcl
# main.tf

resource "aws_key_pair" "ln_ec2_kp" {
  key_name   = "ln_ec2_kp"
  public_key = file(".ssh/ec2_kp.pub")
}
```

and associate the key pair with the EC2 instance.

```hcl
# main.tf

resource "aws_instance" "ln_web_server" {
  # [...]
  key_name                    = aws_key_pair.ln_ec2_kp.key_name
  # [...]
}
```

#### Connect to EC2 and RDS instances

Run `terraform init`, `terraform plan` and `terraform apply` to create our resources. Once complete, note the `rds_endpoint = <rds_instance_hostname>` that is displayed in the terminal. We will need this value soon.

We should now be able to SSH into the EC2 instance.

```shell
ssh -i .ssh/ec2_kp.pem  ubuntu@$(terraform output -raw web_public_dns)
```

Once connected to the instance, install `psql` (a terminal-based front-end for PostgreSQL).

```shell
sudo apt install postgresql-client
```

Use the `<rds_instance_hostname>` value mentioned above and connect to our RDS instance with the following command:

```shell
psql -h <rds_instance_hostname> -p 5432 -d mydb -U root          
```

Upon a successful connection, your terminal prompt will change (ex. to `mydb=>`), and you can run SQL commands.

Enter `\q` to quit the RDS connection, and then `exit` to quit the EC2 connection.

Run `terraform destroy`.

## Modules

**Modules** are self-contained, reusable packages of Terraform configuration files used to organize, simplify, and standardize infrastructure deployments. They group resources into a single unit, which can be called using a `module {}` block. 

Every Terraform configuration has a **root module** , which consists of all the resources defined in the `.tf` files within working directory. The root module can call external modules (**child modules**) using a `module {}` block. Child modules can be stored locally within a subdirectory or remotely from a registry or a version control system (VCS).

The [Terraform Registry](https://registry.terraform.io/) is the official, public repository managed by HashiCorp for sharing Terraform providers and modules. Its pre-built infrastructure components reduce the need to write complex configuration from scratch.

```hcl
# Local path
module "web-app" {
  source = "../web-app"
}

# Terraform Registry
module "consul" {
  source = "hashicorp/consul/aws"
  version = "0.1.0"
}

# HTTPS
module "example" {
  source = "github.com/hashicorp/example?ref=v1.2.0"
}

# SSH 
module "example" {
  source = "git@github.com:hashicorp/example.git"
}
```

Input variables can be passed into child modules via the `module {}` block. This approach abstracts away complex resource logic and offers some customizability while ensuring the module remains consistent and reusable across different projects and environments.

```hcl
module "web_app" {
  source = "../web-app-module"

  # Input variables
  bucket_name = "web-app-data"
  domain      = "example.com"
  db_name     = "mydb"
  db_user     = "root"
  db_pass     = var.db_pass
}
```

### Demo
In `06-modules`, we have the configuration files for the same infrastructure described in the previous section. Here, we created a module by separating the resources from our original `main.tf` file into separate configuration files and moving them into a subdirectory (`demo-module`). 

```
demo-module
  ├── app.tf                # EC2 configuration
  ├── module-variables.tf   # Variables
  ├── network.tf            # VPC, route tables, security groups
  ├── outputs.tf            # Outputs
  ├── storage.tf            # RDS
```

The S3 backend and SSH key pair resources are kept out of the module since we only need one instance of each. By keeping them at the root level, we treat them as global resources that can be shared across all environments.

Encapsulating our configuration within a module allows us to provision two infrastructures for our `dev` and `staging` environments without having to completely recreate the resources for each environment. Instead, we can simply call the same module twice and pass in different input variables to customize environment-specific details, such as database names and passwords.

```hcl
# main.tf

module "web_app_dev" {
  source = "./demo-module"

  # Input variables
  environment_name = "dev"
  db_name          = "web_app_dev_db"
  db_user          = "root"
  db_pass          = var.dev_db_pass
  my_ip            = var.my_ip
  ssh_key_name     = aws_key_pair.ln_ec2_kp.key_name
}

module "web_app_staging" {
  source = "./demo-module"

  # Input variables
  environment_name = "staging"
  db_name          = "web_app_staging_db"
  db_user          = "root"
  db_pass          = var.staging_db_pass
  my_ip            = var.my_ip
  ssh_key_name     = aws_key_pair.ln_ec2_kp.key_name
}
```

We'll update our `terraform.tfvars` file to pass in our database passwords and IP address into the module.

```hcl
# terraform.tfvars

dev_db_pass = "SecretPassword1"
staging_db_pass = "SecretPassword2"
my_ip     = "<your_ip_address>"
```

After running `terraform init`, `terraform plan`, and `terraform apply`, we'll find two instances each of EC2, VPC, and RDS in the AWS console. We should be able to connect to each EC2 instance and RDS database.

#### Connecting to `dev` EC2 and RDS

1. Output the `dev` database's endpoint for later.

```shell
terraform output dev_rds_endpoint
```

2. SSH into the EC2 instance.

```shell
ssh -i .ssh/ec2_kp.pem  ubuntu@$(terraform output -raw dev_web_public_dns)
```

3. Once connected to the instance, install `psql`.

```shell
sudo apt install postgresql-client
```

4. Use the endpoint from step 1 to connect to the `dev` database. Recall that we specified `web_app_dev_db` as the database name in `main.tf`

```shell
psql -h <dev_rds_endpoint> -p 5432 -d web_app_dev_db -U root          
```

5. Enter the password (`SecretPassword1`) for the `dev` database, which we specified in `terraform.tfvars`.

#### Connecting to `staging` EC2 and RDS

The process for connecting to the `staging` environment resources is very similar to connecting to the `dev` environment versions.

1. Output the `staging` database's endpoint for later.

```shell
terraform output staging_rds_endpoint
```

2. SSH into the EC2 instance.

```shell
ssh -i .ssh/ec2_kp.pem  ubuntu@$(terraform output -raw staging_web_public_dns)
```

3. Once connected to the instance, install `psql`.

```shell
sudo apt install postgresql-client
```

4. Use the endpoint from step 1 to connect to the `staging` database. Recall that we specified `web_app_staging_db` as the database name in `main.tf`

```shell
psql -h <staging_rds_endpoint> -p 5432 -d web_app_staging_db -U root          
```

5. Enter the password (`SecretPassword2`) for the `staging` database, which we specified in `terraform.tfvars`.