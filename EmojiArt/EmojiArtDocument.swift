//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by Yoojin Park on 2021/02/15.
//

import SwiftUI
import Combine

class EmojiArtDocument: ObservableObject {
    static let palette: String = "⭐️☁️🍎🍋🥝🍗🍔🍟"
    
    @Published private var emojiArt: EmojiArt
    
    //@Published // workaround(해결방법) for property observer(ex.willSet) problem with property wappers
//    private var emojiArt: EmojiArt = EmojiArt() {
//        willSet {
//            objectWillChange.send() // 값이 변동되었음을 알려주는 메서드 (published와 같은 동작을 함)
//        }
//        didSet {
//            UserDefaults.standard.set(emojiArt.json, forKey: EmojiArtDocument.untitled)
//        }
//    }
    
    private static let untitled = "EmojiArtDocument.Untitled"
    
    private var autosaveCancellable: AnyCancellable?
    
    init() {
        emojiArt = EmojiArt(json: UserDefaults.standard.data(forKey: EmojiArtDocument.untitled)) ?? EmojiArt()
        autosaveCancellable = $emojiArt.sink { emojiArt in // 종료 기반 동작이있는 구독자를 절대 실패하지 않는 게시자에 연결
            UserDefaults.standard.set(emojiArt.json, forKey: EmojiArtDocument.untitled)
        }
        fetchBackgroundImageData()
    }
    
    @Published private(set) var backgroundImage: UIImage?
    
    var emojis: [EmojiArt.Emoji] { emojiArt.emojis }
    
    // MARK: Intent(s)
    
    func addEmoji(_ emoji: String, at location: CGPoint, size: CGFloat) {
        emojiArt.addEmoji(emoji, x: Int(location.x), y: Int(location.y), size: Int(size))
    }
    
    func moveEmoji(_ emoji: EmojiArt.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y += Int(offset.height)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArt.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.firstIndex(matching: emoji) {
            emojiArt.emojis[index].size = Int((CGFloat(emojiArt.emojis[index].size) * scale).rounded(.toNearestOrEven))
        }
    }
    
    var backgroundURL: URL? {
        get {
            emojiArt.backgroundURL
        }
        set {
            emojiArt.backgroundURL = newValue?.imageURL
            fetchBackgroundImageData()
        }
    }
    
    private var fetchImageCancellable: AnyCancellable?
    
    // backgroundImage 세팅을 위한 함수
    private func fetchBackgroundImageData() {
        backgroundImage = nil
        if let url = self.emojiArt.backgroundURL {
            fetchImageCancellable?.cancel() // 이전것을 삭제 후 아래 소스로 새 이미지 가져옴
            // global : 지정된 서비스 품질 클래스가있는 전역 시스템 큐
            // qos : 대기열과 연결할 서비스 품질 수준입니다. 이 값은 시스템이 실행 작업을 예약하는 우선 순위를 결정
            // qos - user Initiated : 사용자가 앱을 적극적으로 사용하지 못하게하는 작업에 대한 서비스 품질 클래스입니다.
            // 이외의 것들은 https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass 참고
            fetchImageCancellable = URLSession.shared.dataTaskPublisher(for: url)
                .map { data, urlResponse in UIImage(data: data)}
                .receive(on: DispatchQueue.main)
                .replaceError(with: nil)
                .assign(to: \EmojiArtDocument.backgroundImage, on: self)
        }
    }
}

extension EmojiArt.Emoji {
    var fontSize: CGFloat { CGFloat(self.size) }
    var location: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
