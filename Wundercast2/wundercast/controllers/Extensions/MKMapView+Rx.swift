/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import Foundation
import MapKit
import RxSwift
import RxCocoa

//지도에 주변 지역 날씨를 표현하기 위해서 MapKit의 MKMapView를 확장한다.
//확장하는 방식은 CLLocationManager 확장했을 때와 같다.

extension MKMapView: HasDelegate {
    public typealias Delegate = MKMapViewDelegate
}

class RxMKMapViewDelegateProxy: DelegateProxy<MKMapView, MKMapViewDelegate>, DelegateProxyType, MKMapViewDelegate {
    public private(set) weak var mapView: MKMapView?
    
    public init(mapView: ParentObject) {
        self.mapView = mapView
        super.init(parentObject: mapView, delegateProxy: RxMKMapViewDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { RxMKMapViewDelegateProxy.init(mapView: $0) }
    }
}

public extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView, MKMapViewDelegate> {
        return RxMKMapViewDelegateProxy.proxy(for: base)
    }
    
    //MKOverlay 인스턴스를 가져와 MKMapView에 주입하는 바인딩 옵저버를 만드는 메소드.
    //Binder 타입은 bind나 drive와 함께 사용할 수 있다.
    var overlays: Binder<[MKOverlay]> {
        return Binder(self.base) { mapView, overlays in
            //이전 overlay들을 지우고 받아온 overlay를 새로 추가한다.
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays)
            
            //여기에서는 한 화면에 10개 이상의 overlay가 있을 가능성이 매우 적기때문에 그냥 이전 것들을 전부 삭제하고 새로 다 추가하는 방식을 사용했다. 만약 overlay가 굉장히 많아 성능 문제가 걱정된다면 diffing 알고리즘을 사용해 성능을 개선하고 오버헤드를 줄일 수 있다.
        }
    }
    
//    var centerCoordinate: Binder<CLLocationCoordinate2D> {
//        return Binder(self.base) { mapView, coordinate in
//            mapView.centerCoordinate = coordinate
//        }
//    }

    
    //주변 날씨를 구할 때 위도 경도 -1...1로 계산할 거기 때문에 이렇게 변경했다.
    var location: Binder<CLLocationCoordinate2D> {
        return Binder(self.base) { mapView, coordinate in
            let span = MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
            mapView.region = MKCoordinateRegion(center: coordinate, span: span)
        }
    }
    
    var regionDidChangeAnimated: ControlEvent<Bool> {
        let source = delegate.methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:)))
            .map { parameters in
                return (parameters[1] as? Bool) ?? false
            }
        return ControlEvent(events: source)
    }
    
    //func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer 메소드를 사용할건데, 리턴값이 있고, 관찰을 위한 리턴값이 아니라 처리를 위한 메소드이다. 또 기본 값을 지정하는 것이 까다롭기 때문에 delegate의 메소드를 그대로 이용하기 위해서 아래와 같이 처리해준다.
    //installForwardDelegate 메소드를 통해서 forwarding delegate를 설치했고, 이제 호출을 전달하고 필요한 경우 리턴값을 제공해줄 수도 있다.
    //RxProxy에서 처리되지 않은 모든 메소드 호출을 delegate가 대신 받는다.
    func setDelegate(_ delegate: MKMapViewDelegate) -> Disposable {
        return RxMKMapViewDelegateProxy.installForwardDelegate(
            delegate,
            retainDelegate: false,
            onProxyForObject: self.base
        )
    }
}
