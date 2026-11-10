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


## Push Auth & Click Updates 1.5.0

- `setConfig(apiKey:dataCenterUrl:subDomain:authHeader:)`: `apiKey` is now optional and there is a new optional `authHeader`. Existing calls compile unchanged. When `authHeader` is set, it is sent as the `Authorization` header exactly as given (no prefix is added, so pass the full value, e.g. `Basic <token>`), and no `apiKey` query parameter is sent.
- **Behaviour change:** push clicks are now sent as `INTERACTION` events (`type: push`). Before 1.5.0 the click interaction was never sent, so push click numbers in reporting will go up after upgrading.
- New `handlePushNotificationResponse(response:completion:)` sends the CLICK and opens the deeplink. It is not available in app extensions; use `handlePushNotificationExtension` in a Notification Service Extension.
- `instanceId` is read from the top-level `instanceId` or, for Firebase payloads, `gcm.notification.instanceId`.
- `NotificationModel.fromPush(userInfo:type:)` also sets `providerType` (`FIREBASE` for FCM payloads, otherwise `APNS`), so VIEW and CLICK for the same push report the same provider.
