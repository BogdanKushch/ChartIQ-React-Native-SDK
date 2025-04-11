import ChartIQ
import WebKit

@objc(ChartIqWrapperView)
class ChartIqWrapperView: UIView {
    internal var chartIQView: ChartIQView!
    internal var chartIQDatasource: ChartIQDataSource!
    public var chartIQHelper: ChartIQHelper!
    internal var chartIQDelegate: ChartIQDelegate!
    internal var updateStartParam: String = ""
    internal var pagingStartParam: String = ""
    let defaultQueue = DispatchQueue.main

    @objc var url: String = "" {
        didSet {
            do {
                print("[ChartIQ] Setting chart URL: \(url)")
                chartIQView.setChartIQUrl(url)
                print("[ChartIQ] Chart URL set successfully")
            } catch {
                print("[ChartIQ] Error setting chart URL: \(error.localizedDescription)")
            }
        }
    }
    
    @objc var dataMethod: String = "pull" {
        didSet {
            do {
                print("[ChartIQ] Setting data method: \(dataMethod)")
                chartIQView.setDataMethod(dataMethod == "push" ? .push : .pull)
                print("[ChartIQ] Data method set successfully")
            } catch {
                print("[ChartIQ] Error setting data method: \(error.localizedDescription)")
            }
        }
    }
 
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Create ChartIQView with frame only
        chartIQView = ChartIQView(frame: frame)
        
        // Configure web view after creation
        if let webView = chartIQView.getWebView() as? WKWebView {
            if #available(iOS 14.0, *) {
                webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            } else {
                // For older iOS versions
                #if swift(>=5.7)
                // Use the new API if available
                webView.configuration.preferences.javaScriptEnabled = true
                #else
                // Use the deprecated API for older Swift versions
                webView.configuration.preferences.setValue(true, forKey: "allowsContentJavaScript")
                #endif
            }
            webView.configuration.allowsInlineMediaPlayback = true
        }
        
        setUpChart()
    }
    
    func setUpChart() {
        do {
            print("[ChartIQ] Starting chart setup")
            chartIQView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(chartIQView)
            
            // Add web view configuration logging
            if let webView = chartIQView.getWebView() as? WKWebView {
                print("[ChartIQ] WebView configuration:")
                webView.configuration.websiteDataStore = .default()  // Use default data store
                webView.configuration.processPool = WKProcessPool()  // Use shared process pool
                
                print("[ChartIQ] - AllowsBackForwardNavigationGestures: \(webView.allowsBackForwardNavigationGestures)")
                print("[ChartIQ] - AllowsLinkPreview: \(webView.allowsLinkPreview)")
                print("[ChartIQ] - Configuration preferences: \(webView.configuration.preferences)")
                
                // Check privacy settings
                if #available(iOS 14.0, *) {
                    print("[ChartIQ] WebView privacy settings:")
                    print("[ChartIQ] - AllowsAirPlayForMediaPlayback: \(webView.configuration.allowsAirPlayForMediaPlayback)")
                    print("[ChartIQ] - AllowsPictureInPictureMediaPlayback: \(webView.configuration.allowsPictureInPictureMediaPlayback)")
                }
                
                // Set navigation delegate
                webView.navigationDelegate = self
                print("[ChartIQ] Set navigation delegate")
            }
            
            if #available(iOS 16.4, *) {
                if let webView = chartIQView.getWebView() as? WKWebView {
                    print("[ChartIQ] Checking web view inspectability")
                    if(!webView.isInspectable){
                        webView.isInspectable = true
                    }
                    print("[ChartIQ] Web view inspectable: \(webView.isInspectable)")
                }
            }
            
            chartIQView.dataSource = self
            chartIQView.delegate = self
            print("[ChartIQ] Chart setup completed successfully")
            
        } catch {
            print("[ChartIQ] Error during chart setup: \(error.localizedDescription)")
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ChartIqWrapperView: ChartIQDataSource {
    func pullInitialData(by params: ChartIQ.ChartIQQuoteFeedParams, completionHandler: @escaping ([ChartIQ.ChartIQData]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
            let id = UUID().uuidString
            self.chartIQHelper.onPullInitialCompleationHandlers.append(RNPullCallback(callback: completionHandler, id: id))
            RTEEventEmitter.shared?.emitEvent(withName: .dispatchOnPullInitial, body: self.convertParams(params: params, id: id))
        }
    }
    
    func pullUpdateData(by params: ChartIQ.ChartIQQuoteFeedParams, completionHandler: @escaping ([ChartIQ.ChartIQData]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
            let id = UUID().uuidString
            self.chartIQHelper.onPullUpdateCompleationHandlers.append(RNPullCallback(callback: completionHandler, id: id))
            RTEEventEmitter.shared?.emitEvent(withName: .dispatchOnPullUpdate, body: self.convertParams(params: params, id: id))
        }
    }
    
    func pullPaginationData(by params: ChartIQ.ChartIQQuoteFeedParams, completionHandler: @escaping ([ChartIQ.ChartIQData]) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0) {
            let id = UUID().uuidString
            self.chartIQHelper.onPullPagingCompleationHandlers.append(RNPullCallback(callback: completionHandler, id: id))
            RTEEventEmitter.shared?.emitEvent(withName: .dispatchOnPullPaging, body: self.convertParams(params: params, id: id))
        }
    }
    
    func convertParams(params: ChartIQ.ChartIQQuoteFeedParams, id: String) -> [AnyHashable: Any] {
        return ["quoteFeedParam": [
            "symbol": params.symbol,
            "start": params.startDate,
            "end": params.endDate,
            "interval": params.interval,
            "period": params.period,
            "id": id
        ] as [String: Any]]
    }
}

