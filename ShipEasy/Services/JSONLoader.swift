import Foundation

// MARK: - JSON Loader Utility
/// A helper class providing a reusable function to load and parse bundled JSON files.
final class JSONLoader {

    /// Loads and decodes a JSON resource file from the application's main bundle.
    /// - Parameter file: The filename including extension (e.g. "couriers.json").
    /// - Returns: The parsed model conforming to Decodable, or a fatal error / fallback.
    static func load<T: Decodable>(_ file: String) -> T {
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension.isEmpty ? "json" : (file as NSString).pathExtension

        let possibleUrl = Bundle.main.url(forResource: file, withExtension: nil)
            ?? Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: file, withExtension: nil, subdirectory: "Resources")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources")

        guard let url = possibleUrl else {
            print("⚠️ [JSONLoader] File not found in main bundle: \(file)")
            fatalError("Failed to locate \(file) in bundle.")
        }

        return decode(from: url, file: file)
    }

    /// Internal helper that reads data from a URL and runs JSONDecoder.
    private static func decode<T: Decodable>(from url: URL, file: String) -> T {
        // Step 2: Read raw byte data from the file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("⚠️ [JSONLoader] Error reading data from \(file): \(error.localizedDescription)")
            fatalError("Failed to load \(file) from bundle: \(error.localizedDescription)")
        }

        // Step 3: Decode JSON data into the target Swift data type
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ [JSONLoader] Error parsing JSON in \(file): \(error.localizedDescription)")
            fatalError("Failed to parse \(file) as \(T.self): \(error.localizedDescription)")
        }
    }
}
