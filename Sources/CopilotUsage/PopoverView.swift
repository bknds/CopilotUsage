import SwiftUI

// MARK: - Main Popover View

struct CopilotPopoverView: View {
    @ObservedObject var service: GitHubCopilotService

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            mainBody
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .environment(\.font, .custom("IBMPlexMono", size: 13))
        .overlay {
            if service.isLoading {
                ZStack {
                    Color(NSColor.windowBackgroundColor).opacity(0.7)
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(spacing: 8) {
            CopilotIcon(size: 16)
            Text("Copilot")
                .font(.ibm.headline)
                .fontWeight(.semibold)

            Spacer()

            if let data = service.usageData {
                Text("重置: \(data.nextBillingDate)")
                    .font(.ibm.caption)
                    .foregroundColor(.secondary)
                Text(data.planType)
                    .font(.ibm.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.quaternaryLabelColor))
                    .cornerRadius(4)
            }

            if case .authorized = service.authState {
                Button(action: { Task { await service.fetchUsage() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.ibm.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Main Body

    @ViewBuilder
    private var mainBody: some View {
        switch service.authState {
        case .notAuthorized:
            loginView
        case .authorizing(let userCode, let uri):
            authorizingView(userCode: userCode, uri: uri)
        case .authorized:
            if let data = service.usageData {
                contentView(data: data)
            } else if let err = service.errorMessage {
                errorView(message: err)
            } else if !service.isLoading {
                loadingView
            }
        }
    }

    // MARK: Login View

    private var loginView: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.custom("IBMPlexMono", size: 36))
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text("尚未关联 GitHub 账号")
                    .font(.ibm.subheadline)
                    .fontWeight(.medium)
                if let err = service.errorMessage {
                    Text(err)
                        .font(.ibm.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: {
                Task { await service.startDeviceFlow() }
            }) {
                Label("一键关联 GitHub 账号", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("退出") {
                let alert = NSAlert()
                alert.messageText = "确认退出"
                alert.informativeText = "退出后菜单栏图标将消失。"
                alert.addButton(withTitle: "退出")
                alert.addButton(withTitle: "取消")
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.ibm.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: Authorizing View

    private func authorizingView(userCode: String, uri: String) -> some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(0.9)

            Text("在浏览器中授权")
                .font(.ibm.subheadline)
                .fontWeight(.medium)

            Text("浏览器已打开，请在页面中输入验证码：")
                .font(.ibm.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // User code display
            Text(userCode)
                .font(.custom("IBMPlexMono", size: 28).weight(.bold))
                .tracking(6)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

            HStack(spacing: 8) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                }) {
                    Label("复制验证码", systemImage: "doc.on.doc")
                        .font(.ibm.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    if let url = URL(string: uri) { NSWorkspace.shared.open(url) }
                }) {
                    Label("重新打开浏览器", systemImage: "safari")
                        .font(.ibm.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button("取消") { service.logout() }
                .buttonStyle(.plain)
                .font(.ibm.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: Content View

    private func contentView(data: CopilotUsageData) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                infoRow(label: "订阅", value: "$\(String(format: "%.0f", data.subscriptionCost))/人/月")
                infoRow(label: "Premium 超额单价", value: "$\(String(format: "%.2f", data.premiumUnitPrice))/次")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Premium")
                        .font(.ibm.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    let pct = data.usagePercent
                    Text("\(data.premiumUsed) / \(data.premiumIncluded)（\(pct)%）")
                        .font(.ibm.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(pct > 100 ? .red : .primary)
                }

                ProgressBarView(percent: data.usagePercent)
                    .frame(height: 6)
            }
            .padding(.horizontal, 16)

            if data.overageCount > 0 {
                HStack(spacing: 4) {
                    Text("超额 \(data.overageCount) 次  ·  预估费用")
                        .font(.ibm.caption)
                        .foregroundColor(.red)
                    Text("$\(String(format: "%.2f", data.overageCost))")
                        .font(.ibm.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("(= ¥\(String(format: "%.0f", data.overageCost * service.settings.cnyRate)))")
                        .font(.ibm.caption)
                        .foregroundColor(Color.red.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }

            HStack {
                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = "确认登出"
                    alert.informativeText = "登出后需要重新关联 GitHub 账号。"
                    alert.addButton(withTitle: "登出")
                    alert.addButton(withTitle: "取消")
                    alert.alertStyle = .warning
                    if alert.runModal() == .alertFirstButtonReturn {
                        service.logout()
                    }
                }) {
                    Label("登出", systemImage: "person.badge.minus")
                        .font(.ibm.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                Spacer()
                Text("每 5 分钟自动刷新")
                    .font(.ibm.caption2)
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                Spacer()
                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = "确认退出"
                    alert.informativeText = "退出后菜单栏图标将消失。"
                    alert.addButton(withTitle: "退出")
                    alert.addButton(withTitle: "取消")
                    alert.alertStyle = .warning
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSApplication.shared.terminate(nil)
                    }
                }) {
                    Text("退出")
                        .font(.ibm.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if let release = service.newRelease {
                Divider()
                Button(action: {
                    if case .idle = service.updateState {
                        Task { await service.installUpdate() }
                    } else if case .failed = service.updateState {
                        service.updateState = .idle
                        Task { await service.installUpdate() }
                    }
                }) {
                    HStack(spacing: 6) {
                        switch service.updateState {
                        case .idle:
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("有新版本 v\(release.version)，点击自动更新")
                                .font(.ibm.caption)
                                .foregroundColor(.accentColor)
                        case .downloading(let progress):
                            ProgressView(value: progress)
                                .frame(width: 60)
                            Text("下载中 \(Int(progress * 100))%")
                                .font(.ibm.caption)
                                .foregroundColor(.secondary)
                        case .installing:
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("安装中...")
                                .font(.ibm.caption)
                                .foregroundColor(.secondary)
                        case .failed(let msg):
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(msg)
                                .font(.ibm.caption)
                                .foregroundColor(.orange)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled({
                    if case .downloading = service.updateState { return true }
                    if case .installing = service.updateState { return true }
                    return false
                }())
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.ibm.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.ibm.subheadline)
        }
        .padding(.vertical, 2)
    }

    // MARK: State Views

    private var loadingView: some View {
        HStack {
            ProgressView().scaleEffect(0.7)
            Text("加载中...").font(.ibm.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
            Text(message)
                .font(.ibm.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") { Task { await service.fetchUsage() } }
                .buttonStyle(.bordered).controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    let percent: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(NSColor.separatorColor))

                let ratio = min(Double(percent) / 100.0, 1.0)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: max(ratio * geo.size.width, 0))
            }
        }
    }

    private var barColor: Color {
        if percent > 100 { return .red }
        if percent > 80 { return .orange }
        return .accentColor
    }
}
