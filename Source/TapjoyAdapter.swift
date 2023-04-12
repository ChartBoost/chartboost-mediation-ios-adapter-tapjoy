// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import Tapjoy
import UIKit

/// Chartboost Mediation Tapjoy adapter.
final class TapjoyAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion: String = Tapjoy.getVersion()
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.13.0.0.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "tapjoy"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Tapjoy"
        
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) { }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Fail early if credentials unavailable
        guard let sdkKey = configuration.sdkKey, !sdkKey.isEmpty else {
            let error = error(.initializationFailureInvalidCredentials, description: "Missing \(String.sdkKey)")
            log(.setUpFailed(error))
            return completion(error)
        }
        
        // Listen to Tapjoy initialization notifications
        NotificationCenter.default.addObserver(forName: Notification.Name(TJC_CONNECT_SUCCESS), object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            self.log(.setUpSucceded)
            completion(nil)
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name(TJC_CONNECT_FAILED), object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            let error = self.error(.initializationFailureUnknown)
            self.log(.setUpFailed(error))
            completion(error)
        }
        
        // Start Tapjoy SDK
        Tapjoy.startSession()
        Tapjoy.connect(sdkKey)
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        completion(nil)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // See https://dev.tapjoy.com/en/ios-sdk/User-Privacy
        let policy = Tapjoy.getPrivacyPolicy()
        if let applies = applies {
            policy.setSubjectToGDPR(applies)
            log(.privacyUpdated(setting: "setSubjectToGDPR", value: applies))
        }
        if status != .unknown {
            let userConsent = status == .granted ? "1" : "0"
            log(.privacyUpdated(setting: "userConsent", value: userConsent))
            policy.setUserConsent(userConsent)
        }
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // See https://dev.tapjoy.com/en/ios-sdk/User-Privacy
        Tapjoy.getPrivacyPolicy().setBelowConsentAge(isChildDirected)
        log(.privacyUpdated(setting: "setBelowConsentAge", value: isChildDirected))
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // See https://dev.tapjoy.com/en/ios-sdk/User-Privacy
        Tapjoy.getPrivacyPolicy().setUSPrivacy(privacyString)
        log(.privacyUpdated(setting: "setUSPrivacy", value: privacyString))
    }
    
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .interstitial, .rewarded:
            return try TapjoyAdapterAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            throw error(.loadFailureUnsupportedAdFormat)
        @unknown default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
}

/// Convenience extension to access APS credentials from the configuration.
private extension PartnerConfiguration {
    var sdkKey: String? { credentials[.sdkKey] as? String }
}

private extension String {
    /// Tapjoy sdk credentials key
    static let sdkKey = "sdk_key"
}
