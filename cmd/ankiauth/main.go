// ankiauth retrieves an AnkiWeb sync hkey (host key) from username and password.
// The hkey can then be stored as ANKI_SYNC_HKEY and injected into the container.
//
// Usage:
//
//	ANKI_EMAIL=you@example.com ANKI_PASSWORD=secret ankiauth
//	ANKI_EMAIL=you@example.com ANKI_PASSWORD=secret ANKI_SYNC_ENDPOINT=https://my-server/ ankiauth
package main

import (
	"fmt"
	"os"

	"github.com/zendext/anki-remote-api/internal/ankiweb"
)

func main() {
	email := os.Getenv("ANKI_EMAIL")
	password := os.Getenv("ANKI_PASSWORD")
	endpoint := os.Getenv("ANKI_SYNC_ENDPOINT")

	if email == "" || password == "" {
		fmt.Fprintln(os.Stderr, "error: ANKI_EMAIL and ANKI_PASSWORD must be set")
		os.Exit(1)
	}

	var (
		hkey string
		err  error
	)
	if endpoint != "" {
		hkey, err = ankiweb.LoginWithEndpoint(email, password, endpoint)
	} else {
		hkey, err = ankiweb.Login(email, password)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(hkey)
}
