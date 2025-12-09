/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation
import UIKit

// App
let buildName: String = "Vendetta"
let buildStage: String = "Alpha"

var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
}

var buildNumber: String {
    guard let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
          let number = Int(build) else {
        return "Unknown"
    }
    return String(format: "%X", number)
}

// AppInfoView
class AppInfoViewController: UIThemedTableViewController {
    
    private var credits: [Credit] = [
        Credit(name: "Frida", role: "Maintainer", githubURL: "https://github.com/cr4zyengineer"),
        Credit(name: "Duy Tran", role: "LiveContainer", githubURL: "https://github.com/khanhduytran0"),
        Credit(name: "Huge_Black", role: "LiveContainer", githubURL: "https://github.com/hugeBlack"),
        Credit(name: "Stossy11", role: "Helpful advise for the window server", githubURL: "https://github.com/stossy11"),
        Credit(name: "Lars Fröder", role: "Litehook", githubURL: "https://github.com/opa334"),
        Credit(name: "ayame09", role: "Original Nyxian app icons", githubURL: "https://github.com/ayayame09"),
        Credit(name: "sxdev", role: "Drawn app icons", githubURL: "https://github.com/SamoXcZ"),
        Credit(name: "xzadik", role: "Nyxcat app icons", githubURL: "https://github.com/xzadik"),
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Info"
        
        self.tableView.register(CreditCell.self, forCellReuseIdentifier: CreditCell.identifier)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 4
        case 2:
            return credits.count
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 1:
            return "Nyxian"
        case 2:
            return "Credits"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return 120
        case 2:
            return 80
        default:
            return tableView.rowHeight
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = UITableViewCell(style: .value1, reuseIdentifier: "")
        
        if(indexPath.section == 0) {
            cell.contentView.backgroundColor = .clear
            cell.backgroundColor = .clear
            
            let image: UIImage = UIImage(imageLiteralResourceName: "InfoThumbnail")
            let imageView: UIImageView = UIImageView(image: image)
            imageView.layer.cornerRadius = 15
            imageView.layer.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            
            cell.contentView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.heightAnchor.constraint(equalToConstant: 100),
                imageView.widthAnchor.constraint(equalToConstant: 100),
                imageView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor)
            ])
            
            cell.selectionStyle = .none
        } else if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = buildName
            case 1:
                cell.textLabel?.text = "Stage"
                cell.detailTextLabel?.text = buildStage
            case 2:
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = appVersion
            case 3:
                cell.textLabel?.text = "Build"
                cell.detailTextLabel?.text = buildNumber
            default:
                cell.textLabel?.text = "Unknown"
            }
            
            cell.selectionStyle = .none
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: CreditCell.identifier, for: indexPath) as? CreditCell else {
                return UITableViewCell()
            }
            
            let credit = credits[indexPath.row]
            cell.nameLabel.text = credit.name
            cell.roleLabel.text = credit.role
            
            downloadImage(from: "\(credit.githubURL).png") { image in
                cell.profileImageView.image = image ?? UIImage(systemName: "person.circle")
            }
            
            return cell
        }
        
        return cell
    }
    
    func downloadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async { completion(image) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 2 { return }
        let credit = credits[indexPath.row]
        if let url = URL(string: credit.githubURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
