import CryptoKit
import Foundation
import Testing
@testable import VaultSecurity

struct EncryptionServiceTests {
    @Test
    func encryptDecryptRestoresOriginalData() throws {
        let service = EncryptionService()
        let originalData = Data("Passport.pdf".utf8)

        let payload = try service.encrypt(data: originalData)
        let decryptedData = try service.decrypt(payload: payload)

        #expect(decryptedData == originalData)
    }

    @Test
    func encryptingSameDataTwiceProducesDifferentPayloads() throws {
        let service = EncryptionService()
        let originalData = Data("Passport.pdf".utf8)

        let firstPayload = try service.encrypt(data: originalData)
        let secondPayload = try service.encrypt(data: originalData)

        #expect(firstPayload != secondPayload)
        #expect(firstPayload.ciphertext != secondPayload.ciphertext)
        #expect(firstPayload.nonce != secondPayload.nonce)
    }

    @Test
    func decryptWithWrongKeyFails() throws {
        let encryptingService = EncryptionService(key: SymmetricKey(size: .bits256))
        let decryptingService = EncryptionService(key: SymmetricKey(size: .bits256))
        let originalData = Data("Passport.pdf".utf8)

        let payload = try encryptingService.encrypt(data: originalData)

        #expect(throws: EncryptionService.EncryptionError.decryptionFailed) {
            try decryptingService.decrypt(payload: payload)
        }
    }
}
