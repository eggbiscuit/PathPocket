// Demo build switch: --dart-define=USE_MOCK=true runs fully client-side
// (mock auth + chat), no backend needed — used for the GitHub Pages showcase.
const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// PathPocket FastAPI backend. Override at build time, e.g.
// --dart-define=BACKEND_BASE_URL=https://your-host
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// WebSocket base for the /asr streaming endpoint — http→ws, https→wss.
String get backendWsUrl =>
    backendBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
const String apiEndpoint = 'https://api.openai.com/v1/chat/completions';
const String apiKey = 'YOUR_API_KEY'; // replace with your OpenAI key
const String model = 'gpt-4o';
const String systemPrompt =
    'You are PathPocket, an AI medical assistant specializing in pathology. '
    'Help doctors and medical students with diagnosis, pathological analysis, '
    'and clinical reasoning. Be concise and cite evidence when possible.';
