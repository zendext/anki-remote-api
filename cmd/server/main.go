package main

import (
	"log"
	"net/http"
	"os"

	"github.com/zendext/ankiconnect-relay/internal/app"
)

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	cfg := app.Config{
		ListenAddr:      getenv("LISTEN_ADDR", ":8080"),
		AnkiConnectURL:  getenv("ANKICONNECT_URL", "http://127.0.0.1:8765"),
		AnkiBase:        getenv("ANKI_BASE", "/anki-data"),
		ProgramFilesDir: getenv("ANKI_PROGRAM_FILES_DIR", "/home/anki/.local/share/AnkiProgramFiles"),
	}

	srv := app.NewServer(cfg)
	log.Printf("listening on %s → ankiconnect %s", cfg.ListenAddr, cfg.AnkiConnectURL)
	if err := http.ListenAndServe(cfg.ListenAddr, srv.Handler()); err != nil {
		log.Fatal(err)
	}
}
