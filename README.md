# tf-gcp-infra
Repo relate Infrastructure as code with terraform 

1. Copy the `terraform.tfvars.example` to `terraform.tfvars` and fill in the required values.
2. Copy credentials.json to the downloaded path
3. brew install terraform `brew install terraform`
4. download the serverless and delete object in bucket in gcp console and reupload it.
5. Copy project id and service account key file to the root directory or download it from the GCP console.
6. Run `terrform fmt` to format the code.
7. Run `terraform init` to initialize the project.
8. Run `terraform validate` to validate the code.
9. Run `terraform plan` to see the changes that will be made.
10. Run `terraform apply` to apply the changes.
11. Once the infrastructure is created, and crossverfied through post copy keyring and cryptokey from terminal output and update the github secrets 
12. Go to the template which is create from terraform (prefix: csye6225) get the DB_HOST (GITHUB : DB_HOST_TF) and DB_PASSWROD(GITHUB : DB_PASSWORD_TF) and update the github secrets .
13. Run `terraform destroy` to destroy the infrastructure.



#### API'S Enabled 
- Compute Engine API	
- Cloud Monitoring API		
- Cloud SQL Admin API		
- Cloud Logging API		
- Cloud DNS API		
- Cloud Resource Manager API	
- Identity and Access Management (IAM) API		
- Cloud OS Login API					
- IAM Service Account Credentials API					
- Network Management API					
- Service Networking API
- Cloud Build API
- Cloud Functions API
- Cloud Logging API
- Cloud Pub/Sub API
- Eventarc API
- Cloud Pub/Sub API
- Cloud Run Admin API
- Cloud key management service API
- Cloud Storage API
- Cloud 
