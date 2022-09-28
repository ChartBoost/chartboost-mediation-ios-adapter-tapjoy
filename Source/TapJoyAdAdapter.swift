//
//  TapJoyAdAdapter.swift
//  ChartboostHeliumAdapterTapJoy
//

import Foundation
import HeliumSdk
import Tapjoy
import UIKit

final class TapJoyAdAdapter: NSObject, PartnerAdAdapter {

    /// The current adapter instance
    let adapter: PartnerAdapter

    /// The current PartnerAdLoadRequest containing data relevant to the curent ad request
    let request: PartnerAdLoadRequest

    /// A PartnerAd object with a placeholder (nil) ad object.
    lazy var partnerAd = PartnerAd(ad: nil, details: [:], request: request)

    /// The partner ad delegate to send ad life-cycle events to.
    weak var partnerAdDelegate: PartnerAdDelegate?

    /// The completion handler to notify Helium of ad show completion result.
    var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// The completion handler to notify Helium of ad load completion result.
    var showCompletion: ((Result<PartnerAd, Error>) -> Void)?

    /// Create a new instance of the adapter.
    /// - Parameters:
    ///   - adapter: The current adapter instance
    ///   - request: The current AdLoadRequest containing data relevant to the curent ad request
    ///   - partnerAdDelegate: The partner ad delegate to notify Helium of ad lifecycle events.
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) {
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate

        super.init()
    }

    /// Attempt to load an ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad load completion result.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        loadCompletion = completion

        guard let placement = TJPlacement(name: request.partnerPlacement, mediationAgent: "chartboost", mediationId: nil, delegate: self) else {
            let error = error(.loadFailure(request), description: "Failed to create placement.")
            log(.loadFailed(request, error: error))
            return completion(.failure(error))
        }

        placement.adapterVersion = adapter.adapterVersion
        placement.placementName = request.partnerPlacement
        placement.videoDelegate = self

        // TODO: Build from PartnerAdLoadRequest.partnerSettings?  Somewhere else?  Discussion is still in progress.
        // Note: If it was `partnerSettings`, that is a [String:String] which also complicates things since it would
        //       really need to be [String:Any]
        placement.auctionData = [:]

        partnerAd = PartnerAd(ad: placement, details: [:], request: request)

        placement.requestContent()
    }

    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        guard let placement = partnerAd.ad as? TJPlacement else {
            return completion(.failure(error(.showFailure(partnerAd), description: "Ad instance is nil/not an TJPlacement.")))
        }

        if placement.isContentReady, placement.isContentAvailable {
            showCompletion = completion
            placement.showContent(with: viewController)
        }
        else {
            return completion(.failure(error(.showFailure(partnerAd), description: "Content not ready or not available.")))
        }
    }
}

extension TapJoyAdAdapter {
    // TODO: Not used yet...see above regarding `auctionData`
    struct AuctionData: Codable {
        let id: String?
        let clearingPrice: Float?
        let extraData: String?
        let type: Int = 1

        enum CodingKeys: String, CodingKey {
            case id
            case clearingPrice = "clearing_price"
            case extraData = "ext_data"
        }

        func jsonDictionary() throws -> [String: Any] {
            let encoder = JSONEncoder()
            let data = try encoder.encode(self)
            return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        }
    }
}

extension TapJoyAdAdapter: TJPlacementDelegate {
    func requestDidSucceed(_ placement: TJPlacement) {
        if placement.isContentAvailable, placement.isContentReady {
            loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        }
        else if !placement.isContentAvailable {
            let error = error(.loadFailure(request), description: "Content not available.")
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        }
        loadCompletion = nil
    }

    func requestDidFail(_ placement: TJPlacement, error: Error?) {
        let error = self.error(.loadFailure(request), error: error)
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func contentIsReady(_ placement: TJPlacement) {
        if placement.isContentReady {
            loadCompletion?(.success(partnerAd)) ?? log(.loadResultIgnored)
        }
        else {
            let error = error(.loadFailure(request), description: "Content not ready.")
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        }
        loadCompletion = nil
    }

    func contentDidAppear(_ placement: TJPlacement) {
        Tapjoy.setVideoAdDelegate(self)
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }

    func contentDidDisappear(_ placement: TJPlacement) {
        Tapjoy.setVideoAdDelegate(nil)
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }

    func didClick(_ placement: TJPlacement) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }
}

extension TapJoyAdAdapter: TJCVideoAdDelegate {
    func videoAdError(_ errorMsg: String?) {
        let error = error(.showFailure(partnerAd), description: errorMsg ?? "Unknown reason")
        showCompletion?(.failure(error))
        showCompletion = nil
    }
}

extension TapJoyAdAdapter: TJPlacementVideoDelegate {
    func videoDidComplete(_ placement: TJPlacement) {
        partnerAdDelegate?.didReward(partnerAd, reward: .init(amount: 1, label: nil)) ?? log(.delegateUnavailable)
    }

    func videoDidFail(_ placement: TJPlacement, error errorMsg: String?) {
        let error = error(.showFailure(partnerAd), description: errorMsg ?? "Unknown reason")
        showCompletion?(.failure(error))
        showCompletion = nil
    }
}
