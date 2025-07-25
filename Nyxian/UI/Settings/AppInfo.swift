//
//  AppInfo.swift
//  Nyxian
//
//  Created by SeanIsTethered on 23.06.25.
//

import Foundation
import UIKit

// App
let buildName: String = "Twinterlune"
let buildStage: String = "Indev"
let buildVersion: Double = 0.4

// AppInfoView
class AppInfoViewController: UIThemedTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Info"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : 3
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : "Nyxian"
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return (indexPath.section == 0) ? 120 : tableView.rowHeight
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
        }else {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = {
                    if buildVersion <= 0.3 {
                        return "Nightsky"
                    } else if buildVersion <= 0.9 {
                        return "Moonshine"
                    } else {
                        return "Unknown"
                    }
                }()
            case 1:
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = String(buildVersion)
            default:
                cell.textLabel?.text = "Stage"
                cell.detailTextLabel?.text = buildStage
            }
        }
        
        cell.selectionStyle = .none
        
        return cell
    }
}
