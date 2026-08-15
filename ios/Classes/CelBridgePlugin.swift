import Flutter
import Foundation

public final class CelBridgePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "cel_bridge",
      binaryMessenger: registrar.messenger()
    )
    let instance = CelBridgePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "version":
      respond(cel_bridge_version(), result: result)
    case "runtimeInfo":
      respond(cel_bridge_runtime_info(), result: result)
    case "validate":
      guard let arguments = call.arguments as? [String: Any],
            let environment = arguments["environment"] as? String,
            let source = arguments["source"] as? String else {
        invalidArguments(result)
        return
      }
      environment.withCString { environmentPointer in
        source.withCString { sourcePointer in
          respond(
            cel_bridge_validate(environmentPointer, sourcePointer),
            result: result
          )
        }
      }
    case "evaluate":
      guard let arguments = call.arguments as? [String: Any],
            let environment = arguments["environment"] as? String,
            let source = arguments["source"] as? String,
            let variables = arguments["variables"] as? String else {
        invalidArguments(result)
        return
      }
      environment.withCString { environmentPointer in
        source.withCString { sourcePointer in
          variables.withCString { variablesPointer in
            respond(
              cel_bridge_evaluate(
                environmentPointer,
                sourcePointer,
                variablesPointer
              ),
              result: result
            )
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func invalidArguments(_ result: @escaping FlutterResult) {
    result(
      FlutterError(
        code: "invalid_request",
        message: "iOS CEL plugin arguments are invalid",
        details: nil
      )
    )
  }

  private func respond(
    _ value: UnsafeMutablePointer<CChar>?,
    result: @escaping FlutterResult
  ) {
    guard let value else {
      result(
        FlutterError(
          code: "internal_error",
          message: "iOS CEL runtime returned null",
          details: nil
        )
      )
      return
    }
    let string = String(cString: value)
    cel_bridge_free(value)
    result(string)
  }
}
