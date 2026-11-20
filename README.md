# Real-Time Order & Inventory System

A serverless microservice built with Go, AWS Lambda, DynamoDB, and API Gateway. Fully provisioned and managed via Terraform Infrastructure as Code (IaC) with structured `slog` telemetry and automated observability.

---

## 🏗 Architecture Overview

![AWS Serverless Architecture Diagram](https://i.imgur.com/G2hOc0H.jpeg "An AWS diagram showing the cloud infrastructure of the project")

### System Flow
1. **API Gateway (Edge Layer):** Acts as an entry bridge (`POST /order`), filtering out unmapped methods (`GET`, `PUT`) to prevent unnecessary compute invocation.
2. **Lambda Pre-Validation (Compute Layer):** Ensures that the data provided by the API Gateway is valid (`product_id`, `quantity`), otherwise returns an error immediately. Then connects to DynamoDB to get/put/update an item and redirects the response to the API Gateway.
3. **DynamoDB Transaction (Data Layer):** Stores the items in stock and orders and executes an atomic conditional deduction. If stock is insufficient or order placement fails, DynamoDB rejects the write and Lambda return an error.
4. **SNS Email Order Notifications:** Sends an email to the administrator when a new order is received.
5. **Observability:** Structured JSON logs stream to CloudWatch Logs (14-day retention), while CloudWatch Alarms monitor runtime errors.

---

## 🛠 Tech Stack

* **Language:** Go (custom `bootstrap` binary)
* **API Routing:** AWS API Gateway
* **Item validation:** AWS Lambda
* **Database:** AWS DynamoDB
* **Notifications:** AWS DynamoDB Streams, AWS EventBridge Pipe, AWS SNS
* **Infrastructure as Code:** Terraform (modules: `dynamodb`, `iam`, `lambda`, `apigateway`, `pipes`, `sns`)
* **Observability:** Go `log/slog`, CloudWatch Logs, CloudWatch Metric Alarms

---

## 🔒 Security & Networking Design

### Application & Runtime Security
- **VPC-Free Serverless Architecture:** Lambda runs on the AWS public network without having to deploy VPC and manually manage server security (Networking, OS updates, Security Patches). In addition to that, running code on Golang minimizes the cold-start latencies.
- **DynamoDB Atomic Transactions:** Using DynamoDB ensures high reliability, because if the traffic suddenly spikes, and two identical orders are placed at the same time with only 1 item available in stock, DynamoDB millisecond response and conditional expressions will not allow the items to be ordered. In addition to that, different products have different JSON schemas, and a non-relational database, like DynamoDB, allows storing them without additional complexity.
- **No-Code Reliable Notifications:** DynamoDB Streams send a stream to EventBridge Pipes, which saves costs by filtering events (e.g. `INSERT`) and retries failed deliveries automatically. It also doesn't require custom code and maintenance. Then EventBridge sends the stream to SNS, which delivers an email to the administrator.

### CI/CD Security & Least-Privilege IAM
- **Keyless Authentication (OIDC):** GitHub Actions authenticates to AWS via OpenID Connect identity provider scoped strictly to this repository, eliminating the need for `AWS_ACCESS_KEY_ID` secrets.
- **Least-Privilege Policy Generation:** Rather than using broad managed policies like `AdministratorAccess`, `terraform/iac-bootstrap/resources/policy.json` was created by tracking calls with AWS CloudTrail and [iamlive](https://github.com/iann0036/iamlive/), then tightening resource ARNs to this project's specific resources.

---

## 📊 Cost Estimation & Scaling Analysis

The architecture utilizes the On-Demand pricing model, removing the costs in idle periods.

### Free Tier Capabilities

The Free Tier partially allows the free-of-charge usage for the first 6 months.

* **Lambda:** 1,000,000 requests/month + 400,000 GB-seconds of compute time per month.
* **DynamoDB (WRU/RRU):** 25 GB storage + 25 WCU / 25 RCU (~200M requests/month).
* **DynamoDB Streams Reads:** 2.5M read requests/month.
* **API Gateway:** 1,000,000 HTTP API calls/month (first 6 months).
* **EventBridge Pipes:** No free tier available.
* **SNS Publish Requests:** 1,000,000 free requests/month
* **SNS Email Deliveries:** 1,000 free email notification per month.

### Post-Free Tier Monthly Cost Projections

| Component | 100k Requests / Month | 1M Requests / Month | Pricing Basis |
| --- | --- | --- | --- |
| **API Gateway** | $0.10 | $1.00 | $1.00 per 1M HTTP requests |
| **AWS Lambda** | $0.02 | $0.20 | $0.20 per 1M requests (Compute time fits free memory tier) |
| **DynamoDB (WRU/RRU)** | $0.075 | $0.75 | $0.625/M write units + $0.125/M read units |
| **DynamoDB Storage** | $0.00 | $0.00 | Under 25 GB free storage tier (~1 KB / order) |
| **DynamoDB Streams Reads** | $1.60 | $1.60 | Under 2.5M free read requests/month tier ($0.02 per 100,000 read requests/month above that allowance). EventBridge Pipes poll DynamoDB shards 4 times a second 24/7, which will result in ~10.37M reads per 30-day month |
| **EventBridge Pipes** | $0.04 | $0.40 | $0.40 per million requests |
| **SNS Publish Requests** | $0.00 | $0.00 | Under 1M/month free tier ($0.50 per 1M requests above that allowance) |
| **SNS Email Deliveries** | $1.98 | $19.98 | Under 1,000 emails/month free tier ($2.00 per 100,000 above that allowance) |
| **Total Estimated Cost** | **~$3.80 / month** | **~$24 / month** | |

The pricing above is specified for the us-east-1 region and is valid as of: `November 11, 2026`.

---

## 📈 Observability & CloudWatch Insights

### Log Retention Management
To eliminate unexpected storage charges from orphan log groups, CloudWatch retention is explicitly managed via Terraform:
```hcl
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.order_processor.function_name}"
  retention_in_days = 14
}
```

### Metrics & Alarming

A metric alarm triggers on unhandled 5xx Lambda execution errors:
* **Metric:** AWS/Lambda -> Errors
* **Evaluation Period:** 1 period of 300 seconds (5 minutes)
* **Threshold:** > 1 error triggers ALARM state.

### CloudWatch Logs Insights Querying

Because the Go handler utilizes structured log/slog output, logs can be queried directly by field attributes:
```plaintext
fields @timestamp, level, msg, product_id, quantity, remaining_stock, error
| filter ispresent(product_id)
| sort @timestamp desc
| limit 20
```

## 🚀 Deployment Instructions

### 1. Create an S3 Bucket for Terraform State Storage
```bash
aws s3api create-bucket --bucket order-system-terraform-state-storage --region us-east-1
aws s3api put-bucket-versioning --bucket order-system-terraform-state-storage --versioning-configuration Status=Enabled
```

### 2. Create Terraform Roles and Policies

```bash
cd terraform/iac-bootstrap
terraform init
terraform apply
```

### 3. Build the Go Executable
```bash
cd ..
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap modules/lambda/resources/main.go
zip modules/lambda/resources/function.zip bootstrap && rm bootstrap
```

### 4. Provision Infrastructure via Terraform
```bash
export TF_VAR_alert_email=<YOUR_EMAIL_ADDRESS_FOR_ORDER_NOTIFICATIONS>
terraform init
terraform apply
```

### 5. Test Execution
A confirmation email will be sent to the provided email address. It needs to be confirmed before testing the order feature.
```bash
curl -X POST <API_GATEWAY_ENDPOINT_URL>/order \
  -H "Content-Type: application/json" \
  -d '{"product_id": "prod-101", "quantity": 2}'
```

The `API_GATEWAY_ENDPOINT_URL` will be outputted to your console upon the completion of the `terraform apply` command.