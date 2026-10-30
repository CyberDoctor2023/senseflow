import Foundation
import CryptoKit

// Public-key verification never reads the signing private key or Keychain.
guard CommandLine.arguments.count == 4,
      let key = Data(base64Encoded: CommandLine.arguments[1]),
      let signature = Data(base64Encoded: CommandLine.arguments[2]) else {
    fputs("Invalid public key/signature arguments\n", stderr)
    exit(1)
}
do {
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: key)
    let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))
    guard publicKey.isValidSignature(signature, for: archive) else {
        fputs("Update signature does not match the application's embedded public key\n", stderr)
        exit(1)
    }
    print("PASS update archive Ed25519 signature")
} catch {
    fputs("Signature verification failed: \(error)\n", stderr)
    exit(1)
}
