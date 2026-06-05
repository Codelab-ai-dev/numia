package coach

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const groqVisionModel = "llama-4-scout-17b-16e-instruct"

// visionImageURL is the image_url payload (a data URL with base64 content).
type visionImageURL struct {
	URL string `json:"url"`
}

// visionContentPart is one item in a multimodal message content array.
type visionContentPart struct {
	Type     string          `json:"type"`
	Text     string          `json:"text,omitempty"`
	ImageURL *visionImageURL `json:"image_url,omitempty"`
}

// visionMessage is a chat message whose content is an array of parts.
type visionMessage struct {
	Role    string              `json:"role"`
	Content []visionContentPart `json:"content"`
}

// visionResponseFormat forces a JSON object response.
type visionResponseFormat struct {
	Type string `json:"type"`
}

// visionRequest is the request body for a non-streaming vision call.
type visionRequest struct {
	Model          string               `json:"model"`
	Messages       []visionMessage      `json:"messages"`
	ResponseFormat visionResponseFormat `json:"response_format"`
	Stream         bool                 `json:"stream"`
}

// visionResponse is the relevant subset of the chat completion response.
type visionResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

// VisionJSON sends an image (as a data URL) plus a prompt to the Groq vision
// model and returns the raw JSON string the model produces. Non-streaming.
func (g *GroqClient) VisionJSON(ctx context.Context, prompt, imageDataURL string) (string, error) {
	reqBody := visionRequest{
		Model: groqVisionModel,
		Messages: []visionMessage{
			{
				Role: "user",
				Content: []visionContentPart{
					{Type: "text", Text: prompt},
					{Type: "image_url", ImageURL: &visionImageURL{URL: imageDataURL}},
				},
			},
		},
		ResponseFormat: visionResponseFormat{Type: "json_object"},
		Stream:         false,
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal vision request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, groqAPIURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create vision request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+g.apiKey)

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("vision http request: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("groq vision api error %d: %s", resp.StatusCode, string(body))
	}

	var vr visionResponse
	if err := json.Unmarshal(body, &vr); err != nil {
		return "", fmt.Errorf("unmarshal vision response: %w", err)
	}
	if len(vr.Choices) == 0 {
		return "", fmt.Errorf("vision response had no choices")
	}
	return vr.Choices[0].Message.Content, nil
}
