/*
 * Copyright (c) 2016-present Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

func cachedFileURL(_ fileName: String) -> URL {
  return FileManager.default
    .urls(for: .cachesDirectory, in: .allDomainsMask)
    .first!
    .appendingPathComponent(fileName)
}

class ActivityController: UITableViewController {
  private let repo = "ReactiveX/RxSwift"
  
  private let events = BehaviorRelay<[Event]>(value: [])
  private let lastModified = BehaviorRelay<String?>(value: nil)
  private let bag = DisposeBag()
  
  private let eventsFileURL = cachedFileURL("events.json")
  private let modifiedFileURL = cachedFileURL("modified.json")
  
  override func viewDidLoad() {
    super.viewDidLoad()
    title = repo
    
    self.refreshControl = UIRefreshControl()
    let refreshControl = self.refreshControl!
    
    refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
    refreshControl.tintColor = UIColor.darkGray
    refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
    
    let decoder = JSONDecoder()
    if let eventsData = try? Data(contentsOf: eventsFileURL), let persistedEvents = try? decoder.decode([Event].self, from: eventsData) {
      events.accept(persistedEvents)
    }
    
    if let lastModifiedString = try? String(contentsOf: modifiedFileURL, encoding: .utf8) {
      lastModified.accept(lastModifiedString)
    }
    
    refresh()
  }
  
  @objc func refresh() {
    DispatchQueue.global(qos: .default).async { [weak self] in
      guard let self = self else { return }
      self.fetchEvents(repo: self.repo)
    }
  }
  
  func fetchEvents(repo: String) {
    /*
    let response = Observable.from([repo])
        .map { urlString -> URL in
          return URL(string: "https://api.github.com/repos/\(urlString)/events")!
        }
  //      .map { url -> URLRequest in
  //        return URLRequest(url: url)
  //      }
        .map { [weak self] url -> URLRequest in
          //URLRequest에 Last-Modified 헤더를 추가한다. addValue 메소드를 이용한다는 것!!!!
          //이 Last-Modified 값을 추가하면 서버에 이 값 보다 이전의 값은 관심이 없다는 것을 알려줄 수 있다.
          //서버에서는 Last-Modified가 포함된 요청을 받으면 자신의 Last-Modified를 확인해서 다르다면 새로운 데이터를 전송하고, 같다면 데이터를 전송하지 않고 응답만 보낸다.
          //데이터가 전송되지 않으니 트래픽을 줄일 수 있고 전송 시간도 줄어든다. 또 데이터가 없는 응답은 API 사용 카운트로 적용되지 않는다.
          //🤔 브라우저에서 요청을 보낼 때 사용하는거는 If-Modified-Since 필드라는데...?! Last-Modified는 서버에서 응답 보낼때 사용하는거고....그냥 Last-Modified로 해도 되는건지..?!

          var request = URLRequest(url: url)

          if let modifiedHeader = self?.lastModified.value {
            request.addValue(modifiedHeader, forHTTPHeaderField: "Last-Modified")
          }
          return request
        }
        .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
          return URLSession.shared.rx.response(request: request)
          //RxCocoa에서 shared URLSession의 response(request:) 메소드는 Observable<(response: HTTPURLResponse, data: Data)> 타입의 인스턴스를 리턴한다.
          //이 observable은 웹 서버로부터 모든 response를 받으면 completed 된다.
        }
        .share(replay: 1)
  */
    
    //github에서 가장 인기있는 swift repositories 5개를 가져온다. score(검색 횟수? 등으로 계산된대) 내림차순으로 정렬된 값을 보내준다.
    //이렇게 받은 repositories들의 event 상황을 받아보자~!
    let response = Observable.from(["https://api.github.com/search/repositories?q=language:swift&per_page=5"])
      .map { urlString -> URL in
        return URL(string: urlString)!
      }
      .flatMap { url -> Observable<Any> in
        let urlRequest = URLRequest(url: url)
        return URLSession.shared.rx.json(request: urlRequest)
      }
      .flatMap { response -> Observable<String> in
        guard let response = response as? [String : Any], let items = response["items"] as? [[String : Any]] else {
          return Observable<String>.empty()
        }
        
        return Observable.from(items.map { $0["full_name"] as! String })
      }
      .map { repo -> URL in
        return URL(string: "https://api.github.com/repos/\(repo)/events")!
      }
      .map { [weak self] url -> URLRequest in
        var urlRequest = URLRequest(url: url)
        
        if let modifiedHeader = self?.lastModified.value {
          urlRequest.addValue(modifiedHeader, forHTTPHeaderField: "Last-Modified")
        }
        return urlRequest
      }
      .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
        return URLSession.shared.rx.response(request: request)
      }
    
    response
      .filter { response, _ in
        return 200..<300 ~= response.statusCode
      }
      .map { _, data -> [Event] in
        let decoder = JSONDecoder()
        let events = try? decoder.decode([Event].self, from: data)
        return events ?? []
      }
      .filter { objects in
        return !objects.isEmpty
      }
      .subscribe(onNext: { [weak self] newEvents in
        self?.processEvents(newEvents)
      })
      .disposed(by: bag)
    
    //이전에 받아온 데이터에서 변경사항이 있을 때만 데이터를 가져오기 위해서 헤더의 Last-Modified를 이용한다.
    //Last-Modified 필드는 서버가 알고있는 가장 마지막 수정사항의 날짜와 시간을 나타낸다.
    //Last-Modified 헤더 값이 있는 이벤트만 lastModified observable에 보내고, modifiedFileURL에 해당 헤더 값을 저장한다.
    response
      .filter { response, _ in
        return 200..<400 ~= response.statusCode
      }
      .flatMap { response, _ -> Observable<String> in
        guard let value = response.allHeaderFields["Last-Modified"] as? String else {
          return Observable.empty()
        }
        return Observable.just(value)
      }
      .subscribe(onNext: { [weak self] modifiedHeader in
        guard let self = self else { return }
        
        self.lastModified.accept(modifiedHeader)
        try? modifiedHeader.write(to: self.modifiedFileURL, atomically: true, encoding: .utf8)
      })
      .disposed(by: bag)
  }
  
  func processEvents(_ newEvents: [Event]) {
    var updatedEvents = newEvents + events.value
    if updatedEvents.count > 50 {
      updatedEvents = [Event](updatedEvents.prefix(upTo: 50))
    }
    
    events.accept(updatedEvents)
    
    DispatchQueue.main.async {
      self.tableView.reloadData()
      self.refreshControl?.endRefreshing()
    }
    
    let encoder = JSONEncoder()
    if let eventsData = try? encoder.encode(updatedEvents) {
      try? eventsData.write(to: eventsFileURL, options: .atomicWrite)
    }
  }
    
  // MARK: - Table Data Source
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return events.value.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let event = events.value[indexPath.row]
    
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
    cell.textLabel?.text = event.actor.name
    cell.detailTextLabel?.text = event.repo.name + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
    cell.imageView?.kf.setImage(with: event.actor.avatar, placeholder: UIImage(named: "blank-avatar"))
    return cell
  }
}
