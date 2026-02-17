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

// AppInfoView
class CreditsViewController: UIThemedTableViewController {
    
#if !JAILBREAK_ENV
    private var credits: [Credit] = [
        Credit(name: "Frida", role: "Maintainer", githubURL: "https://github.com/cr4zyengineer"),
        Credit(name: "LucaVmu", role: "Manager", githubURL: "https://github.com/LucaVmu"),
        Credit(name: "Duy Tran", role: "LiveContainer", githubURL: "https://github.com/khanhduytran0"),
        Credit(name: "Huge_Black", role: "LiveContainer", githubURL: "https://github.com/hugeBlack"),
        Credit(name: "Vinogradov Daniil", role: "Massive help on LLVM-On-iOS", githubURL: "https://github.com/XITRIX"),
        Credit(name: "light-tech", role: "LLVM-On-iOS", githubURL: "https://github.com/light-tech"),
        Credit(name: "Lars Fröder", role: "Litehook", githubURL: "https://github.com/opa334"),
        Credit(name: "ayame09", role: "Original Nyxian app icons", githubURL: "https://github.com/ayayame09"),
        Credit(name: "sxdev", role: "Drawn app icons", githubURL: "https://github.com/SamoXcZ"),
        Credit(name: "xzadik", role: "Nyxcat app icons", githubURL: "https://github.com/xzadik"),
    ]
#else
    private var credits: [Credit] = [
        Credit(name: "Frida", role: "Maintainer", githubURL: "https://github.com/cr4zyengineer"),
        Credit(name: "LucaVmu", role: "Manager", githubURL: "https://github.com/LucaVmu"),
        Credit(name: "Duy Tran", role: "FrontBoardAppLauncher", githubURL: "https://github.com/khanhduytran0"),
        Credit(name: "Vinogradov Daniil", role: "Massive help on LLVM-On-iOS", githubURL: "https://github.com/XITRIX"),
        Credit(name: "light-tech", role: "LLVM-On-iOS", githubURL: "https://github.com/light-tech"),
        Credit(name: "Lars Fröder", role: "Litehook,Trollstore and libroot", githubURL: "https://github.com/opa334"),
        Credit(name: "ayame09", role: "Original Nyxian app icons", githubURL: "https://github.com/ayayame09"),
        Credit(name: "sxdev", role: "Drawn app icons", githubURL: "https://github.com/SamoXcZ"),
        Credit(name: "xzadik", role: "Nyxcat app icons", githubURL: "https://github.com/xzadik"),
    ]
#endif // !JAILBREAK_ENV
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Credits"
        
        self.tableView.register(CreditCell.self, forCellReuseIdentifier: CreditCell.identifier)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return credits.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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
        let credit = credits[indexPath.row]
        if let url = URL(string: credit.githubURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
