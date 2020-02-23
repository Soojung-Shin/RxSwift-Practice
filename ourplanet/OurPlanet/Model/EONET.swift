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
import RxSwift
import RxCocoa

class EONET {
  static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
  static let categoriesEndpoint = "/categories"
  static let eventsEndpoint = "/events"

  static func jsonDecoder(contentIdentifier: String) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.userInfo[.contentIdentifier] = contentIdentifier
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
    return events.filter { event in
      return event.categories.contains(where: { $0.id == category.id }) && !category.events.contains {
        $0.id == event.id
      }
      }
      .sorted(by: EOEvent.compareDates)
  }

  //request를 만들어서 옵저버블로 전달하는 메소드.
  static func request<T: Decodable>(endpoint: String, query: [String : Any] = [:], contentIdentifier: String) -> Observable<T> {
    do {
      guard let url = URL(string: API)?.appendingPathComponent(endpoint), var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
        //URL을 만들 수 없는 경우 에러를 발생시킨다.
        throw EOError.invalidURL(endpoint)
      }
      
      //주어진 쿼리를 URLQueryItem으로 만드는 compactMap. URLComponents의 queryItems의 속성으로 들어간다.
      components.queryItems = try query.compactMap { (key, value) in
        guard let v = value as? CustomStringConvertible else {
          throw EOError.invalidParameter(key, value)
        }
        return URLQueryItem(name: key, value: v.description)
      }
      
      guard let finalURL = components.url else {
        throw EOError.invalidURL(endpoint)
      }
      
      let request = URLRequest(url: finalURL)
      
      return URLSession.shared.rx.response(request: request)
        .map { (result: (response: HTTPURLResponse, data: Data)) -> T in
          let decoder = self.jsonDecoder(contentIdentifier: contentIdentifier)
          let envelope = try decoder.decode(EOEnvelope<T>.self, from: result.data)
          return envelope.content
        }
    } catch {
      return Observable.empty()
    }
  }
  
  //카테고리 리스트를 만드는 옵저버블을 받아오는 메소드. 카테고리를 요청하는 request를 만들어 옵저버블을 받아온다.
  //singleton(static, share)으로 만들어서 여러번의 request 없이 하나의 옵저버블만 유지하고, 새로운 구독이 생기면 제일 처음에 만들어진 옵저버블을 반환한다.
  static var categories: Observable<[EOCategory]> = {
    let request: Observable<[EOCategory]> = EONET.request(endpoint: categoriesEndpoint, contentIdentifier: "categories")
    
    return request
      .map { categories in
        categories.sorted { $0.name < $1.name }
      }
      .catchErrorJustReturn([])
      .share(replay: 1, scope: .forever)
  }()
  
  /*
  //이벤트 리스트를 만드는 옵저버블을 받아오는 메소드. 이벤트를 요청하는 request를 만들어 옵저버블을 받아온다.
  private static func events(forLast days: Int, closed: Bool) -> Observable<[EOEvent]> {
    let query: [String : Any] = [
      "days" : days,
      "status" : (closed ? "closed" : "open")
    ]
    
    let request: Observable<[EOEvent]> = EONET.request(endpoint: eventsEndpoint, query: query, contentIdentifier: "events")
    return request.catchErrorJustReturn([])
  }
   
   //status가 open인 이벤트와 closed인 이벤트를 모두 받아와야하기 때문에 따로 만들어서 concat 시켜 반환한다. 외부에서는 요청할 때 이 메소드를 사용하게 될 것!
   static func events(forLast days: Int = 360) -> Observable<[EOEvent]> {
     let openEvents = events(forLast: days, closed: false)
     let closedEvents = events(forLast: days, closed: true)
     
     //return openEvents.concat(closedEvents)
     
     //concat으로 sequential하게 묶었던 옵저버블을 merge로 변경해 parallel하게 변경한다.
     return Observable.of(openEvents, closedEvents)
       .merge()
       .reduce([]) { running, new in
         running + new
       }
   }
 */
  
  //이벤트 다운로드를 각 카테고리 별로 분리시키기 위해 endpoint 파라미터를 추가한다.
  private static func events(forLast days: Int, closed: Bool, endpoint: String) -> Observable<[EOEvent]> {
    let query: [String : Any] = [
      "days" : days,
      "status" : (closed ? "closed" : "open")
    ]
    
    let request: Observable<[EOEvent]> = EONET.request(endpoint: endpoint, query: query, contentIdentifier: "events")
    return request.catchErrorJustReturn([])
  }
  
  //이벤트 다운로드를 각 카테고리 별로 분리시키기 위해 category 파라미터를 추가한다.
  static func events(forLast days: Int = 360, category: EOCategory) -> Observable<[EOEvent]> {
    let openEvents = events(forLast: days, closed: false, endpoint: category.endpoint)
    let closedEvents = events(forLast: days, closed: true, endpoint: category.endpoint)
    
    return Observable.of(openEvents, closedEvents)
      .merge()
      .reduce([]) { running, new in
        running + new
      }
  }
}
