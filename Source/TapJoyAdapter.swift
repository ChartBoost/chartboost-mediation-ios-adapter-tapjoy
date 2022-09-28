//
//  TapJoyAdapter.swift
//  ChartboostHeliumAdapterTapJoy
//

import Foundation
import HeliumSdk
import Tapjoy
import UIKit

final class TapJoyAdapter: ModularPartnerAdapter {
    /// Get the version of the partner SDK.
    let partnerSDKVersion: String = Tapjoy.getVersion()

    /// Get the version of the mediation adapter.
    let adapterVersion = "4.12.10.0.0"

    /// Get the internal name of the partner.
    let partnerIdentifier = "tapjoy"

    /// Get the external/official name of the partner.
    let partnerDisplayName = "Tapjoy"

    /// Storage of adapter instances.  Keyed by the request identifier.
    var adAdapters: [String: PartnerAdAdapter] = [:]

    /// The last value set on `setGDPRApplies(_:)`.
    private var gdprApplies = false

    /// The last value set on `setGDPRConsentStatus(_:)`.
    private var gdprStatus: GDPRConsentStatus = .unknown

    /// Upon deinitialization, end the Tapjoy session
    deinit {
        Tapjoy.endSession()
    }

    /// Provides a new ad adapter in charge of communicating with a single partner ad instance.
    func makeAdAdapter(request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) throws -> PartnerAdAdapter {
        guard request.format != .banner else {
            throw error(.loadFailure(request), description: "Banner ads are not supported.")
        }

        let adapter = TapJoyAdAdapter(adapter: self, request: request, partnerAdDelegate: partnerAdDelegate)
        return adapter
    }

    /// Onitialize the partner SDK so that it's ready to request and display ads.
    /// - Parameters:
    ///   - configuration: The necessary initialization data provided by Helium.
    ///   - completion: Handler to notify Helium of task completion.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)

        guard let sdkKey = configuration.sdkKey, !sdkKey.isEmpty else {
            let error = error(.missingSetUpParameter(key: .sdkKey))
            log(.setUpFailed(error))
            return completion(error)
        }

        Tapjoy.startSession()
        Tapjoy.connect(sdkKey)

        let timeout: TimeInterval = 5.0
        var duration: TimeInterval = 0
        DispatchQueue.global(qos: .background).async {
            while (!Tapjoy.isConnected() && duration < timeout) {
                sleep(1)
                duration += 1
            }
            if Tapjoy.isConnected() {
                self.log(.setUpSucceded)
                completion(nil)
            }
            else {
                let error = self.error(.setUpFailure, description: "Connect timeout")
                self.log(.setUpFailed(error))
                completion(error)
            }
        }
    }

    /// Compute and return a bid token for the bid request.
    /// - Parameters:
    ///   - request: The necessary data associated with the current bid request.
    ///   - completion: Handler to notify Helium of task completion.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]) -> Void) {
        log(.fetchBidderInfoStarted(request))
        log(.fetchBidderInfoSucceeded(request))
        completion([:])
    }

    /// Notify the partner SDK of GDPR applicability as determined by the Helium SDK.
    /// - Parameter applies: true if GDPR applies, false otherwise.
    func setGDPRApplies(_ applies: Bool) {
        gdprApplies = applies
        let policy = Tapjoy.getPrivacyPolicy()
        policy.setSubjectToGDPR(applies)
        updateGDPRConsent()
    }

    /// Notify the partner SDK of the GDPR consent status as determined by the Helium SDK.
    /// - Parameter status: The user's current GDPR consent status.
    func setGDPRConsentStatus(_ status: GDPRConsentStatus) {
        gdprStatus = status
        updateGDPRConsent()
    }

    private func updateGDPRConsent() {
        guard gdprApplies else {
            return
        }
        let policy = Tapjoy.getPrivacyPolicy()
        let userConsent = gdprStatus == .granted ? "1" : "0"
        log(.privacyUpdated(setting: "'UserConsent String'", value: userConsent))
        policy.setUserConsent(userConsent)
    }

    /// Notify the partner SDK of the COPPA subjectivity as determined by the Helium SDK.
    /// - Parameter isSubject: True if the user is subject to COPPA, false otherwise.
    func setUserSubjectToCOPPA(_ isSubject: Bool) {
        log(.privacyUpdated(setting: "'BelowConsentAge Bool'", value: isSubject))

        let policy = Tapjoy.getPrivacyPolicy()
        policy.setBelowConsentAge(isSubject)
    }

    /// Notify the partner SDK of the CCPA privacy String as supplied by the Helium SDK.
    /// - Parameters:
    ///   - hasGivenConsent: True if the user has given CCPA consent, false otherwise.
    ///   - privacyString: The CCPA privacy String.
    func setCCPAConsent(hasGivenConsent: Bool, privacyString: String?) {
        let privacyString = privacyString ?? (hasGivenConsent ? "1YN-" : "1YY-")
        log(.privacyUpdated(setting: "'USPrivacy String'", value: privacyString))

        // https://ltv.tapjoy.com/sdk/api/objc/Classes/TJPrivacyPolicy.html#//api/name/setUSPrivacy:
        // https://ltv.tapjoy.com/sdk/api/objc/Classes/Tapjoy.html#//api/name/getPrivacyPolicy
        // https://github.com/InteractiveAdvertisingBureau/USPrivacy/blob/master/CCPA/US%20Privacy%20String.md
        let policy = Tapjoy.getPrivacyPolicy()
        policy.setUSPrivacy(privacyString)
    }
}

/// Convenience extension to access APS credentials from the configuration.
private extension PartnerConfiguration {
    var sdkKey: String? { credentials[.sdkKey] as? String }
}

private extension String {
    /// Tapjoy keys
    static let sdkKey = "sdk_key"
}
