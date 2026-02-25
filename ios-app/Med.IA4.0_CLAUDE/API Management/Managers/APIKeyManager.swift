import Foundation
import Security

// MARK: - API Key Manager
class APIKeyManager: ObservableObject {
    static let shared = APIKeyManager()
    
    @Published var isAPIKeyConfigured: Bool = false
    
    private let keychainService = "com.yourapp.medical-training"  // Update with your bundle ID
    private let apiKeyAccount = "claude_api_key"
    
    private init() {
        // If a key was injected via UserDefaults (e.g. xcrun simctl), promote it to Keychain
        if let injectedKey = UserDefaults.standard.string(forKey: "claude_api_key"), !injectedKey.isEmpty {
            _ = saveAPIKey(injectedKey)
            UserDefaults.standard.removeObject(forKey: "claude_api_key")
        }
        checkAPIKeyExists()
    }
    
    // MARK: - Public Methods
    
    func checkAPIKeyExists() {
        isAPIKeyConfigured = getAPIKey() != nil
    }
    
    func saveAPIKey(_ apiKey: String) -> Bool {
        let data = apiKey.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            DispatchQueue.main.async {
                self.isAPIKeyConfigured = true
            }
            return true
        } else {
            print("Error saving API key: \(status)")
            return false
        }
    }
    
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }

        // Fallback: check UserDefaults (useful for simulator testing via xcrun simctl defaults)
        if let key = UserDefaults.standard.string(forKey: "claude_api_key"), !key.isEmpty {
            return key
        }

        return nil
    }
    
    func removeAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: apiKeyAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            DispatchQueue.main.async {
                self.isAPIKeyConfigured = false
            }
            return true
        } else {
            print("Error removing API key: \(status)")
            return false
        }
    }
    
    func isValidAPIKeyFormat(_ apiKey: String) -> Bool {
        return apiKey.hasPrefix("sk-ant-") && apiKey.count >= 30
    }
}
