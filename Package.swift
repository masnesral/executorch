// swift-tools-version:5.9
/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import PackageDescription

let version = "0.8.0.20250716"
let url = "https://ossci-ios.s3.amazonaws.com/executorch/"
let debug_suffix = "_debug"
let dependencies_suffix = "_with_dependencies"

func deliverables(_ dict: [String: [String: Any]]) -> [String: [String: Any]] {
  dict
    .reduce(into: [String: [String: Any]]()) { result, pair in
      let (key, value) = pair
      result[key] = value
      result[key + debug_suffix] = value
    }
    .reduce(into: [String: [String: Any]]()) { result, pair in
      let (key, value) = pair
      var newValue = value
      if key.hasSuffix(debug_suffix) {
        for (k, v) in value where k.hasSuffix(debug_suffix) {
          let trimmed = String(k.dropLast(debug_suffix.count))
          newValue[trimmed] = v
        }
      }
      result[key] = newValue.filter { !$0.key.hasSuffix(debug_suffix) }
    }
}

let products = deliverables([
  "backend_coreml": [
    "sha256": "4c4e685002e8b927f6b16f336a741d2d3770526ab718f82bcf75689f46fbf3b5",
    "sha256" + debug_suffix: "26bd7cc299b58975caf66c92e1ff445d579ea509f74ab98cd3e2326f55d45611",
    "frameworks": [
      "Accelerate",
      "CoreML",
    ],
    "libraries": [
      "sqlite3",
    ],
  ],
  "backend_mps": [
    "sha256": "255a91f6b970c4c0f509641cd64032ded445ff571d2e0a5e9ea0224acd4d3edb",
    "sha256" + debug_suffix: "dd3228e6a76d9733c615c49ef0d515febfed0994c98bd5acf6396cc5a55baddb",
    "frameworks": [
      "Metal",
      "MetalPerformanceShaders",
      "MetalPerformanceShadersGraph",
    ],
  ],
  "backend_xnnpack": [
    "sha256": "facc2b68713317cfbb25fcb0bb8b6a6b9ddcc08580ba0dab2063c79a94dc15a3",
    "sha256" + debug_suffix: "20e15f6cb8fc0354472d5c9db41c008c6ffddf4afce188aa46031ea61c3d9476",
    "targets": [
      "threadpool",
    ],
  ],
  "executorch": [
    "sha256": "26b70697e00a4f29d50e45366e5508164976cfeee42daaefb06d69e01df6ca21",
    "sha256" + debug_suffix: "3beb9e8cb3c5d7dea751f30f51f3b4a8de2b1017c8b86602069f4de62a23a6aa",
    "libraries": [
      "c++",
    ],
  ],
  "kernels_llm": [
    "sha256": "c276efd2b49a857065fe9cc84409c25c5c5959e703bdbd408236a71e61f2a7aa",
    "sha256" + debug_suffix: "090e460ec03ba60dfe8a0637d9c8cfaa53323001ab9344f0fa6a693267f2d94b",
  ],
  "kernels_optimized": [
    "sha256": "72a6b0464757bc2442eb63659ebb079ac89f5a078aca0fed3ad2ede8b20def31",
    "sha256" + debug_suffix: "35df0c7d821e1591990fcc2bf5428b97cc6bbe01f0f6c3def65447a00b29224b",
    "frameworks": [
      "Accelerate",
    ],
    "targets": [
      "threadpool",
    ],
  ],
  "kernels_quantized": [
    "sha256": "637b16c65c8568d81893d3fb87d49da99a4c958d1beb78da648a3100f59bb086",
    "sha256" + debug_suffix: "d73b714173c13afa4cbcb40322b56248f2e5a1081aadd2c49a953f75dcfa6551",
  ],
])

let targets = deliverables([
  "threadpool": [
    "sha256": "4eefcd039953daab0db224e0086d127df1cd16639725ccd3006183e6db1047ed",
    "sha256" + debug_suffix: "a7a27877a6c6d768ad801d0884057d8a6fde954796f9593dfc7cd0198113f505",
  ],
])

let packageProducts: [Product] = products.keys.map { key -> Product in
  .library(name: key, targets: ["\(key)\(dependencies_suffix)"])
}.sorted { $0.name < $1.name }

var packageTargets: [Target] = []

for (key, value) in targets {
  packageTargets.append(.binaryTarget(
    name: key,
    url: "\(url)\(key)-\(version).zip",
    checksum: value["sha256"] as? String ?? ""
  ))
}

for (key, value) in products {
  packageTargets.append(.binaryTarget(
    name: key,
    url: "\(url)\(key)-\(version).zip",
    checksum: value["sha256"] as? String ?? ""
  ))
  let target: Target = .target(
    name: "\(key)\(dependencies_suffix)",
    dependencies: ([key] + (value["targets"] as? [String] ?? []).map {
      key.hasSuffix(debug_suffix) ? $0 + debug_suffix : $0
    }).map { .target(name: $0) },
    path: ".Package.swift/\(key)",
    linkerSettings:
      (value["frameworks"] as? [String] ?? []).map { .linkedFramework($0) } +
      (value["libraries"] as? [String] ?? []).map { .linkedLibrary($0) }
  )
  packageTargets.append(target)
}

let package = Package(
  name: "executorch",
  platforms: [
    .iOS(.v17),
    .macOS(.v12),
  ],
  products: packageProducts,
  targets: packageTargets
)
