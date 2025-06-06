import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import AVFoundation
import CoreHaptics

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 푸시 알림 설정
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Notification authorization failed: \(error)")
                }
            }
        )
        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self
        
        // 오디오 세션 초기화 (현재 프로젝트 기능 유지)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        
        // 햅틱 엔진 초기화 (iOS 13.0 이상, 현재 프로젝트 기능 유지)
        if #available(iOS 13.0, *) {
            if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                do {
                    let engine = try CHHapticEngine()
                    try engine.start()
                } catch {
                    print("Failed to start haptic engine: \(error)")
                }
            }
        }
        
        // Flutter 플러그인 등록 (예전 프로젝트와 동일)
        GeneratedPluginRegistrant.register(with: self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // 푸시 알림 등록 성공
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken // APNs 토큰 설정
        print("APNs token set: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    }
    
    // 푸시 알림 등록 실패
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // 백그라운드 fetch 처리
    override func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }
    
    // 포그라운드에서 알림 처리
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }
}

// Firebase Messaging 델리게이트
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "None")")
    }
}