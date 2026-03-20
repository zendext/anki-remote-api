package app

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/zendext/ankiconnect-relay/internal/ankiconnect"
)

type Config struct {
	ListenAddr      string
	AnkiConnectURL  string
	AnkiBase        string
	ProgramFilesDir string
}

type Server struct {
	cfg    Config
	anki   *ankiconnect.Client
	router *gin.Engine
}

func NewServer(cfg Config) *Server {
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.Logger())

	s := &Server{
		cfg:    cfg,
		anki:   ankiconnect.New(cfg.AnkiConnectURL, 30*time.Second),
		router: r,
	}
	s.routes()
	return s
}

func (s *Server) Handler() http.Handler { return s.router }

func (s *Server) routes() {
	// Relay root: fully compatible with AnkiConnect's POST /
	s.router.POST("/", s.handleRelay)

	// Internal probes under /_/ to avoid conflicting with AnkiConnect actions
	internal := s.router.Group("/_")
	internal.GET("/health", s.handleHealth)
	internal.GET("/status", s.handleStatus)
}

// handleRelay forwards the request body directly to AnkiConnect and returns
// its response verbatim. The caller sends a standard AnkiConnect envelope:
// {"action":"...","version":6,"params":{...}}
func (s *Server) handleRelay(c *gin.Context) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "read body: " + err.Error()})
		return
	}
	if len(body) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "empty body"})
		return
	}

	raw, err := s.anki.Do(c.Request.Context(), body)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}

	c.Data(http.StatusOK, "application/json; charset=utf-8", raw)
}

type statusResponse struct {
	DesktopUp          bool   `json:"desktop_up"`
	AnkiProcessRunning bool   `json:"anki_process_running"`
	AnkiconnectReady   bool   `json:"ankiconnect_ready"`
	RuntimeState       string `json:"runtime_state"`
	ManualIntervention bool   `json:"manual_intervention_required"`
	ProgramFilesReady  bool   `json:"program_files_ready"`
	AnkiStartupLog     string `json:"anki_startup_log,omitempty"`
}

func (s *Server) detectStatus(c *gin.Context) statusResponse {
	realAnki := filepath.Join(s.cfg.ProgramFilesDir, ".venv", "bin", "anki")
	startupLog := filepath.Join(s.cfg.AnkiBase, "anki-startup.log")

	_, err := os.Stat(realAnki)
	installed := err == nil

	status := statusResponse{
		DesktopUp:          true,
		RuntimeState:       "bootstrap",
		ManualIntervention: true,
		ProgramFilesReady:  installed,
	}
	if installed {
		status.RuntimeState = "installed"
	}

	if b, err := os.ReadFile(startupLog); err == nil {
		if len(b) > 4000 {
			b = b[len(b)-4000:]
		}
		status.AnkiStartupLog = string(b)
	}

	if _, err := s.anki.Version(c.Request.Context()); err == nil {
		status.AnkiconnectReady = true
		status.AnkiProcessRunning = true
		status.ManualIntervention = false
	}

	return status
}

func (s *Server) handleHealth(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (s *Server) handleStatus(c *gin.Context) {
	c.JSON(http.StatusOK, s.detectStatus(c))
}
