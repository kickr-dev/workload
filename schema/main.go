package main

import (
	"fmt"
	"log/slog"
	"os"
	"path/filepath"

	"github.com/goccy/go-yaml"
)

func run() error {
	dir, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("get wd: %w", err)
	}

	root, err := os.OpenRoot(dir)
	if err != nil {
		return fmt.Errorf("open root: %w", err)
	}
	defer root.Close()

	in, err := root.ReadFile(filepath.Join("schema", "values.schema.yml"))
	if err != nil {
		return fmt.Errorf("read file: %w", err)
	}

	out, err := yaml.YAMLToJSON(in)
	if err != nil {
		return fmt.Errorf("yaml to json: %w", err)
	}

	if err := root.WriteFile(filepath.Join("chart", "values.schema.json"), out, 0o644); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	return nil
}

func main() {
	if err := run(); err != nil {
		slog.Error("failed to generate JSON schema", slog.Any("error", err))
		os.Exit(1)
	}
}
