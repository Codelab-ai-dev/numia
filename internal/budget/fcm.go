package budget

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// FCMClient wraps the Firebase Cloud Messaging client.
type FCMClient struct {
	client *messaging.Client
}

// NewFCMClient creates a new FCMClient using the credentials file at credentialsPath.
// Returns nil if credentialsPath is empty (graceful degradation — notifications are disabled).
func NewFCMClient(credentialsPath string) *FCMClient {
	if credentialsPath == "" {
		log.Println("FCM: no credentials path provided, push notifications disabled")
		return nil
	}
	ctx := context.Background()
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credentialsPath))
	if err != nil {
		log.Printf("FCM: failed to initialise Firebase app: %v", err)
		return nil
	}
	mc, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("FCM: failed to get Messaging client: %v", err)
		return nil
	}
	return &FCMClient{client: mc}
}

// Send sends a push notification to a single FCM device token.
// Errors are logged but not returned so the caller is never blocked.
func (f *FCMClient) Send(ctx context.Context, token, title, body string) error {
	if f == nil || f.client == nil {
		return nil
	}
	msg := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
	}
	_, err := f.client.Send(ctx, msg)
	if err != nil {
		log.Printf("FCM: send error (token=%s): %v", token, err)
	}
	return err
}
