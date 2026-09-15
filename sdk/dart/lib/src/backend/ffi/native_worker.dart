import 'native_worker_client.dart';

Future<String> invokeNative(
  String operation, [
  String first = '',
  String second = '',
  String third = '',
  String fourth = '',
]) {
  return NativeWorkerClient.instance.invoke(
    operation,
    first,
    second,
    third,
    fourth,
  );
}

Future<void> closeNativeWorker() {
  return NativeWorkerClient.instance.close();
}

Future<void> closeNativeWorkerForTesting() => closeNativeWorker();

int nativeWorkerSpawnCountForTesting() {
  return NativeWorkerClient.instance.spawnCount;
}
