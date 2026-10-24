package workload

import (
	"embed"
	"io/fs"
	"regexp"
	"runtime/debug"
	"strings"
)

//go:generate go run ./schema

//go:embed chart/values.schema.json chart/values.yaml
var embedded embed.FS

var _ fs.FS = (*embed.FS)(nil) // ensure interface is implemented

// pseudoVersion matches the timestamp and revision suffix of the three Go pseudo-version forms:
//   - X.0.0-20060102150405-abcdefabcdef, without base version.
//   - X.Y.Z-pre.0.20060102150405-abcdefabcdef, with a pre-release base version.
//   - X.Y.Z-0.20060102150405-abcdefabcdef, with a release base version.
var pseudoVersion = regexp.MustCompile(`[-.](0\.)?\d{14}-\w+$`)

// FS returns the embedded chart files:
//   - chart/values.schema.json, the chart values JSON schema.
//   - chart/values.yaml, the example values with one sample entry per workload kind.
func FS() fs.FS {
	return embedded
}

// Version returns the chart version matching the embedded schema.
//
// Module and chart share a version, which it reads from the running binary's build info.
// It strips the "v" prefix, the Go pseudo-version suffix and the build metadata,
// so "v1.0.0-rc.1.0.20060102150405-abcdef123456+dirty" gives "1.0.0-rc.1".
//
// When the binary doesn't depend on this module, it returns an empty string.
func Version() string {
	return version(debug.ReadBuildInfo)
}

func version(readBuildInfo func() (*debug.BuildInfo, bool)) string { //nolint:revive
	info, ok := readBuildInfo()
	if !ok {
		return ""
	}
	for _, dep := range info.Deps {
		if dep.Path == "gitlab.com/kickr-dev/workload" {
			version, _, _ := strings.Cut(strings.TrimPrefix(dep.Version, "v"), "+")
			return pseudoVersion.ReplaceAllString(version, "")
		}
	}
	return ""
}
