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

type Envelope struct {
    Action  string      `json:"action"`
    Version int         `json:"version"`
    Params  interface{} `json:"params,omitempty"`
}

type Response struct {
    Result json.RawMessage `json:"result"`
    Error  interface{}     `json:"error"`
}

type VersionResult int

func New(baseURL string, timeout time.Duration) *Client {
    return &Client{
        baseURL: baseURL,
        httpClient: &http.Client{
            Timeout: timeout,
        },
    }
}

func (c *Client) Do(ctx context.Context, action string, params interface{}, out interface{}) error {
    payload := Envelope{Action: action, Version: 6, Params: params}
    body, err := json.Marshal(payload)
    if err != nil {
        return fmt.Errorf("marshal request: %w", err)
    }

    req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL, bytes.NewReader(body))
    if err != nil {
        return fmt.Errorf("build request: %w", err)
    }
    req.Header.Set("Content-Type", "application/json")

    resp, err := c.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("post anki connect: %w", err)
    }
    defer resp.Body.Close()

    raw, err := io.ReadAll(resp.Body)
    if err != nil {
        return fmt.Errorf("read response: %w", err)
    }

    if resp.StatusCode < 200 || resp.StatusCode >= 300 {
        return fmt.Errorf("anki connect http %d: %s", resp.StatusCode, string(raw))
    }

    var envelopeResp Response
    if err := json.Unmarshal(raw, &envelopeResp); err != nil {
        return fmt.Errorf("decode response: %w", err)
    }
    if envelopeResp.Error != nil {
        return fmt.Errorf("anki connect error: %v", envelopeResp.Error)
    }
    if out != nil {
        if err := json.Unmarshal(envelopeResp.Result, out); err != nil {
            return fmt.Errorf("decode result: %w", err)
        }
    }
    return nil
}

func (c *Client) Version(ctx context.Context) (int, error) {
    var version int
    if err := c.Do(ctx, "version", nil, &version); err != nil {
        return 0, err
    }
    return version, nil
}

func (c *Client) DeckNames(ctx context.Context) ([]string, error) {
    var decks []string
    if err := c.Do(ctx, "deckNames", nil, &decks); err != nil {
        return nil, err
    }
    return decks, nil
}
