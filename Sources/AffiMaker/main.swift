// main.swift

// 参考　http://seiya-orz.hatenablog.com/entry/2018/01/21/154249

import Alamofire
import Cocoa
import CryptoSwift
import Foundation
import SWXMLHash

let associateTag = "gikohadiary-22"
let amazonAccessKey = "--replace your amazon access key--"
let amazonSecretKey = // "--replace your amazon secret key--"

extension Date
{
    func jpDate(_ format: String = "yyyy/MM/dd") -> String
    {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension String
{
    func urlAWSQueryEncoding() -> String
    {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-")
        if let ret = addingPercentEncoding(withAllowedCharacters: allowedCharacters)
        {
            return ret
        }
        return ""
    }

    func hmac(key: String) -> String
    {
        guard let keyBytes = key.data(using: .utf8)?.bytes, let mesBytes = data(using: .utf8)?.bytes else
        {
            return ""
        }
        let hmac = try! HMAC(key: keyBytes, variant: .sha256).authenticate(mesBytes)
        return Data(hmac).base64EncodedString()
    }
}

let args = CommandLine.arguments.dropFirst()

guard let asin = args.first, !asin.isEmpty else
{
    print("ERROR: please input ASIN")
    exit(1)
}

var keepAlive = true
var parameters = "AWSAccessKeyId=" + amazonAccessKey
parameters += "&AssociateTag=" + associateTag
parameters += "&ItemId=" + asin // "B07XHJ821V"
parameters += "&Operation=" + "ItemLookup"
parameters += "&Service=" + "AWSECommerceService"
parameters += "&Timestamp=" + Date().jpDate("yyyy-MM-dd'T'HH:mm:ssZZZZZ").urlAWSQueryEncoding()
let target = "GET\nwebservices.amazon.co.jp\n/onca/xml\n\(parameters)"
let signature = target.hmac(key: amazonSecretKey).urlAWSQueryEncoding()
let url = "https://webservices.amazon.co.jp/onca/xml?\(parameters)&Signature=\(signature)"

AF.request(url).response { response in
    keepAlive = false
    if let data = response.data
    {
        let xml = SWXMLHash.parse(String(data: data, encoding: .utf8)!)
        let title = xml["ItemLookupResponse"]["Items"]["Item"]["ItemAttributes"]["Title"].element?.text
        if title == nil
        {
            let errmsg = xml["ItemLookupResponse"]["Items"]["Request"]["Errors"]["Error"]["Message"].element?.text
            print("Error: \(errmsg!)")
        }
        else
        {
            let itemurl = xml["ItemLookupResponse"]["Items"]["Item"]["DetailPageURL"].element?.text
            print("<a href=\"\(itemurl!)\">\(title!)</a>")
        }
    }
}

let runLoop = RunLoop.current
while keepAlive, runLoop.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 0.1))
{}

exit(0)
