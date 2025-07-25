//
//  FileList.swift
//  LindDE
//
//  Created by lindsey on 05.05.25.
//

import UIKit
import UniformTypeIdentifiers

class FileListViewController: UIThemedTableViewController, UIDocumentPickerDelegate {
    let project: AppProject
    let path: String
    var entries: [FileListEntry]
    let isSublink: Bool
    var openTheLogSheet: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "LDEReopened")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LDEReopened")
        }
    }
    
    init(
        isSublink: Bool = false,
        project: AppProject,
        path: String? = nil
    ) {
        Author.shared.setTargetProject(project.projectConfig.displayname)
        
        self.project = project
        self.path = path ?? project.getPath()
        self.entries = FileListEntry.getEntries(ofPath: self.path)
        self.isSublink = isSublink
        super.init(style: .insetGrouped)
        
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(performRefresh), for: .valueChanged)
    }
    
    @objc func performRefresh() {
        guard let visibleRows = tableView.indexPathsForVisibleRows else { return }

        UIView.animate(withDuration: 0.3, animations: {
            for indexPath in visibleRows {
                if let cell = self.tableView.cellForRow(at: indexPath) {
                    cell.alpha = 0
                    cell.transform = CGAffineTransform(translationX: 0, y: 20)
                }
            }
        }, completion: { _ in
            self.entries = FileListEntry.getEntries(ofPath: self.path)
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()

            let newVisibleRows = self.tableView.indexPathsForVisibleRows ?? []
            for indexPath in newVisibleRows {
                if let cell = self.tableView.cellForRow(at: indexPath) {
                    cell.alpha = 0
                    cell.transform = CGAffineTransform(translationX: 0, y: 20)
                }
            }

            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut], animations: {
                for indexPath in newVisibleRows {
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        cell.alpha = 1
                        cell.transform = .identity
                    }
                }
            }, completion: nil)

            self.refreshControl?.endRefreshing()
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !self.isSublink {
            LDELogger.log(forProject: self.project)
        }
        
        self.title = self.isSublink ? URL(fileURLWithPath: self.path).lastPathComponent : project.projectConfig.displayname
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        if UIDevice.current.userInterfaceIdiom == .pad, !self.isSublink {
            self.navigationItem.setLeftBarButton(UIBarButtonItem(primaryAction: UIAction(title: "Close") { _ in
                UserDefaults.standard.set(nil, forKey: "LDELastProjectSelected")
                self.dismiss(animated: true)
            }), animated: false)
        }
        self.navigationItem.setRightBarButton(UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), primaryAction: nil, menu: generateMenu()), animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.isSublink {
            if self.project.reload() {
                self.title = self.project.projectConfig.displayname
            }
            
            if self.project.projectConfig.restartApp {
                if self.openTheLogSheet {
                    let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
                    loggerView.modalPresentationStyle = .formSheet
                    self.present(loggerView, animated: true)
                    self.openTheLogSheet = false
                }
            }
        }
    }
    
    func generateMenu() -> UIMenu {
        var rootMenuChildren: [UIMenu] = []
        
        // Project Roots Menu in case its the root of the project obviously
        if !self.isSublink, UIDevice.current.userInterfaceIdiom != .pad {
            var projectMenuElements: [UIMenuElement] = []
            projectMenuElements.append(UIAction(title: "Build", image: UIImage(systemName: "hammer.fill"), handler: { _ in
                self.buildProject()
            }))
            projectMenuElements.append(UIAction(title: "Issue Navigator", image: UIImage(systemName: "exclamationmark.triangle.fill"), handler: { _ in
                let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
                loggerView.modalPresentationStyle = .formSheet
                self.present(loggerView, animated: true)
            }))
            projectMenuElements.append(UIAction(title: "Log", image: UIImage(systemName: {
                if #available(iOS 17.0, *) {
                    return "apple.terminal.fill"
                } else {
                    return "waveform.path.ecg.rectangle.fill"
                }
            }()), handler: { _ in
                let loggerView = UINavigationController(rootViewController: LoggerViewController())
                loggerView.modalPresentationStyle = .formSheet
                self.present(loggerView, animated: true)
            }))
            
            rootMenuChildren.append({
                if #available(iOS 17.0, *) {
                    return UIMenu(title: "Project", options: [.displayAsPalette, .displayInline], children: projectMenuElements.reversed())
                } else {
                    return UIMenu(title: "Project", options: [.displayInline], children: projectMenuElements)
                }
            }())
        }
        
        // The generic file system menu
        enum CreateEntryMode {
            case file
            case folder
        }
        
        func createEntry(mode: CreateEntryMode) {
            let alert: UIAlertController = UIAlertController(
                title: "Create \((mode == .file) ? "File" : "Folder")",
                message: nil,
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.placeholder = "Name"
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Submit", style: .default) { _ in
                let destination: URL = URL(fileURLWithPath: self.path).appendingPathComponent(alert.textFields![0].text ?? "")
                
                var isDirectory: ObjCBool = ObjCBool(false)
                if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
                    self.presentConfirmationAlert(
                        title: mode == .folder ? "Error" : "Warning",
                        message: "\(isDirectory.boolValue ? "Folder" : "File") with the name \"\(destination.lastPathComponent)\" already exists. \(!isDirectory.boolValue ? "" : "Folders cannot be removed!")",
                        confirmTitle: "Overwrite",
                        confirmStyle: .destructive,
                        confirmHandler: {
                            try? String(getFileContentForName(filename: destination.lastPathComponent)).write(to: destination, atomically: true, encoding: .utf8)
                            self.replaceFile(destination: destination)
                        },
                        addHandler: mode == .file && !isDirectory.boolValue
                    )
                } else {
                    if mode == .file {
                        try? String(getFileContentForName(filename: destination.lastPathComponent)).write(to: destination, atomically: true, encoding: .utf8)
                    } else {
                        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
                    }
                    self.addFile(destination: destination)
                }
            })
            
            self.present(alert, animated: true)
        }
        
        var fileMenuElements: [UIMenuElement] = []
        var createMenuElements: [UIMenuElement] = []
        createMenuElements.append(UIAction(title: "File", image: UIImage(systemName: "doc.fill"), handler: { _ in
            createEntry(mode: .file)
        }))
        createMenuElements.append(UIAction(title: "Folder", image: UIImage(systemName: "folder.fill"), handler: { _ in
            createEntry(mode: .folder)
        }))
        fileMenuElements.append(UIMenu(title: "New", image: UIImage(systemName: "plus.circle.fill"), children: createMenuElements))
        fileMenuElements.append(UIAction(title: "Paste", image: UIImage(systemName: {
            if #available(iOS 16.0, *) {
                return "list.bullet.clipboard.fill"
            } else {
                return "doc.on.doc.fill"
            }
        }()), handler: { _ in
            let destination: URL = URL(fileURLWithPath: self.path).appendingPathComponent(URL(fileURLWithPath: PasteBoardServices.path).lastPathComponent)
            
            var isDirectory: ObjCBool = ObjCBool(false)
            if FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory) {
                self.presentConfirmationAlert(
                    title: isDirectory.boolValue ? "Error" : "Warning",
                    message: "\(isDirectory.boolValue ? "Folder" : "File") with the name \"\(destination.lastPathComponent)\" already exists. \(isDirectory.boolValue ? "Folder cannot be overwritten" : "Do you want to overwrite it?")",
                    confirmTitle: "Overwrite",
                    confirmStyle: .destructive,
                    confirmHandler: {
                        PasteBoardServices.paste(path: self.path)
                        self.replaceFile(destination: destination)
                    },
                    addHandler: !isDirectory.boolValue
                )
            } else {
                PasteBoardServices.paste(path: self.path)
                self.addFile(destination: destination)
            }
        }))
        fileMenuElements.append(UIAction(title: "Import", image: UIImage(systemName: "square.and.arrow.down.fill")) { _ in
            let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            documentPicker.allowsMultipleSelection = true
            documentPicker.modalPresentationStyle = .pageSheet
            documentPicker.delegate = self
            self.present(documentPicker, animated: true)
        })
        
        rootMenuChildren.append(UIMenu(title: "File", options: [.displayInline], children: fileMenuElements))
        
        return UIMenu(children: rootMenuChildren)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // TODO: Add handling for overwrite and stuff... like keep,rename,overwrite. We also should merge these functions as thats the 3rd time copying those.
        for url in urls {
            let fileName: String = url.lastPathComponent
            let destination: URL = URL(fileURLWithPath: self.path).appendingPathComponent(fileName)
            
            do {
                try FileManager.default.moveItem(at: url, to: destination)
                replaceOrAddFile(destination: destination)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            let copyAction = UIAction(title: "Copy", image: UIImage(systemName: {
                if #available(iOS 17.0, *) {
                    return "document.on.clipboard"
                } else {
                    return "doc.on.doc.fill"
                }
            }())) { action in
                PasteBoardServices.copy(mode: .copy, path: self.entries[indexPath.row].path)
            }
            let moveAction = UIAction(title: "Move", image: UIImage(systemName: "arrow.right")) { action in
                PasteBoardServices.onMove = {
                    self.entries.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
                PasteBoardServices.copy(mode: .move, path: self.entries[indexPath.row].path)
            }
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "rectangle.and.pencil.and.ellipsis")) { action in
                let entry: FileListEntry = self.entries[indexPath.row]
                
                let alert: UIAlertController = UIAlertController(
                    title: "Rename \(entry.type == .dir ? "Folder" : "File")",
                    message: nil,
                    preferredStyle: .alert
                )
                
                alert.addTextField { textField in
                    textField.placeholder = "Filename"
                    textField.text = entry.name
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { _ in
                    try? FileManager.default.moveItem(atPath: "\(self.path)/\(entry.name)", toPath: "\(self.path)/\(alert.textFields![0].text ?? "0")")
                    
                    self.entries.remove(at: indexPath.row)
                    self.entries.append(FileListEntry.getEntry(ofPath: "\(self.path)/\(alert.textFields![0].text ?? "0")"))
                    self.tableView.reloadData()
                }))
                
                self.present(alert, animated: true)
            }
            let shareAction = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up.fill")) { action in
                let entry: FileListEntry = self.entries[indexPath.row]
                share(url: URL(fileURLWithPath: "\(self.path)/\(entry.name)"), remove: false)
            }
            let deleteAction = UIAction(title: "Remove", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { action in
                let entry = self.entries[indexPath.row]
                let fileUrl: URL = URL(fileURLWithPath: "\(self.path)/\(entry.name)")
                if ((try? FileManager.default.removeItem(at: fileUrl)) != nil) {
                    let database: DebugDatabase = DebugDatabase.getDatabase(ofPath: "\(self.project.getCachePath())/debug.json")
                    database.removeFileDebug(ofPath: fileUrl.path)
                    database.saveDatabase(toPath: "\(self.project.getCachePath())/debug.json")
                    self.entries.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            }
            
            return UIMenu(children: [UIMenu(options: .displayInline, children: [copyAction, moveAction, renameAction]),
                                     UIMenu(options: .displayInline, children: [shareAction, deleteAction])])
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.entries.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        if !self.navigationItem.hidesBackButton {
            let fileListEntry: FileListEntry = self.entries[indexPath.row]
            
            if fileListEntry.type == .dir {
                let fileVC = FileListViewController(
                    isSublink: true,
                    project: project,
                    path: fileListEntry.path
                )
                self.navigationController?.pushViewController(fileVC, animated: true)
            } else {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",fileListEntry.path])
                } else {
                    let fileVC = UINavigationController(rootViewController: CodeEditorViewController(
                        project: project,
                        path: fileListEntry.path
                    ))
                    fileVC.modalPresentationStyle = .overFullScreen
                    self.present(fileVC, animated: true)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        
        let entry = self.entries[indexPath.row]
        let path = entry.path // Assuming entry.path is a valid file path as String
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        
        cell.accessoryType = (entry.type == .dir) ? .disclosureIndicator : .none
        cell.textLabel?.text = url.deletingPathExtension().lastPathComponent
        cell.separatorInset = .zero
        
        // Remove default imageView
        cell.imageView?.isHidden = true
        
        // Add custom preview icon view
        let iconView = UIView(frame: CGRect(x: 15, y: 7, width: 25, height: 25))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .light)
        label.translatesAutoresizingMaskIntoConstraints = false

        if entry.type == .file {
            switch ext {
            case "c":
                label.text = "c"
                label.textColor = .systemBlue
                iconView.addSubview(label)
            case "h":
                label.text = "h"
                label.textColor = .systemGray
                iconView.addSubview(label)
            case "cpp":
                addStackedLabel(to: iconView, base: "c", offset: CGPoint(x: 8, y: -5), color: .systemBlue)
            case "hpp":
                addStackedLabel(to: iconView, base: "h", offset: CGPoint(x: 8, y: -5), color: .systemBlue)
            case "m":
                label.text = "m"
                label.textColor = .systemPurple
                iconView.addSubview(label)
            case "mm":
                addStackedLabel(to: iconView, base: "m", offset: CGPoint(x: 9, y: -6), color: .systemBlue)
            case "plist":
                addSystemImage(to: iconView, name: "tablecells.fill")
            case "zip","tar","zst":
                addSystemImage(to: iconView, name: "doc.fill")
            case "ipa":
                addSystemImage(to: iconView, name: "app.gift.fill")
            default:
                addSystemImage(to: iconView, name: "text.page.fill")
            }
        } else {
            addSystemImage(to: iconView, name: "folder.fill")
        }
        
        cell.contentView.addSubview(iconView)

        var constraints: [NSLayoutConstraint] = [
            iconView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 15),
            iconView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25)
        ]

        if label.superview != nil {
            constraints.append(contentsOf: [
                label.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
            ])
        }

        NSLayoutConstraint.activate(constraints)
        
        cell.textLabel?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.textLabel!.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            cell.textLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        return cell
    }
    
    private func addStackedLabel(to view: UIView, base: String, offset: CGPoint, color: UIColor) {
        let baseLabel = UILabel()
        baseLabel.text = base
        baseLabel.font = .systemFont(ofSize: 20, weight: .light)
        baseLabel.textColor = color
        baseLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let plusLabel = UILabel()
        plusLabel.text = "+"
        plusLabel.font = .systemFont(ofSize: 10, weight: .light)
        plusLabel.textColor = color
        plusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(baseLabel)
        view.addSubview(plusLabel)

        NSLayoutConstraint.activate([
            baseLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            baseLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            plusLabel.leadingAnchor.constraint(equalTo: baseLabel.trailingAnchor, constant: offset.x),
            plusLabel.topAnchor.constraint(equalTo: baseLabel.topAnchor, constant: offset.y)
        ])
    }
    
    private func addSystemImage(to view: UIView, name: String, tintColor: UIColor? = nil) {
        let imageView = UIImageView(image: UIImage(systemName: name))
        imageView.contentMode = .scaleAspectFit
        if let tintColor = tintColor {
            imageView.tintColor = tintColor
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    ///
    /// Private: Function to add or replace a file or files in the array
    ///
    private func addFile(destination: URL) {
        self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
        let newIndexPath = IndexPath(row: self.entries.count - 1, section: 0)
        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
    
    private func replaceFile(destination: URL) {
        let index = self.entries.firstIndex(where: { $0.name == destination.lastPathComponent} )
        if let index {
            self.entries.remove(at: index)
            let oldIndexPath = IndexPath(row: index, section: 0)
            self.tableView.deleteRows(at: [oldIndexPath], with: .automatic)
        }
        
        self.entries.append(FileListEntry.getEntry(ofPath: destination.path))
        let newIndexPath = IndexPath(row: self.entries.count - 1, section: 0)
        self.tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
    
    private func replaceOrAddFile(destination: URL) {
        if FileManager.default.fileExists(atPath: destination.path) {
            replaceFile(destination: destination)
        } else {
            addFile(destination: destination)
        }
    }
    
    ///
    /// Private: Function to initiate building the app
    ///
    private func buildProject() {
        self.navigationItem.titleView?.isUserInteractionEnabled = false
        XCodeButton.switchImageSync(systemName: "hammer.fill", animated: false)
        LDELogger.clear()
        guard let oldBarButton: UIBarButtonItem = self.navigationItem.rightBarButtonItem else { return }
        let barButton: UIBarButtonItem = UIBarButtonItem(customView: XCodeButton.shared)

        self.navigationItem.setRightBarButton(barButton, animated: true)
        self.navigationItem.setHidesBackButton(true, animated: true)
        
        Builder.buildProject(withProject: project) { result in
            DispatchQueue.main.async {
                self.navigationItem.setRightBarButton(oldBarButton, animated: true)
                self.navigationItem.setHidesBackButton(false, animated: true)
                
                if result && self.project.projectConfig.restartAppOnSucceed {
                    exit(0)
                } else if !result {
                    if self.project.projectConfig.restartAppOnSucceed {
                        self.openTheLogSheet = true
                        restartProcess()
                    } else {
                        let loggerView = UINavigationController(rootViewController: UIDebugViewController(project: self.project))
                        loggerView.modalPresentationStyle = .formSheet
                        self.present(loggerView, animated: true)
                    }
                }
            }
        }
    }
}

func share(url: URL, remove: Bool = false) -> Void {
    let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    activityViewController.modalPresentationStyle = .popover
        if remove {
        activityViewController.completionWithItemsHandler = { activity, success, items, error in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
            }
        }
    }

    DispatchQueue.main.async {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let rootViewController = windowScene.windows.first?.rootViewController {
                if let popoverController = activityViewController.popoverPresentationController {
                    popoverController.sourceView = rootViewController.view
                    popoverController.sourceRect = CGRect(x: rootViewController.view.bounds.midX,
                                                      y: rootViewController.view.bounds.midY,
                                                      width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                rootViewController.present(activityViewController, animated: true, completion: nil)
            } else {
                print("No root view controller found.")
            }
        } else {
            print("No window scene found.")
        }
    }
}
