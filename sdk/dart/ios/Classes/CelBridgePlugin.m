#import "CelBridgePlugin.h"

#include "cel_bridge.h"
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

static BOOL CelBridgeInvalidString(id value) {
  if (value == nil || value == [NSNull null]) return NO;
  if (![value isKindOfClass:[NSString class]]) return YES;
  return CelBridgeHasNUL((NSString *)value);
}

static NSString *CelBridgeString(NSDictionary *arguments, NSString *key) {
  id value = arguments[key];
  if (value == nil || value == [NSNull null]) return nil;
  if (![value isKindOfClass:[NSString class]]) return nil;
  return (NSString *)value;
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
  if ([call.method isEqualToString:@"close"]) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSString *json = CelBridgeJSON(cel_bridge_close());
      dispatch_async(dispatch_get_main_queue(), ^{
        result(json ?: CelBridgeError(@"iOS CEL runtime returned invalid JSON"));
      });
    });
    return;
  }

  NSDictionary *arguments =
      [call.arguments isKindOfClass:[NSDictionary class]]
          ? (NSDictionary *)call.arguments
          : @{};
  for (NSString *key in arguments) {
    if (CelBridgeInvalidString(arguments[key])) {
      result([FlutterError errorWithCode:@"invalid_request"
                                 message:@"iOS CEL plugin arguments are invalid"
                                 details:nil]);
      return;
    }
  }

  NSString *environment = CelBridgeString(arguments, @"environment");
  NSString *source = CelBridgeString(arguments, @"source");
  NSString *sources = CelBridgeString(arguments, @"sources");
  NSString *variables = CelBridgeString(arguments, @"variables");
  NSString *options = CelBridgeString(arguments, @"options") ?: @"";
  NSString *requests = CelBridgeString(arguments, @"requests");
  NSString *programId = CelBridgeString(arguments, @"programId");
  NSString *method = call.method;

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    char *value = NULL;
    if ([method isEqualToString:@"validate"] && environment != nil &&
        source != nil) {
      value = cel_bridge_validate_options(
          [environment UTF8String], [source UTF8String], [options UTF8String]);
    } else if ([method isEqualToString:@"evaluate"] && environment != nil &&
               source != nil && variables != nil) {
      value = cel_bridge_evaluate_options(
          [environment UTF8String], [source UTF8String],
          [variables UTF8String], [options UTF8String]);
    } else if ([method isEqualToString:@"evaluateMany"] && environment != nil &&
               sources != nil && variables != nil) {
      value = cel_bridge_evaluate_many(
          [environment UTF8String], [sources UTF8String],
          [variables UTF8String]);
    } else if ([method isEqualToString:@"evaluateRequests"] &&
               environment != nil && requests != nil) {
      value = cel_bridge_evaluate_requests(
          [environment UTF8String], [requests UTF8String],
          [options UTF8String]);
    } else if ([method isEqualToString:@"prepare"] && environment != nil &&
               source != nil) {
      value = cel_bridge_prepare(
          [environment UTF8String], [source UTF8String], [options UTF8String]);
    } else if ([method isEqualToString:@"evaluateProgram"] && programId != nil &&
               variables != nil) {
      value = cel_bridge_evaluate_program(
          [programId UTF8String], [variables UTF8String],
          [options UTF8String]);
    } else if ([method isEqualToString:@"releaseProgram"] && programId != nil) {
      value = cel_bridge_release_program([programId UTF8String]);
    } else if ([method isEqualToString:@"create"]) {
      value = cel_bridge_create([options UTF8String]);
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        result(FlutterMethodNotImplemented);
      });
      return;
    }
    NSString *json = CelBridgeJSON(value);
    dispatch_async(dispatch_get_main_queue(), ^{
      result(json ?: CelBridgeError(@"iOS CEL runtime returned invalid JSON"));
    });
  });
}

@end
