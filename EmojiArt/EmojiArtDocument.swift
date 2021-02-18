//
//  EmojiArtDocument.swift
//  EmojiArt
//
//  Created by Yoojin Park on 2021/02/15.
//

import SwiftUI

class EmojiArtDocument: ObservableObject {
    static let palette: String = "⭐️☁️🍎🍋🥝🍗🍔🍟"
    
    //@Published // workaround(해결방법) for property observer(ex.willSet) problem with property wappers
    private var emojiArt: EmojiArt = EmojiArt() {
        willSet {
            objectWillChange.send() // 값이 변동되었음을 알려주는 메서드 (published와 같은 동작을 함)
        }
        didSet {
            UserDefaults.standard.set(emojiArt.json, forKey: EmojiArtDocument.untitled)
        }
    }
    
    private static let untitled = "EmojiArtDocument.Untitled"
    
    init() {
        emojiArt = EmojiArt(json: UserDefaults.standard.data(forKey: EmojiArtDocument.untitled)) ?? EmojiArt()
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
    
    func setBackgroundURL(_ url: URL?) {
        emojiArt.backgroundURL = url?.imageURL
        fetchBackgroundImageData()
    }
    
    // backgroundImage 세팅을 위한 함수
    private func fetchBackgroundImageData() {
        backgroundImage = nil
        if let url = self.emojiArt.backgroundURL {
            // global : 지정된 서비스 품질 클래스가있는 전역 시스템 큐
            // qos : 대기열과 연결할 서비스 품질 수준입니다. 이 값은 시스템이 실행 작업을 예약하는 우선 순위를 결정
            // qos - user Initiated : 사용자가 앱을 적극적으로 사용하지 못하게하는 작업에 대한 서비스 품질 클래스입니다.
            // 이외의 것들은 https://developer.apple.com/documentation/dispatch/dispatchqos/qosclass 참고
            DispatchQueue.global(qos: .userInitiated).async {
                if let imageData = try? Data(contentsOf: url) { // 타임아웃과 같은 오류 대비
                    DispatchQueue.main.async {
                        // backgroundImage가 publish임으로 바뀌면 view가 다시 그려질 것이지만 현재 global
                        // main이 아닌 곳에서 무언가를 그릴 수 없기 때문에 main으로 바꿈
                        if url == self.emojiArt.backgroundURL {
                            // 이미지를 끌어오고 로딩되기 전에 다른 이미지를 끌어오고 다른 이미지가 끈 후에 전에 있던 이미지가 오는 이상한 형태 방지를 위한 if문
                            self.backgroundImage = UIImage(data: imageData)
                        }
                    }
                }
            }
        }
    }
}

extension EmojiArt.Emoji {
    var fontSize: CGFloat { CGFloat(self.size) }
    var location: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
