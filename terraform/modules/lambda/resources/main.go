package main

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"strconv"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

// OrderRequest represents the incoming API Gateway HTTP payload
type OrderRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
}

var dbClient *dynamodb.Client

var logger *slog.Logger

func init() {
	ctx := context.Background()

	logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))

	// Load standard AWS configuration
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("us-east-1"))
	if err != nil {
		logger.Error("unable to load SDK config", slog.String("error", err.Error()))
	}

	// Override base endpoint if running locally against LocalStack
	localstackURL := os.Getenv("LOCALSTACK_ENDPOINT")
	if localstackURL != "" {
		dbClient = dynamodb.NewFromConfig(cfg, func(o *dynamodb.Options) {
			o.BaseEndpoint = aws.String(localstackURL)
		})
	} else {
		dbClient = dynamodb.NewFromConfig(cfg)
	}
}

func handleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	var order OrderRequest
	err := json.Unmarshal([]byte(request.Body), &order)
	if err != nil || order.ProductID == "" || order.Quantity <= 0 {
		errMsg := "invalid payload format or missing required fields"
		if err != nil {
			errMsg = err.Error()
		}

		logger.Warn("Invalid JSON payload",
			slog.String("product_id", order.ProductID),
			slog.String("error", errMsg),
		)

		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusBadRequest,
			Body:       `{"error": "Invalid payload. 'product_id' and a positive 'quantity' are required."}`,
		}, nil
	}

	tableName := os.Getenv("TABLE_NAME")
	if tableName == "" {
		tableName = "Inventory"
	}

	// Atomic conditional update: deduct stock only if sufficient stock exists
	input := &dynamodb.UpdateItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"product_id": &types.AttributeValueMemberS{Value: order.ProductID},
		},
		UpdateExpression:    aws.String("SET stock = stock - :qty"),
		ConditionExpression: aws.String("stock >= :qty"),
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":qty": &types.AttributeValueMemberN{Value: strconv.Itoa(order.Quantity)},
		},
		ReturnValues: types.ReturnValueUpdatedNew,
	}

	result, err := dbClient.UpdateItem(ctx, input)
	if err != nil {
		var condErr *types.ConditionalCheckFailedException
		if errors.As(err, &condErr) {
			logger.Warn("Insufficient stock to fulfill order",
				slog.String("product_id", order.ProductID),
				slog.Int("requested_quantity", order.Quantity),
			)

			return events.APIGatewayProxyResponse{
				StatusCode: http.StatusConflict,
				Body:       `{"error": "Insufficient stock to fulfill order."}`,
			}, nil
		}

		logger.Error("DynamoDB UpdateItem error",
			slog.String("product_id", order.ProductID),
			slog.String("error", err.Error()),
		)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       `{"error": "Failed to process order."}`,
		}, nil
	}

	// Extract new stock level from response
	newStock := result.Attributes["stock"].(*types.AttributeValueMemberN).Value
	responseBody, _ := json.Marshal(map[string]interface{}{
		"message":    "Order processed successfully",
		"product_id": order.ProductID,
		"remaining":  newStock,
	})

	logger.Info("Order processed successfully",
		slog.String("product_id", order.ProductID),
		slog.Int("quantity", order.Quantity),
		slog.String("remaining_stock", newStock),
	)

	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    map[string]string{"Content-Type": "application/json"},
		Body:       string(responseBody),
	}, nil
}

func main() {
	lambda.Start(handleRequest)
}
