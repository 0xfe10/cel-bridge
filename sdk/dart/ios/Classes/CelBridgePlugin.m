#import "CelBridgePlugin.h"

#include "../../../abi/cel_bridge.h"
#import <dispatch/dispatch.h>

static FlutterError *CelBridgeError(NSString *message) {
  return [FlutterError errorWithCode:@"internal_error"
                             message:message
                             details:nil];
}

static NSString *CelBridgeJSON(char *value) {
  if (value == NULL) return nil;
  NSString *result = [NSString stringWithUTF8String:value];
  cel_bridge_free(value);
  return result;
}

static BOOL CelBridgeHasNUL(NSString *value) {
  if (value == nil) return NO;
  return [value rangeOfString:@"\0"].location != NSNotFound;
}

@implementation CelBridgePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"cel_bridge"
             binaryMessenger:[registrar messenger]];
  CelBridgePlugin *instance = [[CelBridgePlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"version"]) {
    NSString *value = CelBridgeJSON(cel_bridge_version());
    result(value ?: CelBridgeError(@"iOS CEL runtime returned invalid JSON"));
    return;
  }
  if ([call.method isEqualToString:@"runtimeInfo"]) {
    NSString *value = CelBridgeJSON(cel_bridge_runtime_info());
    result(value ?: CelBridgeError(@"iOS CEL runtime returned invalid JSON"));
    return;
  }

  if (![call.arguments isKindOfClass:[NSDictionary class]]) {
    result([FlutterError errorWithCode:@"invalid_request"
                               message:@"iOS CEL plugin arguments are invalid"
                               details:nil]);
    return;
  }
  NSDictionary *arguments = (NSDictionary *)call.arguments;
  NSString *environment = arguments[@"environment"];
  NSString *source = arguments[@"source"];
  NSString *variables = arguments[@"variables"];
  if (![environment isKindOfClass:[NSString class]] ||
      ![source isKindOfClass:[NSString class]] ||
      (variables != nil && ![variables isKindOfClass:[NSString class]]) ||
      CelBridgeHasNUL(environment) || CelBridgeHasNUL(source) ||
      CelBridgeHasNUL(variables)) {
    result([FlutterError errorWithCode:@"invalid_request"
                               message:@"iOS CEL plugin arguments are invalid"
                               details:nil]);
    return;
  }

  BOOL validate = [call.method isEqualToString:@"validate"] && variables == nil;
  BOOL evaluate = [call.method isEqualToString:@"evaluate"] && variables != nil;
  if (!validate && !evaluate) {
    result(FlutterMethodNotImplemented);
    return;
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    char *value = validate
        ? cel_bridge_validate([environment UTF8String], [source UTF8String])
        : cel_bridge_evaluate(
              [environment UTF8String], [source UTF8String],
              [variables UTF8String]);
    NSString *json = CelBridgeJSON(value);
    dispatch_async(dispatch_get_main_queue(), ^{
      result(json ?: CelBridgeError(@"iOS CEL runtime returned invalid JSON"));
    });
  });
}

@end
