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

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  
  let disposeBag = DisposeBag()
  let categories = BehaviorRelay<[EOCategory]>(value: [])

  @IBOutlet var tableView: UITableView!
  
  let spinner = UIActivityIndicatorView()
  let downloadView = DownloadView()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
    spinner.startAnimating()
    
    view.addSubview(downloadView)
    view.layoutIfNeeded()
    
    categories
      .subscribe(onNext: { [weak self] _ in
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
      })
      .disposed(by: disposeBag)

    startDownload()
  }

  func startDownload() {
    downloadView.progress.progress = 0
    downloadView.label.text = "Download: 0%"
    
    let eoCategories = EONET.categories
    let downloadedEvents = eoCategories
      .flatMap { categories in
        return Observable.from(categories.map { category in
          EONET.events(category: category)
        })
      }
      .merge(maxConcurrent: 2)
    
    let updatedCategories = eoCategories
      .flatMap { categories in
        downloadedEvents.scan(categories) { updated, events in
          return updated.map { category in
            let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
            
            if !eventsForCategory.isEmpty {
              var cat = category
              cat.events = cat.events + eventsForCategory
              
              return cat
            }
            return category
          }
        }
      }
      .do {
        DispatchQueue.main.async { [weak self] in
          self?.spinner.stopAnimating()
          self?.downloadView.isHidden = true
        }
      }
    
    eoCategories.flatMap { categories in
        return updatedCategories.scan(0) { count, _ in
          return count + 1
        }
        .startWith(0)
        .map { ($0, categories.count) }
      }
      .subscribe(onNext: { tuple in
        DispatchQueue.main.async { [weak self] in
          let progress = Float(tuple.0) / Float(tuple.1)
          self?.downloadView.progress.progress = progress
          let percent = Int(progress * 100)
          self?.downloadView.label.text = "Download: \(percent)%"
        }
      })
      .disposed(by: disposeBag)
      
    eoCategories
      .concat(updatedCategories)
      .bind(to: categories)
      .disposed(by: disposeBag)
  }
  
  // MARK: UITableViewDataSource
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return categories.value.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
    
    let category = categories.value[indexPath.row]
    cell.textLabel?.text = "\(category.name) (\(category.events.count))"
    cell.detailTextLabel?.text = category.description
    cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = categories.value[indexPath.row]
    tableView.deselectRow(at: indexPath, animated: true)
    
    guard !category.events.isEmpty else { return }
    
    let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
    
    eventsController.title = category.name
    eventsController.events.accept(category.events)
    
    navigationController?.pushViewController(eventsController, animated: true)
  }
}

