#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
"""Build the launcher and isolated runtimes in one external, stable build tree."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
from managed import compile_managed

ROOT = Path(__file__).resolve().parent.parent

def run(args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)

def external_build_path(raw):
    path = Path(raw).expanduser().resolve()
    if path == ROOT or ROOT in path.parents or path in ROOT.parents:
        raise ValueError("Buildordner muss außerhalb des Codes liegen und darf kein übergeordneter Ordner sein.")
    if any("audit" in part.casefold() for part in path.parts):
        raise ValueError("Buildordner darf kein Audit-Ordner sein.")
    return path

def compile_object(source, output, includes, defines=()):
    flags = ["-arch", "arm64", "-mmacosx-version-min=27.0", "-fobjc-arc", "-O1", "-Wall", "-Wextra", "-Werror", f"-ffile-prefix-map={ROOT}=."]
    flags += [f"-I{x}" for x in includes] + [f"-D{x}" for x in defines]
    if source.suffix == ".mm":
        compiler = "clang++"
        flags += ["-std=c++17"]
    else:
        compiler = "clang"
    run(["xcrun", compiler, *flags, "-c", source, "-o", output])

FRAMEWORKS = ["-framework", "AppKit", "-framework", "Security", "-framework", "QuartzCore", "-framework", "Carbon", "-framework", "UniformTypeIdentifiers", "-lc++"]

def link(objects, output, dynamic=False, undefined_symbols=(), extra_flags=()):
    flags = ["-arch", "arm64", "-mmacosx-version-min=27.0"]
    if dynamic:
        flags += ["-dynamiclib", "-install_name", f"@rpath/{output.name}"]
    for symbol in undefined_symbols:
        if not dynamic or not re.fullmatch(r"_[A-Za-z][A-Za-z0-9_]*", symbol):
            raise ValueError("Ungültiges originales Laufzeitsymbol.")
        flags += [f"-Wl,-U,{symbol}"]
    run(["xcrun", "clang", *flags, *objects, *FRAMEWORKS, *extra_flags, "-o", output])

def catalog_source(backend, config):
    catalog=config.get("catalog",{})
    prefix = catalog.get("prefix", "DI2" if backend == "DeadIsland2" else "RE2" if backend == "ResidentEvil" else "MT")
    integer = "NO" if prefix == "DI2" else "f->integer"
    setup = catalog.get("setup", "MTUseCrimsonFeatures();" if backend == "CrimsonDesert" else "")
    count = catalog.get("count", f"{prefix}FeatureCount")
    function = catalog.get("function", f"{prefix}FeatureInfoAt")
    choose = f"NSInteger count={count}; const {prefix}FeatureInfo *(*info)({prefix}Feature)={function};"
    if prefix == "RE2":
        choose = '''NSInteger count=RE2FeatureCount;
        const RE2FeatureInfo *(*info)(NSInteger)=NULL;
        int game=argc>1 ? atoi(argv[1]) : 2;
        if(game==4){count=RE4FeatureCount;info=RE4FeatureInfoAt;}
        if(game==7){count=RE7FeatureCount;info=RE7FeatureInfoAt;}
        if(game==8){count=RE8FeatureCount;info=RE8FeatureInfoAt;}
        if(game==3)count=RE3FeatureCount;'''
    get = "info ? info(i) : RE2FeatureInfoForGame((RE2Feature)i,game==3)" if prefix == "RE2" else f"info(({prefix}Feature)i)"
    imports = '\n#import "RE4Features.h"\n#import "RE7Features.h"\n#import "RE8Features.h"' if prefix == "RE2" else ""
    imports += "\n"+"\n".join(f'#import "{header}"' for header in catalog.get("imports",[]))
    return f'''#import "TrainerFeatures.h"
    #import <AppKit/AppKit.h>
    {imports}
    int main(int argc,const char *argv[]){{@autoreleasepool{{
    (void)argc;(void)argv;{setup}{choose}
    NSMutableArray *rows=[NSMutableArray new];
    for(NSInteger i=0;i<count;i++){{const {prefix}FeatureInfo *f={get};
    [rows addObject:@{{@"id":@(i),@"title":f->title,@"shortcut":f->shortcut,@"detail":f->detail,
    @"implemented":@(f->implemented),@"numeric":@(f->numeric),@"oneShot":@(f->oneShot),@"integer":@({integer}),
    @"initial":@(f->initial),@"minimum":@(f->minimum),@"maximum":@(f->maximum),@"step":@(f->step),
    @"binding":[NSString stringWithFormat:@"%ld:%hu:%lu:%d:%d",(long)i,f->key,(unsigned long)f->modifiers,f->numeric,f->oneShot]}}];}}
    NSData *data=[NSJSONSerialization dataWithJSONObject:rows options:0 error:NULL];fwrite(data.bytes,1,data.length,stdout);
    }}return 0;}}
    '''

def trainer(module_dir, modules_dir, stage, common, native_objects=None):
    manifest=json.loads((module_dir/"Module.json").read_text())
    config=json.loads((module_dir/"Build.json").read_text())
    if config.get("developmentOnly"):
        raise ValueError(f"{manifest['id']}: Entwicklungs-Vorlage, kein fertiger Trainer. Native Anbindung zuerst implementieren.")
    family=config.get("family",module_dir.name)
    source=(module_dir/config.get("sourceRoot","Sources")).resolve()
    if ROOT/"Modules" not in source.parents:raise ValueError("Trainerquellen müssen im Modules-Ordner liegen.")
    print(f"Trainer module: {manifest['name']}",flush=True)
    if native_objects is None:compile_managed(module_dir,manifest,config,stage)
    objects=dict(native_objects or {});tag=module_dir.name
    for name in ([] if native_objects is not None else config["sources"]):
        obj=stage/f"{tag}-{name}.o"
        compile_object(source/name,obj,[source,ROOT/"ModuleSDK",stage],config.get("defines",[]));objects[name]=obj
    for name in ([] if native_objects is not None else config.get("sdkSources",[])):
        obj=stage/f"{tag}-SDK-{name}.o"
        compile_object(ROOT/"ModuleSDK"/name,obj,[source,ROOT/"ModuleSDK"],config.get("defines",[]));objects[name]=obj
    dest=modules_dir/(manifest["id"]+".mhtmodule");dest.mkdir(exist_ok=True)
    runtime=dest/"Trainer.dylib"
    if native_objects is None:
        link([*objects.values(),common],runtime,True,config.get("undefinedSymbols",[]))
        run(["codesign","--force","--sign","-","--timestamp=none",runtime],stdout=subprocess.DEVNULL)
    dump=stage/(tag+"-Catalog.m");dump.write_text(catalog_source(family,config))
    obj=stage/(tag+"-Catalog.o");compile_object(dump,obj,[source])
    exporter=stage/(tag+"-catalog");link([obj,*[objects[x] for x in config["catalogSources"]]],exporter)
    args=[str(config["catalogGame"])] if "catalogGame" in config else []
    manifest["features"]=json.loads(subprocess.check_output([str(exporter),*args]))
    (dest/"Module.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
    profile_config=dict(schemaVersion=1,app=dict(name=manifest["name"],bundleIdentifier="local.mht.module."+manifest["id"],version=manifest["version"],build="1"),profiles=manifest["profiles"])
    (dest/"TrainerConfig.json").write_text(json.dumps(profile_config,ensure_ascii=False,indent=2)+"\n")
    shutil.copyfile(source/"LICENSE",dest/"LICENSE")
    test_env=dict(os.environ)
    for key in ("MHT_MODULE","MHT_SESSION"):test_env.pop(key,None)
    test_env["MHT_PROFILE"]=manifest["profiles"][0]["id"]
    test_env["MHT_SELECTION"]=json.dumps({"features":{"0":{"wanted":True,"value":0}}})
    if family in ("Cyberpunk2077","CrimsonDesert","RoboCop","LiesOfP") or config.get("testSuite")=="mt":
        test_obj=stage/(tag+"-BridgeTests.o")
        compile_object(ROOT/"Tests/BridgeTests.m",test_obj,[source,ROOT/"ModuleSDK"],config.get("defines",[])+(["TEST_CRIMSON=1"] if family=="CrimsonDesert" else []))
        test_exe=stage/(tag+"-BridgeTests")
        link([test_obj,common,*[objects[x] for x in ("GameBridge.m","TrainerFeatures.m","SelectionSettings.m","OverlaySettings.m","TrainerMaterial.m")]],test_exe);run([test_exe],env=test_env)
    elif family=="ResidentEvil":
        test_obj=stage/(tag+"-BridgeTests.o");compile_object(ROOT/"Tests/ResidentEvilBridgeTests.m",test_obj,[source,ROOT/"ModuleSDK"],config.get("defines",[]))
        test_contents=stage/(tag+"-tests.app")/"Contents";(test_contents/"MacOS").mkdir(parents=True)
        (test_contents/"Info.plist").write_bytes(plistlib.dumps(dict(CFBundleIdentifier=manifest["profiles"][0]["bundleIdentifier"],CFBundleExecutable="TestBridge",CFBundlePackageType="APPL")))
        test_exe=test_contents/"MacOS/TestBridge"
        names=["GameBridge.m","TrainerFeatures.m","RE4Features.m","RE7Features.m","RE8Features.m","CheatPreferences.m","OverlaySettings.m","TrainerMaterial.m"]
        link([test_obj,common,*[objects[x] for x in names]],test_exe);run([test_exe],env=test_env)
    elif family=="DeadIsland2":
        test_objects=[]
        for test_source in sorted((ROOT/"Tests/DeadIsland2").glob("*.m")):
            obj=stage/("DI2-Test-"+test_source.stem+".o");compile_object(test_source,obj,[source]);test_objects.append(obj)
        bridge_obj=stage/"DI2-TestingBridge.o";compile_object(source/"GameBridge.m",bridge_obj,[source],["DI2_TRAINER_TESTING=1"])
        names=["GameAccess.m","GameEdition.m","TrainerFeatures.m","SelectionSettings.m","ExtraFeatures.m","OverlayInput.m"]
        test_exe=stage/"DeadIsland2-BridgeTests";link([*test_objects,bridge_obj,*[objects[x] for x in names]],test_exe);run([test_exe])
        host_obj=stage/"DeadIsland2-OverlayHostTests.o"
        compile_object(ROOT/"Tests/DeadIsland2OverlayHostTests.m",host_obj,[source,ROOT/"ModuleSDK"])
        host_exe=stage/"DeadIsland2-OverlayHostTests"
        link([host_obj,*[obj for name,obj in objects.items() if name!="Runtime.m"]],host_exe);run([host_exe])
    native_test=config.get("nativeContractTests", "Tests/DomeKeeper/NativeContractTests.m" if family=="DomeKeeper" else None)
    if native_test:
        native_obj=stage/(tag+"-NativeContractTests.o")
        compile_object(ROOT/native_test,native_obj,[source,ROOT/"ModuleSDK"])
        native_exe=stage/(tag+"-NativeContractTests")
        link([native_obj,common,*[obj for name,obj in objects.items() if name!="Runtime.m"]],native_exe);run([native_exe])
    dpi_obj=stage/(tag+"-HiDPITests.o")
    compile_object(ROOT/"Tests/HiDPITests.m",dpi_obj,[source,ROOT/"ModuleSDK"],config.get("defines",[])+(["TEST_CRIMSON=1"] if family=="CrimsonDesert" else []))
    dpi_exe=stage/(tag+"-HiDPITests")
    if family=="ResidentEvil":
        # Shared overlays select their game's catalog using the host bundle ID.
        dpi_contents=stage/(tag+"-hidpi.app")/"Contents";(dpi_contents/"MacOS").mkdir(parents=True)
        (dpi_contents/"Info.plist").write_bytes(plistlib.dumps(dict(CFBundleIdentifier=manifest["profiles"][0]["bundleIdentifier"],CFBundleExecutable="HiDPITests",CFBundlePackageType="APPL",NSHighResolutionCapable=True)))
        dpi_exe=dpi_contents/"MacOS/HiDPITests"
    link([dpi_obj,common,*[obj for name,obj in objects.items() if name!="Runtime.m"]],dpi_exe)
    run([dpi_exe],env=test_env)
    if native_objects is None:run(["codesign","--verify","--strict",runtime])
    return dest

def build(build_dir, module_id=None, launcher_only=False, configuration="Debug", version=None, build_number=None):
    """Xcode owns product compilation, incremental objects, linking and signing."""
    from xcode_project import generate, released_modules
    build_dir.mkdir(parents=True,exist_ok=True)
    marker=build_dir/".trainerdock-build"
    if not marker.exists() and any(build_dir.iterdir()):raise ValueError("Nichtleeren fremden Buildordner nicht übernehmen.")
    marker.touch()
    sdk=subprocess.check_output(["xcrun","--sdk","macosx","--show-sdk-version"],text=True).strip()
    if int(sdk.split('.')[0])<27:raise ValueError("Xcode mit macOS-27-SDK oder neuer erforderlich.")
    if module_id and module_id not in [p.name for p in released_modules()]:
        raise ValueError("Unbekanntes Modul oder Entwicklungs-Vorlage, kein fertiger Trainer.")
    if launcher_only and not (build_dir/"Modules").is_dir():
        raise ValueError("Zuerst einen vollständigen Build mit Trainermodulen erzeugen.")
    generate()
    scheme="Trainer-"+module_id if module_id else "TrainerDock-Launcher" if launcher_only else "TrainerDock"
    settings=[]
    if version:
        if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",version):raise ValueError("Ungültige App-Version.")
        settings.append("MARKETING_VERSION="+version)
    if build_number:
        if not re.fullmatch(r"[0-9]+",build_number):raise ValueError("Ungültige Buildnummer.")
        settings.append("CURRENT_PROJECT_VERSION="+build_number)
    if os.environ.get("TRAINERDOCK_MANAGED_IMAGES"):
        settings.append("TRAINERDOCK_MANAGED_IMAGES="+os.environ["TRAINERDOCK_MANAGED_IMAGES"])
    if os.environ.get("TRAINERDOCK_TEST_LUA_LIBRARY"):
        settings.append("TRAINERDOCK_TEST_LUA_LIBRARY="+os.environ["TRAINERDOCK_TEST_LUA_LIBRARY"])
    run(["xcodebuild","-project",ROOT/"TrainerDock.xcodeproj","-scheme",scheme,
         "-configuration",configuration,"-destination","platform=macOS,arch=arm64","-derivedDataPath",build_dir/"Xcode",
         "-jobs",str(min(os.cpu_count() or 2,8)),"-quiet",
         "TRAINERDOCK_BUILD_ROOT="+str(build_dir),*settings,"build"],env=dict(os.environ,PYTHONDONTWRITEBYTECODE="1"))
    from xcode_support import verify_products
    if module_id and (build_dir/"TrainerDock.app/Contents/Resources/Modules").is_dir():
        from xcode_support import bundle_modules
        bundle_modules(build_dir)
    verify_products(build_dir,module_id)
    product=build_dir/"Modules"/(module_id+".mhtmodule") if module_id else build_dir/"TrainerDock.app"
    print(f"Xcode-Build und Prüfungen erfolgreich: {product}")
    return product

if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--build-dir",default=os.environ.get("TRAINERDOCK_BUILD_DIR",os.environ.get("MHT_BUILD_DIR",str(Path.home()/"Library/Developer/TrainerDock"))))
    parser.add_argument("--module",help="Nur dieses vollständige Trainermodul bauen; den Launcher nicht neu kompilieren.")
    parser.add_argument("--launcher-only",action="store_true",help="Nur den Launcher bauen; vorhandene Trainermodule unverändert verwenden.")
    parser.add_argument("--configuration",choices=("Debug","Release"),default="Debug")
    parser.add_argument("--version",help="App-Version für einen Release-Build, z. B. 1.0.0.")
    parser.add_argument("--build-number",help="Numerische App-Buildnummer.")
    args=parser.parse_args()
    if args.module and args.launcher_only:parser.error("--module und --launcher-only schließen sich aus.")
    build(external_build_path(args.build_dir),args.module,args.launcher_only,args.configuration,args.version,args.build_number)
