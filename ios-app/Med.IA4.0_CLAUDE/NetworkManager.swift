import Foundation

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let apiKeyManager = APIKeyManager.shared
    
    private init() {}
    
    func sendClaudeRequest(
        message: String,
        systemPrompt: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let apiKey = apiKeyManager.getAPIKey() else {
            completion(.failure(NSError(domain: "No API Key", code: 0, userInfo: [NSLocalizedDescriptionKey: "No API key configured. Please set up your Claude API key."])))
            return
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL."])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let messages: [[String: Any]] = [
            ["role": "user", "content": message]
        ]
        
        var requestBody: [String: Any] = [
            "model": "claude-3-sonnet-20240229",
            "max_tokens": 1000,
            "messages": messages
        ]
        
        if let systemPrompt = systemPrompt {
            requestBody["system"] = systemPrompt
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "Invalid Response", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from API."])))
                    return
                }
                
                if httpResponse.statusCode == 401 {
                    completion(.failure(NSError(domain: "Unauthorized", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your API key."])))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "No Data", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received from API."])))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let content = json["content"] as? [[String: Any]],
                       let firstContent = content.first,
                       let text = firstContent["text"] as? String {
                        completion(.success(text))
                    } else {
                        completion(.failure(NSError(domain: "Invalid Response", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from API."])))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
