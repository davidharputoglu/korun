class OtkenConfig {
  final String dataDir;
  const OtkenConfig({required this.dataDir});
}

Future<OtkenConfig> loadOtkenConfig() async {
  return const OtkenConfig(dataDir: '/tmp/korun-otken');
}

Future<void> runOtkenDaemon(OtkenConfig cfg) async {
  // TODO: implémenter le daemon Ötken complet
  print('Ötken daemon started with dataDir: ${cfg.dataDir}');
  await Future.delayed(const Duration(days: 365));
}
