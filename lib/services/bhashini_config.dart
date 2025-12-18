class BhashiniConfig {
  static const String userId = '481d81f3bbfc4bab880b7189394ffc1b';
  static const String apiKey = '48624f10dd-646d-45c3-acf8-3b686173aa5c'; // Udyat Key
  static const String serviceId = ''; // Will be determined dynamically or hardcoded if specific
  static const String pipelineId = '64392f96daac500b55c543cd'; // Initial Pipeline Models (ASR, Trans, TTS)
  
  // Endpoints
  static const String getPipelineUrl = 'https://meity-auth.ulcacontrib.org/ulca/apis/v0/model/getModelsPipeline';
  // Compute URL is dynamic based on pipeline config response, but base might be:
  // https://dhruva-api.bhashini.gov.in/services/inference/pipeline
}
