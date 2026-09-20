import Foundation

class XIAOBridge {
    private var secret: String?
    private let xiaoURL = "http://172.31.254.1/input"
    
    func setSecret(_ secret: String) {
        self.secret = secret
    }
    
    func sendInput(hex: String, completion: @escaping (Bool, String?) -> Void) {
        guard let secret = secret else {
            completion(false, "No secret set")
            return
        }
        
        guard let url = URL(string: xiaoURL) else {
            completion(false, "Invalid XIAO URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Input-Device-Secret")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = hex.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 202 {
                    completion(true, nil)
                } else {
                    completion(false, "XIAO returned \(httpResponse.statusCode)")
                }
            } else {
                completion(false, "Invalid response")
            }
        }.resume()
    }
    
    func checkStatus(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://172.31.254.1/status") else {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 200)
            } else {
                completion(false)
            }
        }.resume()
    }
}
