import Foundation

enum APIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case noData
    case invalidResponse
    case networkError(Error)
    case invalidURL
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please enter your Claude API key in settings."
        case .invalidAPIKey:
            return "Invalid API key format. Please check your Claude API key."
        case .noData:
            return "No data received from API."
        case .invalidResponse:
            return "Invalid response from API."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid API URL."
        case .unauthorized:
            return "Unauthorized. Please check your API key."
        }
    }
}
