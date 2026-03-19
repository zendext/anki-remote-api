// Package ankiweb implements the AnkiWeb sync protocol client (v11).
// Reference: https://github.com/ankitects/anki/blob/main/rslib/src/sync/login.rs
package ankiweb

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/klauspost/compress/zstd"
)

const (
	defaultEndpoint = "https://sync.ankiweb.net/"
	syncVersion     = 11
	clientVersion   = "anki-remote-api/0.1"
)

// syncHeader matches the anki-sync header schema.
// Fields use short names as required by the protocol.
type syncHeader struct {
	Version    int    `json:"v"`
	Key        string `json:"k"`
	ClientVer  string `json:"c"`
	SessionKey string `json:"s"`
}

type hostKeyRequest struct {
	Username string `json:"u"`
	Password string `json:"p"`
}

type hostKeyResponse struct {
	Key string `json:"key"`
}

// Login authenticates against AnkiWeb and returns the sync hkey (host key).
// The hkey can be stored and reused; it does not expire unless the password changes.
func Login(username, password string) (string, error) {
	return LoginWithEndpoint(username, password, defaultEndpoint)
}

// LoginWithEndpoint allows specifying a custom sync server endpoint
// (e.g. a self-hosted anki-sync-server instance).
func LoginWithEndpoint(username, password, endpoint string) (string, error) {
	payload, err := json.Marshal(hostKeyRequest{Username: username, Password: password})
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	body, err := zstdCompress(payload)
	if err != nil {
		return "", fmt.Errorf("compress request: %w", err)
	}

	header := syncHeader{
		Version:    syncVersion,
		Key:        "",
		ClientVer:  clientVersion,
		SessionKey: "",
	}
	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", fmt.Errorf("marshal sync header: %w", err)
	}

	url := endpoint + "sync/hostKey"
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/octet-stream")
	req.Header.Set("anki-sync", string(headerJSON))

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("do request: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ankiweb returned %d: %s", resp.StatusCode, string(raw))
	}

	decoded, err := zstdDecompress(raw)
	if err != nil {
		return "", fmt.Errorf("decompress response: %w", err)
	}

	var hkResp hostKeyResponse
	if err := json.Unmarshal(decoded, &hkResp); err != nil {
		return "", fmt.Errorf("parse response: %w", err)
	}
	if hkResp.Key == "" {
		return "", fmt.Errorf("empty hkey in response: %s", string(decoded))
	}

	return hkResp.Key, nil
}

func zstdCompress(data []byte) ([]byte, error) {
	var buf bytes.Buffer
	w, err := zstd.NewWriter(&buf)
	if err != nil {
		return nil, err
	}
	if _, err = w.Write(data); err != nil {
		return nil, err
	}
	if err = w.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func zstdDecompress(data []byte) ([]byte, error) {
	r, err := zstd.NewReader(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	defer r.Close()
	return io.ReadAll(r)
}
