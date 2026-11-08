#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Maintain the checked-in native Xcode project from module build definitions.

No package manager or generator installation is required. Stable identifiers and
write-if-changed keep Xcode's incremental build graph and local editor state intact.
"""
import hashlib
import json
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "TrainerDock.xcodeproj"


def released_modules():
    return [p.parent for p in sorted((ROOT / "Modules").glob("*/Module.json"))
            if not json.loads((p.parent / "Build.json").read_text()).get("developmentOnly")]


def identifier(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def write_changed(path, content):
    if path.is_file() and path.read_bytes() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def openstep(value, depth=0):
    if isinstance(value, dict):
        lines = ["{"]
        lines += ["\t" * (depth + 1) + json.dumps(k) + " = " + openstep(v, depth + 1) + ";"
                  for k, v in value.items()]
        return "\n".join(lines) + "\n" + "\t" * depth + "}"
    if isinstance(value, list):
        return "(" + ", ".join(openstep(v, depth) for v in value) + ")"
    return str(value) if isinstance(value, int) else json.dumps(str(value), ensure_ascii=False)


def generate():
    objects = {}

    def add(key, isa, **fields):
        uid = identifier(key)
        objects[uid] = dict(isa=isa, **fields)
        return uid

    refs = {}

    def ref(path):
        if path not in refs:
            suffix = Path(path).suffix
            kind = {".m": "sourcecode.c.objc", ".mm": "sourcecode.cpp.objcpp",
                    ".h": "sourcecode.c.h", ".hpp": "sourcecode.cpp.h",
                    ".xcconfig": "text.xcconfig", ".plist": "text.plist.xml", ".png": "image.png"}.get(suffix, "text")
            refs[path] = add("file:" + path, "PBXFileReference", lastKnownFileType=kind,
                             path=path, sourceTree="SOURCE_ROOT")
        return refs[path]

    config = ref("Config/TrainerDock.xcconfig")

    def configurations(key, settings):
        configs = []
        for name in ("Debug", "Release"):
            options = dict(settings)
            if key == "TrainerDock" and name == "Debug":
                options["CODE_SIGN_INJECT_BASE_ENTITLEMENTS"] = "YES"
            configs.append(add(key + ":" + name, "XCBuildConfiguration", baseConfigurationReference=config,
                               buildSettings=options, name=name))
        return add(key + ":configs", "XCConfigurationList", buildConfigurations=configs,
                   defaultConfigurationIsVisible=0, defaultConfigurationName="Debug")

    def shell(key, name, action, inputs, outputs, **extra):
        return add(key, "PBXShellScriptBuildPhase", buildActionMask=2147483647, files=[],
                   inputPaths=inputs, outputPaths=outputs, name=name, shellPath="/bin/bash",
                   shellScript='set -euo pipefail\nexport PATH="/opt/homebrew/bin:$PATH"\n'
                               'export PYTHONDONTWRITEBYTECODE=1\n'
                               '/usr/bin/python3 -B "$SRCROOT/script/xcode_support.py" ' + action + '\n',
                   runOnlyForDeploymentPostprocessing=0, **extra)

    products = []
    targets = []

    def native(name, sources, settings, phases_before=(), phases_after=(), app=False, tool=False):
        files = [add(name + ":compile:" + p, "PBXBuildFile", fileRef=ref(p)) for p in sources]
        phase = add(name + ":sources", "PBXSourcesBuildPhase", buildActionMask=2147483647,
                    files=files, runOnlyForDeploymentPostprocessing=0)
        frameworks = add(name + ":frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647,
                         files=[], runOnlyForDeploymentPostprocessing=0)
        phases = [*phases_before, phase, frameworks]
        if app:
            license_file = add("app:license", "PBXBuildFile", fileRef=ref("LICENSE"))
            phases.append(add("app:resources", "PBXResourcesBuildPhase", buildActionMask=2147483647,
                              files=[license_file], runOnlyForDeploymentPostprocessing=0))
            phases.append(shell("app:icon", "Build macOS app icon", "icon",
                                ["$(SRCROOT)/App/Resources/TrainerDock.png", "$(SRCROOT)/script/xcode_support.py"],
                                ["$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/TrainerDock.icns"]))
            phases.append(shell("app:catalog", "Install trainer catalog metadata", "catalog",
                                ["$(SRCROOT)/script/trainer_distribution.py"],
                                ["$(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)/TrainerCatalog.json"],
                                alwaysOutOfDate=1))
        product = add(name + ":product", "PBXFileReference", explicitFileType="wrapper.application" if app else "compiled.mach-o.executable" if tool else "compiled.mach-o.dylib",
                      path="TrainerDock.app" if app else name if tool else "Trainer.dylib", sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        target = add("target:" + name, "PBXNativeTarget", buildConfigurationList=configurations(name, settings),
                     buildPhases=phases + list(phases_after), buildRules=[], dependencies=[], name=name,
                     productName="TrainerDock" if app else name if tool else "Trainer", productReference=product,
                     productType="com.apple.product-type.application" if app else "com.apple.product-type.tool" if tool else "com.apple.product-type.library.dynamic")
        targets.append(target)
        return target

    links = ["$(inherited)", "-framework", "AppKit", "-framework", "Security", "-framework", "QuartzCore",
             "-framework", "Carbon", "-framework", "UniformTypeIdentifiers", "-lc++"]
    sdk_source = "ModuleSDK/MHTProtocol.m"
    broker = native("TrainerDockEpicBroker", ["App/MHTEpicBroker.m", "Core/MHTEpicLaunch.m"], dict(
        PRODUCT_NAME="TrainerDockEpicBroker", MACH_O_TYPE="mh_execute", SKIP_INSTALL="YES",
        CONFIGURATION_BUILD_DIR="$(TRAINERDOCK_BUILD_ROOT)/Xcode/Build/Products/$(CONFIGURATION)/Helpers",
        HEADER_SEARCH_PATHS=["$(SRCROOT)/Core"],
        OTHER_LDFLAGS=["$(inherited)", "-framework", "AppKit", "-framework", "Foundation"]), tool=True)
    broker_file = add("app:broker", "PBXBuildFile", fileRef=objects[broker]["productReference"],
                      settings=dict(ATTRIBUTES=["CodeSignOnCopy"]))
    embed_broker = add("app:embed-broker", "PBXCopyFilesBuildPhase", buildActionMask=2147483647,
                      files=[broker_file], dstPath="", dstSubfolderSpec=6,
                      name="Embed Epic launch broker", runOnlyForDeploymentPostprocessing=0)
    app_sources = [str(p.relative_to(ROOT)) for folder in ("App", "Core")
                   for p in sorted((ROOT / folder).glob("*.m")) if p.name != "MHTEpicBroker.m"] + [sdk_source]
    app = native("TrainerDock", app_sources, dict(
        PRODUCT_NAME="TrainerDock", PRODUCT_BUNDLE_IDENTIFIER="local.trainerdock.launcher",
        INFOPLIST_FILE="Config/Info.plist",
        GENERATE_INFOPLIST_FILE="NO", CONFIGURATION_BUILD_DIR="$(TRAINERDOCK_BUILD_ROOT)",
        HEADER_SEARCH_PATHS=["$(SRCROOT)/App", "$(SRCROOT)/Core", "$(SRCROOT)/ModuleSDK", "$(TRAINERDOCK_ARCHIVE_INCLUDE)"],
        OTHER_LDFLAGS=links+["-larchive.2"]), phases_after=[embed_broker], app=True)
    objects[app]["dependencies"].append(add("app:depends:broker", "PBXTargetDependency", target=broker))
    module_targets = []
    checks = ["$(SRCROOT)/script/" + p for p in ("build.py", "managed.py", "xcode_support.py")]
    for module in released_modules():
        config_data = json.loads((module / "Build.json").read_text())
        architecture=config_data.get("architecture","arm64")
        if architecture not in ("arm64","x86_64"):raise ValueError("Unbekannte Trainerarchitektur.")
        name = "Trainer-" + module.name
        source = (module / config_data.get("sourceRoot", "Sources")).resolve()
        sources = [str((source / p).relative_to(ROOT)) for p in config_data["sources"]]
        sources += ["ModuleSDK/" + p for p in config_data.get("sdkSources", [])] + [sdk_source]
        if len({Path(p).stem for p in sources}) != len(sources):
            raise ValueError(f"{name}: duplicate object filenames must be disambiguated before generation.")
        module_path = str(module.relative_to(ROOT))
        inputs = checks + ["$(SRCROOT)/" + module_path + "/" + p for p in ("Module.json", "Build.json")]
        inputs += ["$(SRCROOT)/" + str((source / "LICENSE").relative_to(ROOT)),
                   "$(SRCROOT)/script/trainer_distribution.py"]
        test_sources = ["Tests/HiDPITests.m", *config_data.get("testSupportSources",[])]
        family = config_data.get("family", module.name)
        if family == "ResidentEvil":
            test_sources.append("Tests/ResidentEvilBridgeTests.m")
        elif family == "DeadIsland2":
            test_sources += [str(p.relative_to(ROOT)) for p in sorted((ROOT / "Tests/DeadIsland2").glob("*.m"))]
            test_sources.append("Tests/DeadIsland2OverlayHostTests.m")
        else:
            test_sources.append("Tests/BridgeTests.m")
        contract = config_data.get("nativeContractTests", "Tests/DomeKeeper/NativeContractTests.m" if family == "DomeKeeper" else None)
        if contract:
            test_sources.append(contract)
        if config_data.get("rendererTests"):test_sources.append(config_data["rendererTests"])
        inputs += ["$(SRCROOT)/" + p for p in test_sources]
        before = []
        if config_data.get("managed"):
            # Reference hashes are checked every build, including an up-to-date native target.
            before.append(shell(name + ":managed", "Compile own managed trainer (verified originals)",
                                "managed " + module.name, [], [], alwaysOutOfDate=1))
        after = shell(name + ":package", "Catalog, bridge, native and HiDPI checks",
                      "module " + module.name, inputs + ["$(TARGET_BUILD_DIR)/Trainer.dylib"],
                      ["$(TARGET_BUILD_DIR)/" + p for p in ("Module.json", "TrainerConfig.json", "LICENSE")]
                      + ["$(TARGET_TEMP_DIR)/verified.stamp"])
        extra_links = list(links)
        for framework in config_data.get("frameworks",[]):
            if not __import__("re").fullmatch(r"[A-Za-z][A-Za-z0-9]*",framework):raise ValueError("Ungültiges Modulframework.")
            extra_links += ["-framework",framework]
        for symbol in config_data.get("undefinedSymbols", []):
            if not __import__("re").fullmatch(r"_[A-Za-z][A-Za-z0-9_]*", symbol):
                raise ValueError("Invalid original runtime symbol.")
            extra_links.append("-Wl,-U," + symbol)
        target = native(name, sources, dict(
            PRODUCT_NAME="Trainer", EXECUTABLE_PREFIX="", MACH_O_TYPE="mh_dylib", ARCHS=architecture, ONLY_ACTIVE_ARCH="NO",
            LD_DYLIB_INSTALL_NAME="@rpath/Trainer.dylib", SKIP_INSTALL="YES",
            CONFIGURATION_BUILD_DIR="$(TRAINERDOCK_BUILD_ROOT)/Modules/" + module.name + ".mhtmodule",
            HEADER_SEARCH_PATHS=["$(SRCROOT)/" + str(source.relative_to(ROOT)), "$(SRCROOT)/ModuleSDK", "$(DERIVED_FILE_DIR)"],
            GCC_PREPROCESSOR_DEFINITIONS=["$(inherited)", *config_data.get("defines", [])],
            OTHER_LDFLAGS=extra_links, ENABLE_HARDENED_RUNTIME="NO"), before, [after])
        module_targets.append((name, target))

    def aggregate(name, dependencies, modules=False):
        deps = [add(name + ":depends:" + target, "PBXTargetDependency", target=target) for target in dependencies]
        inputs = checks + ["$(TRAINERDOCK_BUILD_ROOT)/TrainerDock.app/Contents/MacOS/" + p
                           for p in ("TrainerDock", "TrainerDockEpicBroker")]
        inputs += ["$(SRCROOT)/Tests/" + p for p in ("MHTTests.m", "GameIdentityTests.m", "LauncherLayoutTests.m", "UpdaterTests.m", "test_xcode_project.py")]
        inputs += ["$(SRCROOT)/" + p for p in ("Tests/EpicLaunch/MHTEpicLaunchTests.m",
                                               "Core/MHTEpicLaunch.m", "Core/MHTEpicLaunch.h")]
        inputs.append("$(SRCROOT)/script/xcode_project.py")
        if modules:
            inputs += ["$(TRAINERDOCK_BUILD_ROOT)/Modules/" + p.name + ".mhtmodule/Module.json" for p in released_modules()]
        phase = shell(name + ":checks", "Verify launcher, module signatures and layout", "launcher", inputs,
                      ["$(TARGET_TEMP_DIR)/verified.stamp"])
        target = add("target:" + name, "PBXAggregateTarget", buildConfigurationList=configurations(name, {}),
                     buildPhases=[phase], dependencies=deps, name=name, productName=name)
        targets.append(target)
        return target

    complete = aggregate("TrainerDock-Verified", [app] + [target for _, target in module_targets], modules=True)
    launcher = aggregate("TrainerDock-Launcher-Verified", [app])

    # All versioned development material is visible without adding it to a product.
    def group(folder):
        children = []
        for path in sorted(folder.iterdir(), key=lambda p: (p.is_file(), p.name.casefold())):
            if path.name.startswith(".") or path.name == "__pycache__":
                continue
            if path.is_dir():
                children.append(group(path))
            else:
                children.append(ref(str(path.relative_to(ROOT))))
        return add("group:" + str(folder.relative_to(ROOT)), "PBXGroup", children=children,
                   name=folder.name, sourceTree="<group>")

    groups = [group(ROOT / p) for p in ("App", "Core", "ModuleSDK", "Modules", "Config", "Tests", "Templates", "script", "docs")]
    groups += [ref(p) for p in ("README.md", "AGENTS.md", "LICENSE")]
    groups.append(add("products", "PBXGroup", children=products, name="Products", sourceTree="<group>"))
    main_group = add("main-group", "PBXGroup", children=groups, sourceTree="<group>")
    root = add("project", "PBXProject", attributes=dict(BuildIndependentTargetsInParallel="YES", LastUpgradeCheck="2720"),
               buildConfigurationList=configurations("project", {}), compatibilityVersion="Xcode 14.0",
               developmentRegion="de", hasScannedForEncodings=0, knownRegions=["de", "en", "Base"],
               mainGroup=main_group, productRefGroup=identifier("products"), projectDirPath="", projectRoot="", targets=targets)
    project_data = dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=root)
    write_changed(PROJECT / "project.pbxproj", ("// !$*UTF8*$!\n" + openstep(project_data) + "\n").encode())
    write_changed(PROJECT / "project.xcworkspace/contents.xcworkspacedata",
                  b'<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>\n')
    # Build paths are authoritative in xcconfig; no per-user project state is generated.
    write_changed(PROJECT / "project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings",
                  plistlib.dumps({"IDEWorkspaceSharedSettings_AutocreateContextsIfNeeded": False,
                                  "DerivedDataLocationStyle": "Absolute",
                                  "DerivedDataCustomLocation": "~/Library/Developer/TrainerDock/Xcode"}))

    def scheme(name, build_target, runnable=None):
        def reference(parent, target):
            ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target,
                          BuildableName="TrainerDock.app" if target == app else objects[target]["name"],
                          BlueprintName=objects[target]["name"], ReferencedContainer="container:TrainerDock.xcodeproj")
        tree = ET.Element("Scheme", LastUpgradeVersion="2720", version="1.3")
        action = ET.SubElement(tree, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
        entry = ET.SubElement(ET.SubElement(action, "BuildActionEntries"), "BuildActionEntry",
                              buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
        reference(entry, build_target)
        ET.SubElement(tree, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                      selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
        launch = ET.SubElement(tree, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                               selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO",
                               ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", allowLocationSimulation="NO")
        if runnable:
            reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"), runnable)
        profile = ET.SubElement(tree, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
        if runnable:
            reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"), runnable)
        ET.SubElement(tree, "AnalyzeAction", buildConfiguration="Debug")
        ET.SubElement(tree, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
        ET.indent(tree)
        write_changed(PROJECT / "xcshareddata/xcschemes" / (name + ".xcscheme"),
                      ET.tostring(tree, encoding="utf-8", xml_declaration=True) + b"\n")

    scheme("TrainerDock", complete, app)
    scheme("TrainerDock-Launcher", launcher, app)
    for name, target in module_targets:
        scheme(name, target)
    expected = {"TrainerDock", "TrainerDock-Launcher", *[name for name, _ in module_targets]}
    for path in (PROJECT / "xcshareddata/xcschemes").glob("*.xcscheme"):
        if path.stem not in expected and path.read_text().find('ReferencedContainer="container:TrainerDock.xcodeproj"') >= 0:
            raise ValueError(f"Obsolete scheme {path.name}: review/remove explicitly before regeneration.")


if __name__ == "__main__":
    generate()
    print("TrainerDock.xcodeproj aktualisiert; keine Produkte gebaut oder Apps gestartet.")
