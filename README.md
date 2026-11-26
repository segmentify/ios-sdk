# Segmentify iOS SDK
Segmentify  SDK for sending events and rendering recommendations for iOS based devices

> **Supports iOS 13 and higher devices.**

> **Current Version 1.5.0**

## Installation and Usage
You can directly use Swift Package Manager to add and use Segmentify in your project. 
To learn more about how to integrate Segmentify iOS SDK to your application, please check [Integration Guide](https://www.segmentify.com/dev/integration_ios/).

## Installation - Legacy

You can install Segmentify iOS SDK to your application by using [Pod Module](https://cocoapods.org/?q=segmentify).

Please add following line to your Podfile:

```ruby
pod "Segmentify"
```

## Usage - Legacy

To learn more about how to integrate Segmentify iOS SDK to your application, please check [Integration Guide](https://www.segmentify.com/dev/integration_ios/).

For other integrations you can check [Master Integration](https://www.segmentify.com/dev/) guide too.

Inside your Xcode project's root folder run the following commands.
 
- Run ```pod init``` to create an empty pod file
- Run ```pod install``` to add Cocoapods to your project
- Run open ```YourProject.xcworkspace``` to your new Xcode project's workspace.

## License

Segmentify iOS SDK is available under the BSD-2 license.
Please check LICENSE file to learn more about details.




## Push Permission Updates 1.4.2

1.4.2 update includes auto userId for pushNotification request. It means if you are standalone push user you do NOT require to assign user id to `SegmentifyManager.sharedManager().sendNotification(segmentifyObject: obj)` anymore.

Good Luck!


## Push & User Updates 1.4.3

1.4.3 update changes user events in the background. This is a completely internal and will not effect sdk users. Also productId parameter has been removed from push interaction event. 

## Error handling

The event methods that take a `callback` answer a failed request with an empty result. To be told about the failure, use the variant with `onError`. Exactly one of the two closures is called, on the main queue.

```swift
let page = PageModel()
page.category = "Home Page"

SegmentifyManager.sharedManager().sendPageView(segmentifyObject: page, callback: { recommendations in
    // show the recommendations
}, onError: { error in
    // error.message          what went wrong, for logs
    // error.httpStatus       HTTP status when the server answered with an error
    // error.statusCode       the backend's reason when it refused the request, e.g. "NO_SESSIONID"
    // error.underlyingError  the transport error, e.g. no network
})
```

`SegmentifyError` has a public initialiser, so a test of your app can create one to simulate a failure.

Available for `sendPageView`, `sendProductView`, `sendCustomEvent`, `sendViewBasket`, `sendCustomerInformation`, `sendPaymentInformation`, `sendPurchase`, `sendSearchPageView` and `sendFacetedSearchPageView`, each with a `segmentifyObject`. The existing methods are unchanged.
