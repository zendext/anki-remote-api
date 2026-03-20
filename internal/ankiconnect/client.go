package ankiconnect

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func New(baseURL string, timeout time.Duration) *Client {
	return &Client{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

// Do relays a raw AnkiConnect request and returns the raw response body.
func (c *Client) Do(ctx context.Context, body []byte) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("post ankiconnect: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}
	return raw, nil
}

// invoke is an internal helper used only by status probes.
func (c *Client) invoke(ctx context.Context, action string, params interface{}, out interface{}) error {
	envelope := struct {
		Action  string      `json:"action"`
		Version int         `json:"version"`
		Params  interface{} `json:"params,omitempty"`
	}{Action: action, Version: 6, Params: params}

	body, err := json.Marshal(envelope)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	raw, err := c.Do(ctx, body)
	if err != nil {
		return err
	}

	var r struct {
		Result json.RawMessage `json:"result"`
		Error  interface{}     `json:"error"`
	}
	if err := json.Unmarshal(raw, &r); err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	if s, ok := r.Error.(string); ok && s != "" {
		return fmt.Errorf("ankiconnect: %s", s)
	}
	if out != nil {
		return json.Unmarshal(r.Result, out)
	}
	return nil
}

// Version probes AnkiConnect and returns its version number.
// Used internally by the /_/status endpoint.
func (c *Client) Version(ctx context.Context) (int, error) {
	var v int
	return v, c.invoke(ctx, "version", nil, &v)
}
