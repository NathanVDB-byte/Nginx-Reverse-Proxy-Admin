package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "strings"

    "nginx-admin-api/internal/service"
)

type Response struct {
    Ok      bool   `json:"ok"`
    Message string `json:"message"`
}

var apiKey string

func main() {
    apiKey = os.Getenv("NGINX_ADMIN_API_KEY")
    if apiKey == "" {
        log.Fatal("NGINX_ADMIN_API_KEY non défini")
    }

    mux := http.NewServeMux()

    mux.Handle("/v1/vhost/create", withAuth(handleCreate))
    mux.Handle("/v1/vhost/enable", withAuth(handleEnable))
    mux.Handle("/v1/vhost/disable", withAuth(handleDisable))
    mux.Handle("/v1/vhost/delete", withAuth(handleDelete))
    mux.Handle("/v1/vhost/save-conf", withAuth(handleSaveConf))
    mux.Handle("/v1/certbot/issue", withAuth(handleCertbot))

    addr := "127.0.0.1:9000"
    log.Printf("nginx-admin-api listening on %s", addr)
    if err := http.ListenAndServe(addr, mux); err != nil {
        log.Fatal(err)
    }
}

func withAuth(next http.HandlerFunc) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        key := r.Header.Get("X-API-Key")
        if key == "" || key != apiKey {
            w.WriteHeader(http.StatusUnauthorized)
            json.NewEncoder(w).Encode(Response{Ok: false, Message: "Unauthorized"})
            return
        }
        next.ServeHTTP(w, r)
    })
}

func parseForm(r *http.Request) error {
    if err := r.ParseForm(); err != nil {
        return err
    }
    return nil
}

func handleCreate(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }

    domain := strings.TrimSpace(r.Form.Get("domain"))
    aliases := strings.TrimSpace(r.Form.Get("aliases"))
    backendHost := strings.TrimSpace(r.Form.Get("backend_host"))
    backendPort := strings.TrimSpace(r.Form.Get("backend_port"))
    extraHeaders := r.Form.Get("extra_headers")

    if domain == "" || backendHost == "" || backendPort == "" {
        writeErr(w, "Domain, backend host et port sont obligatoires.")
        return
    }

    out, err := service.CreateVhost(domain, aliases, backendHost, backendPort, extraHeaders)
    if err != nil {
        writeErr(w, "Erreur création vhost : "+out)
        return
    }
    writeOk(w, "Vhost créé avec succès.")
}

func handleEnable(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.EnableVhost(domain)
    if err != nil {
        writeErr(w, "Erreur activation : "+out)
        return
    }
    writeOk(w, "Vhost activé.")
}

func handleDisable(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.DisableVhost(domain)
    if err != nil {
        writeErr(w, "Erreur désactivation : "+out)
        return
    }
    writeOk(w, "Vhost désactivé.")
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.DeleteVhost(domain)
    if err != nil {
        writeErr(w, "Erreur suppression : "+out)
        return
    }
    writeOk(w, "Vhost supprimé.")
}

func handleSaveConf(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := r.ParseForm(); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    content := r.Form.Get("content")
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    if content == "" {
        writeErr(w, "Contenu vide.")
        return
    }

    out, err := service.SaveConf(domain, content)
    if err != nil {
        writeErr(w, "Erreur sauvegarde / nginx -t : "+out)
        return
    }
    writeOk(w, "Configuration sauvegardée et Nginx rechargé.")
}

func handleCertbot(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        w.WriteHeader(http.StatusMethodNotAllowed)
        return
    }
    if err := parseForm(r); err != nil {
        writeErr(w, "Bad form")
        return
    }
    domain := strings.TrimSpace(r.Form.Get("domain"))
    if domain == "" {
        writeErr(w, "Domaine manquant.")
        return
    }
    out, err := service.IssueCert(domain)
    if err != nil {
        writeErr(w, "Erreur Let’s Encrypt : "+out)
        return
    }
    writeOk(w, "Let’s Encrypt lancé pour ce domaine.")
}

func writeOk(w http.ResponseWriter, msg string) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Response{Ok: true, Message: msg})
}

func writeErr(w http.ResponseWriter, msg string) {
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Response{Ok: false, Message: msg})
}
