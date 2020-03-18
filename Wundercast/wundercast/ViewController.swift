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

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    
    private let disposeBag = DisposeBag()
    
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    @IBOutlet private var celsiusSwitch: UISwitch!
    @IBOutlet private var switchLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        style()
        
        //이거는 테스트용 코드. UI와 잘 연결되었나 확인하기 위함.
//        ApiController.shared.currentWeather(city: "RxSwift")
//            .observeOn(MainScheduler.instance)
//            .subscribe(onNext: { data in
//                self.cityNameLabel.text = data.cityName
//                self.tempLabel.text = "\(data.temperature) °C"
//                self.iconLabel.text = data.icon
//                self.humidityLabel.text = "\(data.humidity) %"
//            })
//            .disposed(by: disposeBag)
        
        let searchInput = searchCityName.rx.controlEvent(UIControl.Event.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
        
        //🤔 왜 검색 실패로 404 받아온 후로는 검색이 안되지?!
        //search의 flatMapLatest에서 catchErrorJustReturn을 지워서 안됐던것임...아~~~ 에러 받으면 그 옵저버블이 바로 종료돼서 그 다음 이벤트를 받아올 수가 없었던거군...
        let search = searchInput
            .flatMapLatest { text in
                return ApiController.shared.currentWeather(city: text)
                    .catchErrorJustReturn(ApiController.Weather.empty)
            }
            .asDriver(onErrorJustReturn: ApiController.Weather.empty)
        
        let running = Observable.merge(
                searchInput.map { _ in true },
                search.map { _ in false}.asObservable()
            )
            .startWith(true)
            .asDriver(onErrorJustReturn: false)

        let tempSwitch = celsiusSwitch.rx.isOn.asDriver(onErrorJustReturn: true)

        //처음에 combineLatest에서 에러가 엄청 많이 났는데 왜그런가 생각해봤더니 첨에는 Observable로 만들어서 Driver랑 Observable을 combine하려고해서 그랬던것같다. 그래서 스위치도 Driver로 변경해주고 Driver의 combineLatest를 사용했다.
        Driver<String>
            .combineLatest(search, tempSwitch) { data, switchIsOn -> String in
                if data.cityName == ApiController.Weather.empty.cityName {
                    return switchIsOn ? "\(data.temperature) °C" : "\(data.temperature) °F"
                }
                return switchIsOn ? "\(data.temperature) °C" : "\(Double(data.temperature) * 1.8 + 32) °F"
            }
            .drive(tempLabel.rx.text)
            .disposed(by: disposeBag)

        //📖 아래 주석은 책에 있는 솔루션임. 이거보다 내 코드가 더 나은 이유는...이거는 스위치를 켜고끌때마다 API를 새로 받아옴. 비효율적. 그래도 어케 쓰는지는 알아두자.
//        let textSearch = searchCityName.rx.controlEvent(.editingDidEndOnExit).asObservable()
//        let temperature = celsiusSwitch.rx.controlEvent(.valueChanged).asObservable()
//
//        let search = Observable.merge(textSearch, temperature)
//          .map { self.searchCityName.text ?? "" }
//          .filter { !$0.isEmpty }
//          .flatMapLatest { text in
//            return ApiController.shared.currentWeather(city: text)
//              .catchErrorJustReturn(ApiController.Weather.empty)
//          }
//          .asDriver(onErrorJustReturn: ApiController.Weather.empty)
//
//        search
//          .map { w in
//            switch self.celsiusSwitch.isOn {
//            case true:
//              return "\(Int(Double(w.temperature) * 1.8 + 32))° F"
//            case false:
//              return "\(w.temperature)° C"
//            }
//          }
//          .drive(tempLabel.rx.text)
//          .disposed(by: disposeBag)

        search.map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: disposeBag)

        search.map { "\($0.humidity) %" }
            .drive(humidityLabel.rx.text)
            .disposed(by: disposeBag)

        search.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: disposeBag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        Appearance.applyBottomLine(to: searchCityName)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Style
    
    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
        switchLabel.textColor = UIColor.cream
    }
}
