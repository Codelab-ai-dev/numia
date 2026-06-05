package coach

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const (
	groqAPIURL = "https://api.groq.com/openai/v1/chat/completions"
	groqModel  = "llama-3.3-70b-versatile"
)

// groqMessage is a single message in the Groq chat format.
type groqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// groqRequest is the request body sent to the Groq API.
type groqRequest struct {
	Model    string        `json:"model"`
	Messages []groqMessage `json:"messages"`
	Stream   bool          `json:"stream"`
}

// groqDelta holds the delta content from a streaming chunk.
type groqDelta struct {
	Content string `json:"content"`
}

// groqChoice holds a single choice from a streaming chunk.
type groqChoice struct {
	Delta        groqDelta `json:"delta"`
	FinishReason *string   `json:"finish_reason"`
}

// groqChunk is a single SSE chunk from the Groq API.
type groqChunk struct {
	Choices []groqChoice `json:"choices"`
}

// GroqClient is an HTTP client for the Groq API.
type GroqClient struct {
	apiKey     string
	httpClient *http.Client
}

// NewGroqClient creates a new GroqClient with the given API key.
func NewGroqClient(apiKey string) *GroqClient {
	return &GroqClient{
		apiKey:     apiKey,
		httpClient: &http.Client{},
	}
}

// StreamChat sends messages to Groq and streams the response token by token.
// onToken is called for each content token received.
// onDone is called with the full accumulated response when the stream ends.
func (g *GroqClient) StreamChat(ctx context.Context, messages []groqMessage, onToken func(string), onDone func(fullResponse string)) error {
	reqBody := groqRequest{
		Model:    groqModel,
		Messages: messages,
		Stream:   true,
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return fmt.Errorf("marshal groq request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, groqAPIURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("create groq request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+g.apiKey)

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("groq http request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("groq api error %d: %s", resp.StatusCode, string(body))
	}

	var fullResponse strings.Builder
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			break
		}
		if data == "" {
			continue
		}

		var chunk groqChunk
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}

		for _, choice := range chunk.Choices {
			token := choice.Delta.Content
			if token != "" {
				fullResponse.WriteString(token)
				onToken(token)
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("reading groq stream: %w", err)
	}

	onDone(fullResponse.String())
	return nil
}
