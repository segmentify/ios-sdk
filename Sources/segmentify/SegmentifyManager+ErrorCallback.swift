//
//  SegmentifyManager+ErrorCallback.swift
//  Segmentify

import Foundation

/// The same events as the `callback:`-only methods, with an `onError` closure.
///
/// Exactly one of the two closures is called, on the main queue: `callback`
/// when the backend answered, `onError` when the request failed, was refused
/// by the backend, could not get a session or was rejected before sending.
/// The `callback:`-only methods keep answering failures with an empty result.
public extension SegmentifyManager {

    @objc func sendPageView(segmentifyObject: PageModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendPageView(segmentifyObject: segmentifyObject, callback: callback) }
    }

    @objc func sendProductView(segmentifyObject: ProductModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendProductView(segmentifyObject: segmentifyObject, callback: callback) }
    }

    @objc func sendCustomEvent(segmentifyObject: CustomEventModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendCustomEvent(segmentifyObject: segmentifyObject, callback: callback) }
    }

    func sendViewBasket(segmentifyObject: CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendViewBasket(segmentifyObject: segmentifyObject, callback: callback) }
    }

    func sendCustomerInformation(segmentifyObject: CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendCustomerInformation(segmentifyObject: segmentifyObject, callback: callback) }
    }

    func sendPaymentInformation(segmentifyObject: CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendPaymentInformation(segmentifyObject: segmentifyObject, callback: callback) }
    }

    func sendPurchase(segmentifyObject: CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendPurchase(segmentifyObject: segmentifyObject, callback: callback) }
    }

    @objc func sendSearchPageView(segmentifyObject: SearchPageModel, callback: @escaping (_ searchResponse: SearchModel) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendSearchPageView(segmentifyObject: segmentifyObject, callback: callback) }
    }

    func sendFacetedSearchPageView(segmentifyObject: SearchFacetPageModel, callback: @escaping (_ facetedResponse: FacetedResponseModel) -> Void, onError: @escaping (_ error: SegmentifyError) -> Void) {
        reportingErrors(to: onError) { sendFacetedSearchPageView(segmentifyObject: segmentifyObject, callback: callback) }
    }
}
