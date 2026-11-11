# Real-Time Order & Inventory System

A serverless microservice built with Go, AWS Lambda, DynamoDB, and API Gateway. Fully provisioned and managed via Terraform Infrastructure as Code (IaC) with structured `slog` telemetry and automated observability.

---

## 🏗 Architecture Overview

![alt text](https://i.imgur.com/pWaVgXR.png "An AWS diagram showing the cloud infrastructure of the project")

### System Flow
1. **API Gateway (Edge Layer):** Acts as an entry bridge (`POST /order`), filtering out unmapped methods (`GET`, `PUT`) to prevent unnecessary compute invocation.
2. **Lambda Pre-Validation (Compute Layer):** Ensures that the data provided by the API Gateway is valid (`product_id`, `quantity`), otherwise returns an error immediately. Then connects to DynamoDB to get/put/update an item and redirects the response to the API Gateway.
3. **DynamoDB Transaction (Data Layer):** Stores the items in stock and executes an atomic conditional deduction. If stock is insufficient, DynamoDB rejects the write and Lambda return an error.
4. **Observability:** Structured JSON logs stream to CloudWatch Logs (14-day retention), while CloudWatch Alarms monitor runtime errors.

---

## 🛠 Tech Stack

* **Language:** Go (custom `bootstrap` binary)
* **API Routing:** AWS API Gateway
* **Item validation** AWS Lambda
* **Database:** AWS DynamoDB
* **Infrastructure as Code:** Terraform (modules: `dynamodb`, `iam`, `lambda`, `apigateway`)
* **Observability:** Go `log/slog`, CloudWatch Logs, CloudWatch Metric Alarms

---

## 🔒 Security & Networking Design

* **Serverless Model:** Lambda runs on the AWS public network without having to deploy VPC and manually manage server security (Networking, OS updates, Security Patches). In addition to that, running serverless minimizes the cold-start latencies and infrastructure costs.
* **Principle of Least Privilege:**
  * Lambda is only allowed to execute `dynamodb:GetItem`, `dynamodb:PutItem`, and `dynamodb:UpdateItem` operation on the specific DynamoDB table, which only contains the items in stock.
  * CloudWatch permission are restricted to logging actions: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`.

---

## 📊 Cost Estimation & Scaling Analysis

The architecture utilizes the On-Demand pricing model, removing the costs in idle periods.

### Free Tier Capabilities

The Free Tier allows the free-of-charge usage for the first 6 months.

* **Lambda:** 1,000,000 requests/month + 400,000 GB-seconds of compute time per month.
* **DynamoDB:** 25 GB storage + 25 WCU / 25 RCU (~200M requests/month).
* **API Gateway:** 1,000,000 HTTP API calls/month (first 6 months).

### Post-Free Tier Monthly Cost Projections

| Component | 100k Requests / Month | 1M Requests / Month | Pricing Basis |
| --- | --- | --- | --- |
| **API Gateway** | $0.10 | $1.00 | $1.00 per 1M HTTP requests |
| **AWS Lambda** | $0.02 | $0.20 | $0.20 per 1M requests (Compute time fits free memory tier) |
| **DynamoDB (WRU/RRU)** | $0.075 | $0.75 | $0.625/M write units + $0.125/M read units |
| **DynamoDB Storage** | $0.00 | $0.00 | Under 25 GB free storage tier (~1 KB / order) |
| **Total Estimated Cost** | **~$0.20 / month** | **~$1.95 / month** | |

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

## 🔍 Problems Solved
During deployment, execution failed when processing stock deductions, returning an `AccessDeniedException` error in CloudWatch:
```plaintext
api error AccessDeniedException: User: arn:aws:sts::...:assumed-role/... is not authorized to perform:
dynamodb:UpdateItem on resource: arn:aws:dynamodb:...:table/Inventory
```

### Root Cause Analysis
The Go function had to get the table name from an environment variable, which was set by terraform during the infrastructure setup process:
```go
tableName := os.Getenv("TABLE_NAME")
if tableName == "" {
    tableName = "Inventory"
}
```

However, the UpdateItem struct passed a hardcoded string `aws.String("Inventory")` instead of `aws.String(tableName)`:
```go
TableName: aws.String("Inventory")
```

Because of that, the attempts to change the Inventory table wasn't successfull, as the IAM execution policy rejected the call.

### Resolution
Updated `UpdateItemInput` to take the variable instead of the hardcoded string:
```go
TableName: aws.String(tableName)
```

After recompiling the binary, updating `function.zip`, and re-applying Terraform, the function successfully resolved the environment-provided table ARN.

## 🚀 Deployment Instructions

### 1. Build the Go Executable
```bash
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap terraform/modules/lambda/resources/main.go
zip modules/lambda/resources/function.zip bootstrap
```

### 2. Provision Infrastructure via Terraform
```bash
cd terraform
terraform init
terraform apply
```

### 3. Test Execution
```bash
curl -X POST <API_GATEWAY_ENDPOINT_URL>/order \
  -H "Content-Type: application/json" \
  -d '{"product_id": "prod-101", "quantity": 2}'
```

The `API_GATEWAY_ENDPOINT_URL` will be outputted to your console upon the completion of the `terraform apply` command.