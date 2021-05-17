## [Lecture 7 - Multithreading EmojiArt](https://cs193p.sites.stanford.edu/sites/g/files/sbiybj16636/files/media/file/lecture_7_0.pdf )

### Don't Block my UI!

(다른 플랫폼에서도 비슷하겠지만) 모바일 앱에서의 UI는 무조건 즉각적으로 반응해야한다. 즉, 터치, 스크롤, 줌 등 뭐가되었던 UI와 관련된 동작들은 다른 비용이 큰 작업에 의해 방해받으면 안되고, 이를 처리하는 쓰레드는 Block되면 안된다.

하지만, 만약 어쩔 수 없이 비용이 큰 작업을 하게된다면, UI를 처리하는 쓰레드가 아닌 다른 쓰레드에서 해야 한다.



### Background Queues

그렇다면 non-UI 작업들 중 비용이 큰 녀석들은 어디서 처리할까?

Swift에서는 이를 위해 사용가능한 Background Queue들을 제공한다.

Swift에서는 이러한 Background Queue에 작업을 넣는 것 자체가, 이 작업들이 다른 큐의 작업들과 거의 동시에 실행된다는 것을 보장한다.

```swift
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
```





## [Lecture 8 - Gestures JSON](https://cs193p.sites.stanford.edu/sites/g/files/sbiybj16636/files/media/file/lecture_8.pdf)

EmojiArt 예제의 가장 중요한 기능은 gesture이라고 생각할 정도로 gesture의 많은 기능들을 테스트 해볼 수 있습니다. 

```swift
ZStack {
  Color.white.overlay(
    OptionalImage(uiImage: document.backgroundImage)
    .scaleEffect(zoomScale)
    .offset(panOffset)
  )
  .gesture(doubleTapToZoom(in: geometry.size))
  // 이미지 위에 놓여있는 이모지
  if self.isLoading {
    Image(systemName: "hourglass").imageScale(.large).spinning()
  } else {
    ForEach(document.emojis) { emoji in
			Text(emoji.text)
				.font(animatableWithSize: emoji.fontSize * zoomScale)
				.position(self.position(for: emoji, in: geometry.size))
		}
  }
}
.clipped() // 뷰를 경계 직사각형 프레임으로 자름
.gesture(panGesture())
.gesture(zoomGesture())
```



```swift
private func doubleTapToZoom(in size: CGSize) -> some Gesture {
  TapGesture(count: 2)
  .onEnded { // 클로저를 통해 제스쳐를 받았을때 원하는 로직 실행
    withAnimation {
      zoomToFit(document.backgroundImage, in: size)
    }
  }
}

@State private var steadyStateZoomScale: CGFloat = 1.0
// 제스처가 진행되는 상황에 따른 변화를 알고싶다면 @GestureState 를 사용
// 제스쳐가 끝나면 항상 starting value 로 값이 돌아감
@GestureState private var gestureZoomScale: CGFloat = 1.0

private func panGesture() -> some Gesture {
  DragGesture()
  	// @GestureState 는 이 클로저 안에서만 변경이 가능
    .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
      gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
    }
  	.onEnded { finalDragGestureValue in
			steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
		}
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
```

여기서 updating보다 간단한 작업을 할것이라면 .onChanged를 사용 가능하다

- .onChanged 에서는 @GestureState 값을 변경할수 없음

- 현재 제스처에 절대적인 위치를 .onChanged 에서 알수있지만 이전보다 얼마나 확대됐는지 혹은 움직였는지를 알고싶다면 .updating 을 사용해야함



## [Lecture 9 - Data Flow](https://cs193p.sites.stanford.edu/sites/g/files/sbiybj16636/files/media/file/l9_0.pdf)

##### [Property Wrappers](https://github.com/apple/swift-evolution/blob/master/proposals/0258-property-wrappers.md)

- `@Something` 은 모두 Property Wrapper!

- 일반적으로 wrappedValue 와 projectedValue를 가지고 있는 `struct` 임. 더 많은 property를 가질 수 도 있고, projectedValue가 없을 수도 있음!

