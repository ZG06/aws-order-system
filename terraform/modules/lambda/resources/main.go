package main

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/google/uuid"
)

// OrderRequest represents the incoming API Gateway HTTP payload
type OrderRequest struct {
	ProductID string `json:"product_id"`
	Quantity  int    `json:"quantity"`
	Stock     int    `dynamodbav:"stock"`
}

type OrderItem struct {
	OrderID   string    `dynamodbav:"order_id"`
	ProductID string    `dynamodbav:"product_id"`
	Quantity  int       `dynamodbav:"quantity"`
	OrderTime time.Time `dynamodbav:"order_time"`
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

	inventoryTableName := os.Getenv("INVENTORY_TABLE_NAME")
	ordersTableName := os.Getenv("ORDERS_TABLE_NAME")

	if inventoryTableName == "" {
		inventoryTableName = "Inventory"
	}
	if ordersTableName == "" {
		ordersTableName = "Orders"
	}

	// Populate an OrderItem struct item
	orderItem := OrderItem{
		OrderID:   uuid.New().String(),
		ProductID: order.ProductID,
		Quantity:  order.Quantity,
		OrderTime: time.Now(),
	}

	// Marshal the item into a map of AttributeValue objects
	av, err := attributevalue.MarshalMap(orderItem)
	if err != nil {
		logger.Warn("Unable to marshal the order",
			slog.String("order_id", orderItem.OrderID),
			slog.String("product_id", orderItem.ProductID),
			slog.Time("order_time", orderItem.OrderTime),
		)

		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       `{"error": "Unable to marshal the order."}`,
		}, nil
	}

	input := &dynamodb.TransactWriteItemsInput{
		TransactItems: []types.TransactWriteItem{
			{
				Update: &types.Update{
					TableName: aws.String(inventoryTableName),
					Key: map[string]types.AttributeValue{
						"product_id": &types.AttributeValueMemberS{Value: order.ProductID},
					},
					UpdateExpression:    aws.String("SET stock = stock - :qty"),
					ConditionExpression: aws.String("stock >= :qty"),
					ExpressionAttributeValues: map[string]types.AttributeValue{
						":qty": &types.AttributeValueMemberN{Value: strconv.Itoa(order.Quantity)},
					},
				},
			},
			{
				Put: &types.Put{
					TableName:           aws.String(ordersTableName),
					Item:                av,
					ConditionExpression: aws.String("attribute_not_exists(order_id)"),
				},
			},
		},
	}

	_, err = dbClient.TransactWriteItems(ctx, input)
	if err != nil {
		var condErr *types.TransactionCanceledException
		if errors.As(err, &condErr) {
			if len(condErr.CancellationReasons) > 0 && condErr.CancellationReasons[0].Code != nil &&
				*condErr.CancellationReasons[0].Code == "ConditionalCheckFailed" {
				logger.Warn("Insufficient stock to fulfill order",
					slog.String("product_id", order.ProductID),
					slog.Int("requested_quantity", order.Quantity),
				)

				return events.APIGatewayProxyResponse{
					StatusCode: http.StatusConflict,
					Body:       `{"error": "Insufficient stock to fulfill order."}`,
				}, nil
			}
		}

		logger.Error("DynamoDB UpdateItem or PutItem error",
			slog.String("product_id", order.ProductID),
			slog.String("error", err.Error()),
		)
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Body:       `{"error": "Failed to process order."}`,
		}, nil
	}

	// Extract new stock level from response
	result, err := dbClient.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: aws.String(inventoryTableName),
		Key: map[string]types.AttributeValue{
			"product_id": &types.AttributeValueMemberS{Value: order.ProductID},
		},
		ConsistentRead: aws.Bool(true),
	})

	var newStock int

	if err != nil {
		logger.Warn("Unable to extract remaning items in stock from DynamoDB",
			slog.String("error", err.Error()),
		)
	} else if result == nil || result.Item == nil {
		logger.Warn("Couldn't find the product in DynamoDB",
			slog.String("product_id", order.ProductID),
		)
	} else {
		item := OrderRequest{}

		err = attributevalue.UnmarshalMap(result.Item, &item)
		if err != nil {
			logger.Warn("Unable to unmarshal DynamoDB items",
				slog.String("error", err.Error()),
			)
		}

		newStock = item.Stock
	}

	responseBody, _ := json.Marshal(map[string]interface{}{
		"message":    "Order processed successfully",
		"product_id": order.ProductID,
		"order_id":   orderItem.OrderID,
		"order_time": orderItem.OrderTime,
		"remaining":  newStock,
	})

	logger.Info("Order processed and added to DB successfully",
		slog.String("product_id", orderItem.ProductID),
		slog.String("order_id", orderItem.OrderID),
		slog.Time("order_time", orderItem.OrderTime),
		slog.Int("quantity", order.Quantity),
		slog.Int("remaining_stock", newStock),
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
