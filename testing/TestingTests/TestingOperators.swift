/*:
 Copyright (c) 2019 Razeware LLC
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 distribute, sublicense, create a derivative work, and/or sell copies of the
 Software in any work that is designed, intended, or marketed for pedagogical or
 instructional purposes related to programming, coding, application development,
 or information technology.  Permission for such use, copying, modification,
 merger, publication, distribution, sublicensing, creation of derivative works,
 or sale is expressly withheld.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import XCTest
import RxSwift
import RxTest
import RxBlocking

class TestingOperators : XCTestCase {
    var scheduler: TestScheduler!
    var subscription: Disposable!
    
    //setUp 메소드는 각 테스트 케이스마다 실행된다.
    override func setUp() {
        super.setUp()
        
        //테스트 케이스를 실행할 때 마다 0초부터 시작하는 테스트 스케줄러를 생성한다.
        scheduler = TestScheduler(initialClock: 0)
    }
    
    //tearDown 메소드는 각 테스트가 종료될 때마다 실행된다.
    override func tearDown() {
        //여기서 사용되는 시간은 RxTest가 내부적으로 계산한 가상의 시간 단위이고, 실제 초나 분이랑은 일치하지 않는다.
        //1000일 때 구독을 dispose한다.
        scheduler.scheduleAt(1000) {
            self.subscription.dispose()
        }
        
        super.tearDown()
    }
    
    func testAmb() {
        let observer = scheduler.createObserver(String.self)
        
        let observableA = scheduler.createHotObservable([
            Recorded.next(100, "a"),
            Recorded.next(200, "b"),
            Recorded.next(300, "c")
        ])
        
        let observableB = scheduler.createHotObservable([
            Recorded.next(50, "1"),
            Recorded.next(300, "2"),
            Recorded.next(500, "3")
        ])

        let ambObservable = observableA.amb(observableB)
        
        self.subscription = ambObservable.subscribe(observer)
        
        scheduler.start()
        
        let result = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(result, ["1", "2", "3"])
    }
    
    func testFilter() {
        let observer = scheduler.createObserver(Int.self)
        
        let observable = scheduler.createHotObservable([
            Recorded.next(100, 1),
            Recorded.next(200, 2),
            Recorded.next(300, 3),
            Recorded.next(400, 1),
            Recorded.next(500, 2)
        ])
        
        let filterObservable = observable.filter { $0 < 3 }
        
        //scheduleAt(0)을 안넣어줘도 알아서 되는거아닌가? 왜 해주는거지
        //self.subscription = filterObservable.subscribe(observer)
        scheduler.scheduleAt(0) {
            self.subscription = filterObservable.subscribe(observer)
        }
        
        scheduler.start()
        
        let result = observer.events.compactMap { $0.value.element }
        XCTAssertEqual(result, [1, 2, 1, 2])
    }
    
    //위의 testAmb(), testFilter()는 모두 동기(async)화된 테스트다. 비동기 테스트를 하는 법은 여러가지가 있지만 가장 간단하게 RxBlocking을 사용할 수 있다.
    
    func testToArray() throws {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let toArrayObservable = Observable.of(1, 2).subscribeOn(scheduler)
        
        //toBlocking()으로 toArrayObservable을 BlockingObservable로 변환하고, 스케줄러가 생성한 스레드가 종료될 때까지 블로킹한다.
        //이렇게 하면 비동기 코드 테스트 완료!
        XCTAssertEqual(try toArrayObservable.toBlocking().toArray(), [1, 2])
    }
    
    //RxBlocking에서는 materialize() 오퍼레이터를 제공한다. MaterializedSequenceResult<T> 타입을 리턴하는데, enum으로 성공, 실패 케이스를 가진다. Single과 비슷한 모양새!
    //각 케이스는 옵저버블에서 방출된 elements의 배열을 가지며, 실패시에는 에러값도 함께 갖는다.
    //materialzie를 사용하면 enum으로 모델링해서 더 강력하고 명시적인 테스트가 가능하다.
    func testToArrayMaterialized() {
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let toArrayObservable = Observable.of(1, 2, 3).subscribeOn(scheduler)
        
        let result = toArrayObservable
            .toBlocking()
            .materialize()
        
        switch result {
        case .completed(let element):
            XCTAssertEqual(element, [1, 2, 3])
        case .failed(_, let error):
            XCTFail(error.localizedDescription)
        }
    }
}
