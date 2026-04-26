import UIKit

class ViewController: UIViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = .systemBackground
		
		let config = UIImage.SymbolConfiguration(scale: .large)
		let imageView = UIImageView(image: UIImage(systemName: "globe", withConfiguration: config))
		imageView.tintColor = .systemBlue
		
		let label = UILabel()
		label.text = "Hello, world!"
		label.textAlignment = .center
		label.textColor = .label
		
		let stackView = UIStackView(arrangedSubviews: [imageView, label])
		stackView.axis = .vertical
		stackView.distribution = .equalCentering
		stackView.alignment = .center
		stackView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stackView)
		
		NSLayoutConstraint.activate([
			stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
	}
}