- 이미 "**정해져 있는 동작"** 들을 래핑하는 변수에 적용하여 캡슐화 함.

  

예를 들면...

`@State` :: View 내부에서 수정할 수 있도록 heap에 사는 변수 만들기

`@Published` :: 변수의 변경사항을 공표(publish)하기

`@ObservedObject` :: publish된 변경사항이 감지되면 `View` 를 다시 그리도록 하기



## `@Published`

`wrappedValue` 가 `set` 되는 시점에 `Publish` ( `projectedValue` )를 통해 변경사항을 전달한다. 이 변경사항은 `$emojiArt` 로 연결되어 있는 곳으로 전파됩니다. 그리고 이는 `ObservableObject` 에서 `objectWillChange.send()` 를 호출합니다.



## `@State`

`wrappedValue` 가 값타입이건 참조타입이건(보통 스유에서는 값타입) heap에 저장합니다. 변경사항이 생기면, 연결된 `View` 를 다시 그립니다.

```swift
struct State<Value>: DynamicProperty {

  init(initialValue: Value)

  var wrappedValue: Value
  var projectedValue: Binding<Value>   

}
```

- **DynamicProperty** :: View의 외부 속성을 업데이트하는 stored variable에 대한 interface
- [.init(wrappedValue:) vs .init(initialValue:)](https://forums.swift.org/t/swiftui-state-init-wrappedvalue-vs-init-initialvalue-whats-the-difference/38904/19)



## `@ObservedObject`

`wrappedValue` 는 `ObservableObject` 를 채택한 타입이여야 합니다.

`wrappedValue` 가 `objectWillChange.send()` 를 호출했을 때 `View` 를 다시 그립니다.

```swift
struct ObservedObject<ObjectType>: DynamicProperty where ObjectType : ObservableObject{

  init(initialValue: Value)

  var wrappedValue: Value
  var projectedValue: ObservedObject<ObjectType>.Wrapper { get }

  public struct Wrapper {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> { get }
  }

}
```



## `@Binding`

`wrappedValue` :: 다른 무언가와 연결된 값

다른 어떤 곳에서 `wrappedValue` 를 `get/set` 할 수 있습니다. 값이 변경되었을 때, `View` 를 다시 그립니다.

아주아주아주 많은 곳에서 쓸 수 있음.

**진실의** 단일 소스를 가지게 한다는 점에서, MVVM 패턴에서 매우 중요한 역할을 합니다.

- 데이터는 `ViewModel` 이 가지고 있지만, 이 데이터는 `View` 에서도 제어하기도 함. (둘 중 뭐가 진짜게?)
- `View` 에서 `stored property` 를 추가하는 것이 아닌, `ViewModel` 의 변수를 `@Biniding` 하여 사용 할 수 있다. 한 쪽에서 바뀌면, 둘 다 바뀌기 때문에 둘 다 진짜가 된당!

```swift
struct OtherView: View {
  @Binding var sharedText: String   // @State가 아닌 @Binding으로 선언
  var body: View {
    Text(sharedText)
  }
}
struct MyView: View {
	@State var myString = "Hello"
  var body: View {
    OtherView(sharedText: $myString)  // myString을 OtherView와 연결
  }
}
```



## `@EnvironmentObject`

`@ObservedObject` 랑 유사한데, 넘겨주는 방식이 다릅니다.

### ObservedObject

```swift
struct MyView: View {
	@ObservedObject var viewModel: ViewModelClass
  ...
}
let myView = MyView(viewModel: theViewModel)
```

### EnvironmentObject

```swift
struct MyView: View {
	@EnvironmentObject var viewModel: ViewModelClass
  ...
}
let myView = MyView().environmentObject(theViewModel)
```

가장 큰 차이점!

상위 뷰에서 `@EnvironmentObject` 를 선언하면, `body` 내부의 모든 뷰에서 (모달로 띄운 거 말고) 접근할 수 있다!!!!!!

`View` 하나에서 같은 `ObservableObject` 타입의 `@EnvironmentObject` 는 하나만 존재할 수 있다.

기본적으로 wrappedValue 와 동작방식은 ObservableObject 와 같다!
