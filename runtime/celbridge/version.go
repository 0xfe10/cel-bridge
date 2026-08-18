package celbridge

import (
	"github.com/0xfe10/cel-bridge/runtime/internal/protocol"
	"github.com/0xfe10/cel-bridge/runtime/internal/runtime"
)

const version = "0.5.0"
const celGoVersion = "v0.31.0"

func Version() string {
	return version
}

func RuntimeInfo() string {
	rt := currentRuntime()
	return protocol.JSON(protocol.RuntimeInfo{
		ProtocolVersion: protocol.Version,
		ABIVersion:      protocol.ABIVersion,
		RuntimeVersion:  version,
		CELGoVersion:    celGoVersion,
		Features: map[string]bool{
			"checkedAstArtifact": false,
			"customFunctions":    false,
			"protoTypes":         false,
			"costLimit":          true,
			"expectedResultType": true,
			"perRequestBatch":    true,
			"preparedPrograms":   true,
			"deadlines":          true,
		},
		Profiles: []string{runtime.ProfileDefault, runtime.ProfileSafe, runtime.ProfileTrusted},
		Limits:   rt.Limits().Public(),
	})
}
