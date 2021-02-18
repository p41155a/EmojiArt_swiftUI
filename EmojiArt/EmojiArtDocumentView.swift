//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Yoojin Park on 2021/02/15.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    var body: some View {
        VStack {
            // 상단 스크롤 바
            ScrollView(.horizontal) {
                HStack {
                    // '\'는 key path임을 나타내고 '.'은 self를 연결하기 위함??
                    ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                        Text(emoji) // 각 이모지
                            .font(.system(size: defaultEmojiSize))
                            .onDrag { NSItemProvider(object: emoji as NSString) }
                        // NSItemProvider : 끌어서 놓기 또는 복사 / 붙여 넣기 작업 중 또는 호스트 앱에서 앱 확장으로 프로세스간에 데이터 또는 파일을 전달하기위한 항목 공급자
                        // init(object:) 지정된 개체의 형식 식별자를 사용하여 공급자가 로드 할 수있는 데이터 표현을 지정하여 새 항목 공급자를 초기화합니다.
                    }
                }
            }
            .padding(.horizontal)
            // 스크롤 아래 이미지뷰
            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: document.backgroundImage)
                            .scaleEffect(zoomScale)
                            .offset(panOffset)
                    )
                    .gesture(doubleTapToZoom(in: geometry.size))
                    // 이미지 위에 놓여있는 이모지
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .font(animatableWithSize: emoji.fontSize * zoomScale)
                            .position(self.position(for: emoji, in: geometry.size))
                    }
                }
                .clipped() // 뷰를 경계 직사각형 프레임으로 자름
                .gesture(panGesture())
                .gesture(zoomGesture())
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                // of: 끌어서 놓기를 통해 허용 할 수있는 콘텐츠 유형을 설명하는 유형 식별자
                // isTargeted: 끌어서 놓기 작업이 놓기 대상 영역에 들어가거나 나올 때 업데이트되는 바인딩
                // 바인딩 값이 true -> 커서가 영역 내부에 있을 때 / false -> 외부
                .onDrop(of: ["public.image","public.text"], isTargeted: nil) { providers, location in
                    // SwiftUI bug (as of 13.4)?
                    // 위치는 우리 좌표계에 있어야합니다. 그러나 y 좌표는 전역 좌표계에있는 것처럼 보입니다.
                    var location = CGPoint(x: location.x, y: geometry.convert(location, from: .global).y)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2) // 이렇게 해서 중앙으로 만듬
                    location = CGPoint(x: location.x - panOffset.width, y: location.y - panOffset.height)
                    print(zoomScale)
                    location = CGPoint(x: location.x / zoomScale, y: location.y / zoomScale )
                    // ❓🤔 포인트가 왜 이렇게 되는지 모르겠는데..ㅎ
                    return drop(providers: providers, at: location)
                }
            }
        }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                steadyStateZoomScale *= finalGestureScale
            }
    }
    
    // 이동
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
        }
        .onEnded { finalDragGestureValue in
            steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
        }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
//    private func font(for emoji: EmojiArt.Emoji) -> Font {
//        Font.system(size: emoji.fontSize * zoomScale)
//    }
    
//     화면에 놓여진 이모지의 위치를 화면에 맞게 바꾸어주는 함수
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            document.setBackgroundURL(url)
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                document.addEmoji(string, at: location, size: defaultEmojiSize)
            }
        }
        return found
    }
    
    private let defaultEmojiSize: CGFloat = 40
}
