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
import CoreLocation
import RxSwift
import RxCocoa

//LocationManager에 rx 기능을 추가하기 위해 만들어진 프록시 클래스. delegate를 observable에 1:1로 맵핑한다. 가짜 delegate 객체를 만드는 것....
//이 클래스는 observable이 생성되고, 구독이 생겼을 때 CLLocationManager 인스턴스에 연결되는 프록시가 된다. 이 작업은 RxCocoa가 제공하는 HasDelegate 프로토콜로 단순화된다.

extension CLLocationManager: HasDelegate {
    public typealias Delegate = CLLocationManagerDelegate
}

class RxCLLocationManagerDelegateProxy: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {
    
    public private(set) weak var locationManager: CLLocationManager?
    
    public init(locationManager: ParentObject) {
        self.locationManager = locationManager
        super.init(parentObject: locationManager, delegateProxy: RxCLLocationManagerDelegateProxy.self)
    }
    
    static func registerKnownImplementations() {
        self.register { RxCLLocationManagerDelegateProxy.init(locationManager: $0) }
    }
    
    //위에 과정을 통해서 이제 delegate를 initialize하고, 모든 구현을 register 할 수 있게 됐다. 이제 CLLocationManager의 인스턴스에서 데이터를 가져와 연결된 observable로 데이터를 보내는 작업을 해야한다.
    //이 작업이 RxCocoa에서 delegate proxy 패턴을 사용해 클래스를 확장하는 방법이다.
}

//extension Reactive 하면, CLLocationManager의 rx 네임스페이스에 이 extension 내부의 메소드들이 표시된다.
public extension Reactive where Base: CLLocationManager {
    var delegate: DelegateProxy<CLLocationManager, CLLocationManagerDelegate> {
        return RxCLLocationManagerDelegateProxy.proxy(for: base)
    }
    
    //이제 delegate는 didUpdateLocations의 모든 호출을 받고, 데이터를 가져와 CLLocation 배열로 캐스팅한다.
    //methodInvoked 메소드는 RxCocoa에서 정의된 Objected-C 코드로 기본적인 delegate 호출에 대한 하위 수준의 observer이다.
    //methodInvoked(_:)는 지정된 메소드가 호출될 때마다 next 이벤트를 방출하는 observable을 리턴한다. 이 이벤트에 포함된 element는 메소드가 호출된 매개변수 배열로 되어있다.(locationManager(_:didUpdateLocations:)이 파라미터들을 말하는듯?!) 여기서는 인덱스가 1인 배열에 접근해 CLLocation 배열로 캐스팅했다.
    var didUpdateLocations: Observable<[CLLocation]> {
        return delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)))
            .map { parameters in
                return parameters[1] as! [CLLocation]
            }
    }
}
