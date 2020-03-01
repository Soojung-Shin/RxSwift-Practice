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
import MapKit
import CoreLocation

class ViewController: UIViewController {
    @IBOutlet private var mapView: MKMapView!
    @IBOutlet private var mapButton: UIButton!
    @IBOutlet private var geoLocationButton: UIButton!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private var searchCityName: UITextField!
    @IBOutlet private var tempLabel: UILabel!
    @IBOutlet private var humidityLabel: UILabel!
    @IBOutlet private var iconLabel: UILabel!
    @IBOutlet private var cityNameLabel: UILabel!
    
    private let bag = DisposeBag()
    
    private let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        style()
        
        // MARK: - search
                
        let searchInput = searchCityName.rx.controlEvent(UIControl.Event.editingDidEndOnExit)
            .map { self.searchCityName.text ?? "" }
            .filter { !$0.isEmpty }
        
        let textSearch = searchInput.flatMap { text in
            return ApiController.shared.currentWeather(city: text)
                .catchErrorJustReturn(.dummy)
        }
        
        //왼쪽 하단의 버튼을 눌러 위치 정보를 받아오기 시작했을 때, 위치 정보가 업데이트되면 현재 위치를 가져온다.
        let currentLocation = locationManager.rx.didUpdateLocations
            .map { locations in locations[0] }
            .filter { location in
                return location.horizontalAccuracy < kCLLocationAccuracyHundredMeters
            }
        
        //mapView에서 지도 위치가 변경되었을 때 해당 뷰의 center 값을 가져온다.
        //skip을 하는 이유는 mapView가 처음 initialize 되었을 때 search를 실행하는 것을 방지하기 위해서다.
        let mapInput = mapView.rx.regionDidChangeAnimated
            .skip(1)
            .map { [unowned self] _ in self.mapView.centerCoordinate }
        
        let mapSearch = mapInput.flatMap { coordinate in
            return ApiController.shared.currentWeather(at: coordinate)
                .catchErrorJustReturn(.dummy)
        }
                                
        //현재 위치를 받아오기 위해서 사용자에게 권한을 확인받아야한다. 사용자가 현재 위치를 받아오는 버튼을 누르면 가장 먼저 해야할 일은 권한을 요청하는 것이다.
        let geoInput = geoLocationButton.rx.tap.asObservable()
            .do(onNext: {
                self.locationManager.requestWhenInUseAuthorization()
                self.locationManager.startUpdatingLocation()
            })
        
        let geoLocation = geoInput.flatMap {
            return currentLocation.take(1)
        }
        
        let geoSearch = geoLocation.flatMap { location in
            return ApiController.shared.currentWeather(at: location.coordinate)
                .catchErrorJustReturn(.dummy)
        }
        
        locationManager.rx.didUpdateLocations
            .subscribe(onNext: { locations in
                print(locations)
            })
            .disposed(by: bag)
        
        let search = Observable
            .merge(textSearch, geoSearch, mapSearch)
            .asDriver(onErrorJustReturn: .dummy)
        
        // MARK: - UI Hidden
        
        //네트워크 통신 중일 때 ActivityIndicator를 보이게하고, 나머지 UI들을 숨기기 위해 추가된 Observable.
        //search에서 값이 도착해야 false가 되어 activityIndicator가 사라지고 UI가 보이게된다.
        let running = Observable.merge(
            searchInput.map { _ in true },
            geoInput.map { _ in true },
            mapInput.map { _ in true },
            search.map { _ in false }.asObservable()
        )
            .startWith(true)
            .asDriver(onErrorJustReturn: false)
        
        running.skip(1)
            .drive(activityIndicator.rx.isAnimating)
            .disposed(by: bag)
        
        running
            .drive(tempLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(humidityLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(iconLabel.rx.isHidden)
            .disposed(by: bag)
        
        running
            .drive(cityNameLabel.rx.isHidden)
            .disposed(by: bag)
        
        search.map { "\($0.temperature)° C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: bag)
        
        search.map { "\($0.humidity)%" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.cityName }
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)

        // MARK: - map
        //mapButton을 탭하면 mapView가 토글된다.
        mapButton.rx.tap
            .subscribe(onNext: {
                self.mapView.isHidden.toggle()
            })
            .disposed(by: bag)

        mapView.rx.setDelegate(self)
            .disposed(by: bag)
        
//        search.map { [$0.overlay()] }
//            .drive(mapView.rx.overlays)
//            .disposed(by: bag)
        
        Observable
            .merge(geoSearch, textSearch)
            .map { $0.coordinate }
            .asDriver(onErrorJustReturn: ApiController.Weather.dummy.coordinate)
            .drive(mapView.rx.location)
            .disposed(by: bag)
        
        //지도에서 주변 날씨도 표시한다.
        mapInput.flatMap { coordinate in
                return ApiController.shared.currentWeatherAround(location: coordinate)
                        .catchErrorJustReturn([])
            }
            .asDriver(onErrorJustReturn: [])
            .map { $0.map { $0.overlay() } }
            .drive(mapView.rx.overlays)
            .disposed(by: bag)
        
    }
    
    // MARK: - View LifeCycle
    
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
    }
}

// MARK: - MKMapViewDelegate
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let overlay = overlay as? ApiController.Weather.Overlay else {
            return MKOverlayRenderer()
        }
        
        let overlayView = ApiController.Weather.OverlayView(overlay: overlay, overlayIcon: overlay.icon)
        return overlayView
    }
}
