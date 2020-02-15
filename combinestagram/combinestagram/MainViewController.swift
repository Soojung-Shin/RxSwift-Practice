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

class MainViewController: UIViewController {
  
  private let bag = DisposeBag()
  private let images = BehaviorRelay<[UIImage]>(value: [])
  
  @IBOutlet weak var imagePreview: UIImageView!
  @IBOutlet weak var buttonClear: UIButton!
  @IBOutlet weak var buttonSave: UIButton!
  @IBOutlet weak var itemAdd: UIBarButtonItem!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    //지금은 viewDidLoad에서 subscribe 했는데 나중에 따로 클래스로 뽑아내거나, MVVM 모델로 바꿔서 사용하는 것을 배울 것.
    images
      .subscribe(onNext: { [weak imagePreview] photos in
        guard let preview = imagePreview else { return }
        preview.image = photos.collage(size: preview.frame.size)
      })
      .disposed(by: bag)
    
    //🤔 asObservable을 사용하는 이유는?!?! 안써도 잘 실행되는데.....?
    images.asObservable()
      .subscribe(onNext: { [weak self] photos in
        self?.updateUI(photos: photos)
      })
      .disposed(by: bag)
  }
  
  @IBAction func actionClear() {
    images.accept([])
  }
  
  @IBAction func actionSave() {
    guard let image = imagePreview.image else { return }
    
    PhotoWriter.save(image)
      .subscribe(
        onSuccess: { [weak self] id in
          self?.showMessage("Saved with id: \(id)")
          self?.actionClear()
        }, onError: { [weak self] error in
          self?.showMessage("Error", description: error.localizedDescription)
        }
      )
      .disposed(by: bag)
  }
  
  @IBAction func actionAdd() {
    //    let newImages = images.value + [UIImage(named: "IMG_1907")!]
    //    images.accept(newImages)
    
    let photosViewController = storyboard!.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
    navigationController!.pushViewController(photosViewController, animated: true)
    
    photosViewController.selectedPhotos
      .subscribe(
        onNext: { [weak self] newImage in
          guard let images = self?.images else { return }
          images.accept(images.value + [newImage])
        },
        onDisposed: {
          //photosViewController가 네비게이션의 뷰 스택에서 pop되면 deallocate 된다.
          //photosViewController가 deallocate 되면 해당 subject도 해제될 것이기 때문에 dispose되면 사진 선택이 완료된 것~!
          print("completed photo selection")
      }
    )
      .disposed(by: bag)
  }
  
  private func updateUI(photos: [UIImage]) {
    
    //선택된 사진이 없다면 clear 버튼을 비활성화한다.
    buttonClear.isEnabled = photos.count > 0
    
    //사진이 있을 때 콜라주에 빈칸이 없게 처리하기 위해서 짝수인 경우에만 save 버튼을 활성화한다.
    buttonSave.isEnabled = (photos.count > 0) && (photos.count % 2 == 0)
    
    //사진이 6개 이상이면 이미지 크기를 고려해서 add 버튼 비활성화해 더이상 사진을 추가할 수 없게 한다.
    itemAdd.isEnabled = photos.count < 6
    
    //뷰 컨트롤러의 제목 설정. title이라는 프로퍼티로 바로 접근이 가능하구만?! 추가된 사진이 없다면 collage, 있다면 추가된 사진의 개수를 보여준다.
    title = photos.count > 0 ? "\(photos.count) photos" : "collage"
  }
  
  func showMessage(_ title: String, description: String? = nil) {
    alert(title: title, text: description)
      .subscribe()
      .disposed(by: bag)
  }
}
