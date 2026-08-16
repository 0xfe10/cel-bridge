package celbridge

import "github.com/0xfe10/cel-bridge/runtime/internal/protocol"

const version = "0.1.0"
const celGoVersion = "v0.31.0"

func Version() string {
	return version
}

func RuntimeInfo() string {
	return protocol.JSON(protocol.RuntimeInfo{
		ProtocolVersion: protocol.Version,
		RuntimeVersion:  version,
		CELGoVersion:    celGoVersion,
		Features: map[string]bool{
			"checkedAstArtifact": false,
			"customFunctions":    false,
			"protoTypes":         false,
			"costLimit":          true,
		},
	})
}