extension ChartIqWrapperView: RCTInvalidating {
    func invalidate() {
        chartIQHelper = nil
        chartIQView = nil
        chartIQDatasource = nil
        chartIQDelegate = nil
    }
}

extension ChartIqWrapperView: ChartIQDelegate {
    func chartIQViewDidFinishLoading(_ chartIQView: ChartIQ.ChartIQView) {
        do {
            print("[ChartIQ] ChartIQ view finished loading")
            chartIQView.setVoiceoverFields(default: true)
            print("[ChartIQ] Voiceover fields set to default")
            RTEEventEmitter.shared?.emitEvent(withName: .dispatchOnChartStart, body: "chartIQViewDidFinishLoading")
            print("[ChartIQ] Emitted chart start event")
        } catch {
            print("[ChartIQ] Error in chartIQViewDidFinishLoading: \(error.localizedDescription)")
        }
    }
    
    func chartIQView(_ chartIQView: ChartIQView, didUpdateMeasure measure: String) {
        do {
            print("[ChartIQ] Measure updated: \(measure)")
            if !measure.isEmpty {
                defaultQueue.async {
                    print("[ChartIQ] Emitting measure update event")
                    RTEEventEmitter.shared?.emitEvent(withName: .dispatchOnMeasureUpdate, body: measure)
                }
            }
        } catch {
            print("[ChartIQ] Error in measure update: \(error.localizedDescription)")
        }
    }
    
    func chartIQView(_ chartIQView: ChartIQView, didReceiveError error: Error) {
        print("[ChartIQ] Error received: \(error.localizedDescription)")
    }
}

extension ChartIqWrapperView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[ChartIQ] WebView started loading")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("[ChartIQ] WebView committed navigation")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[ChartIQ] WebView finished navigation")
        
        // Add a small delay to ensure the web content is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Manually trigger chartIQViewDidFinishLoading if needed
            if let chartView = self.chartIQView {
                self.chartIQViewDidFinishLoading(chartView)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[ChartIQ] WebView navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[ChartIQ] WebView provisional navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("[ChartIQ] WebView navigation policy decision for: \(navigationAction.request.url?.absoluteString ?? "unknown")")
        decisionHandler(.allow)
    }
}
