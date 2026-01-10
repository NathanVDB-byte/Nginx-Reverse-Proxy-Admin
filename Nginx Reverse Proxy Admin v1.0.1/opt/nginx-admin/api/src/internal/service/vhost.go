package service

import (
	"bytes"
	"fmt"
	"os/exec"
)

func runScript(name string, args ...string) (string, error) {
	// Lance le script avec sudo
	cmd := exec.Command("sudo", append([]string{name}, args...)...)
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return stderr.String() + out.String(), fmt.Errorf("command failed: %w", err)
	}
	return out.String(), nil
}

func CreateVhost(domain, aliases, backendHost, backendPort, extraHeaders string) (string, error) {
	return runScript(
		"/opt/nginx-admin/scripts/nginx-create-vhost.sh",
		domain, aliases, backendHost, backendPort, extraHeaders,
	)
}

func EnableVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-enable-vhost.sh", domain)
}

func DisableVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-disable-vhost.sh", domain)
}

func DeleteVhost(domain string) (string, error) {
	return runScript("/opt/nginx-admin/scripts/nginx-delete-vhost.sh", domain)
}

func SaveConf(domain, content string) (string, error) {
	// On pipe le contenu sur stdin -> script qui lit depuis stdin
	cmd := exec.Command("sudo", "/opt/nginx-admin/scripts/nginx-save-conf.sh", domain)
	cmd.Stdin = bytes.NewBufferString(content)

	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return stderr.String() + out.String(), fmt.Errorf("command failed: %w", err)
	}
	return out.String(), nil
}

func IssueCert(domain string) (string, error) {
	// Certbot aussi lancé avec sudo
	return runScript("/opt/nginx-admin/scripts/nginx-certbot.sh", domain)
}
