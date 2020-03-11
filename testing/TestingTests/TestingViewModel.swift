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
import RxCocoa
import RxTest
@testable import Testing

class TestingViewModel : XCTestCase {
    var viewModel: ViewModel!
    var scheduler: ConcurrentDispatchQueueScheduler!
    
    override func setUp() {
        super.setUp()
        
        viewModel = ViewModel()
        scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
    }
    
    //기존의 XCTest API를 사용한 테스트 방법.
    func testColorIsRedWhenHexStringIsFF0000_async() {
        let disposeBag = DisposeBag()
        
        //테스트의 비동기 작업이 완료되었을 때 수행할 수 있는 XCTestExpectation 인스턴스를 만든다. 비동기 작업이 완료된 후 fulfill()을 호출한다.
        let expect = expectation(description: #function)
        
        let expectColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        var result: UIColor!
        
        viewModel.color.asObservable()
            .skip(1)    //Driver는 구독시 초기값을 전달하기 때문에 skip(1) 오퍼레이터를 사용했다.
            .subscribe(onNext: {
                result = $0
                expect.fulfill()
            })
            .disposed(by: disposeBag)
        
        viewModel.hexString.accept("#FF0000")
        
        waitForExpectations(timeout: 1.0) { error in
            guard error == nil else {
                XCTFail(error!.localizedDescription)
                return
            }
            
            XCTAssertEqual(result, expectColor)
        }
    }
    
    //RxBlocking을 사용한 테스트 방법. 위 메소드와 같은 동작을 테스트한다.
    func testColorIsRedWhenHexStringIsFF0000() throws {
        let colorObservable = viewModel.color.asObservable().subscribeOn(scheduler)
        
        viewModel.hexString.accept("#FF0000")
        
        XCTAssertEqual(try colorObservable.toBlocking(timeout: 1.0).first(), .red)
    }
    
    func testRgbIs010WhenHexStringIs00FF00() throws {
        let rgbObservable = viewModel.rgb.asObservable().subscribeOn(scheduler)
        
        viewModel.hexString.accept("#00FF00")
        
        let result = try rgbObservable.toBlocking().first()!
        
        XCTAssertEqual(0 * 255, result.0)
        XCTAssertEqual(1 * 255, result.1)
        XCTAssertEqual(0 * 255, result.2)
    }
    
    func testColorNameIsPapayaWhipWhenHexStringIsFFEFD5() throws {
        let colorNameObservable = viewModel.colorName.asObservable().subscribeOn(scheduler)
        
        viewModel.hexString.accept("#FFEFD5")
        
        XCTAssertEqual(try colorNameObservable.toBlocking().first()!, "papayaWhip")
    }
}
