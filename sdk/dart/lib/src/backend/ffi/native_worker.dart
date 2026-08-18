import 'native_worker_client.dart';

Future<String> invokeNative(
  String operation, [
  String first = '',
  String second = '',
  String third = '',
]) {
  return NativeWorkerClient.instance.invoke(operation, first, second, third);
}

Future<void> closeNativeWorkerForTesting() {
  return NativeWorkerClient.instance.closeForTesting();
}

int nativeWorkerSpawnCountForTesting() {
  return NativeWorkerClient.instance.spawnCount;
}
