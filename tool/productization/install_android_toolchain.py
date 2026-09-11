#!/usr/bin/env python3
"""Install two pinned archives in AVARYN's toolchain folder; never accept SDK licenses."""
import hashlib, json, os, pathlib, platform, shutil, stat, subprocess, tarfile, urllib.request, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASE = ROOT / '.avaryn-local/productization-20260911/toolchains'
LOCK = pathlib.Path(__file__).with_name('android-toolchain-lock.json')

def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()

def inside(base, path):
    return os.path.commonpath([str(base.resolve()), str(path.resolve())]) == str(base.resolve())

def unpack(archive, destination):
    destination.mkdir()
    if archive.name.endswith('.zip'):
        with zipfile.ZipFile(archive) as data:
            for item in data.infolist():
                target = destination / item.filename
                mode = item.external_attr >> 16
                if not inside(destination, target) or stat.S_ISLNK(mode):
                    raise RuntimeError('Unsafe ZIP member')
            data.extractall(destination)
            for item in data.infolist():
                target = destination / item.filename
                if target.is_file():
                    target.chmod((item.external_attr >> 16) & 0o777 or 0o644)
    else:
        with tarfile.open(archive) as data:
            for item in data.getmembers():
                target = destination / item.name
                if not inside(destination, target) or item.isdev() or item.isfifo():
                    raise RuntimeError('Unsafe TAR member')
                if item.issym() or item.islnk():
                    link = (target.parent if item.issym() else destination) / item.linkname
                    if not inside(destination, link):
                        raise RuntimeError('Unsafe TAR link')
            data.extractall(destination)

def main():
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise SystemExit('This lock is for macOS arm64 only.')
    BASE.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(BASE).free < 3 * 1024**3:
        raise SystemExit('At least 3 GiB free required.')
    cache = BASE / 'downloads'; cache.mkdir(exist_ok=True)
    installed = []
    for item in json.loads(LOCK.read_text())['archives']:
        archive = cache / item['filename']
        if not archive.exists():
            partial = archive.with_suffix(archive.suffix + '.partial')
            print('Downloading ' + item['name'], flush=True)
            request = urllib.request.Request(item['url'], headers={'User-Agent': 'AVARYN-project-toolchain/1.0'})
            with urllib.request.urlopen(request, timeout=60) as response, partial.open('wb') as out:
                shutil.copyfileobj(response, out, 1024 * 1024)
            if sha(partial) != item['sha256']:
                raise RuntimeError('Downloaded checksum mismatch: ' + item['name'])
            partial.rename(archive)
        if sha(archive) != item['sha256']:
            raise RuntimeError('Cached checksum mismatch: ' + item['name'])
        target = BASE / item['directory']
        stamp = target / '.avaryn-archive-sha256'
        if target.exists():
            if not stamp.is_file() or stamp.read_text().strip() != item['sha256']:
                raise RuntimeError('Existing target not owned by this pinned installation')
        else:
            unpack(archive, target)
            stamp.write_text(item['sha256'] + '\n')
        installed.append({**item, 'actual_sha256': sha(archive), 'status': 'EXTRACTED_VERIFIED'})
        print('Verified and extracted ' + item['name'], flush=True)
    jdk = next((BASE/'jdk21').glob('*/Contents/Home'))
    sdk = BASE/'android-sdk'; (sdk/'cmdline-tools').mkdir(parents=True, exist_ok=True)
    tools = BASE/'google-commandlinetools/cmdline-tools'
    link = sdk/'cmdline-tools/latest'
    if link.is_symlink():
        if link.resolve() != tools.resolve(): raise RuntimeError('Unexpected commandline-tools symlink')
    elif link.exists(): raise RuntimeError('Unexpected commandline-tools directory')
    else: link.symlink_to(os.path.relpath(tools, link.parent), target_is_directory=True)
    user = BASE/'android-user'; user.mkdir(exist_ok=True)
    avd = BASE/'avd'; avd.mkdir(exist_ok=True)
    java_options = '-Duser.home=' + str(BASE/'java-user')
    env = dict(os.environ, JAVA_HOME=str(jdk), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk), ANDROID_USER_HOME=str(user), ANDROID_AVD_HOME=str(avd), JAVA_TOOL_OPTIONS=java_options)
    checks = []
    for command in [[str(jdk/'bin/java'), '-version'], [str(jdk/'bin/javac'), '-version'], [str(link/'bin/sdkmanager'), '--sdk_root='+str(sdk), '--version']]:
        result = subprocess.run(command, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=40)
        checks.append({'command': command, 'exit': result.returncode, 'output': (result.stdout+result.stderr).strip()})
    exports = {'JAVA_HOME':str(jdk),'ANDROID_HOME':str(sdk),'ANDROID_SDK_ROOT':str(sdk),'ANDROID_USER_HOME':str(user),'ANDROID_AVD_HOME':str(avd),'JAVA_TOOL_OPTIONS':java_options,'GRADLE_USER_HOME':str(BASE/'gradle-user')}
    import shlex
    (BASE/'env.sh').write_text('# Source explicitly; no shell profile is modified.\n'+''.join('export '+key+'='+shlex.quote(value)+'\n' for key,value in exports.items())+'export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"\n')
    manifest = {'status':'READY_FOR_PERSONAL_SDK_LICENSE_REVIEW','archives':installed,'checks':checks,'license_acceptance_written':False,'sdk_licenses_directory_exists':(sdk/'licenses').exists(),'android_packages_installed':[], 'environment_script':str(BASE/'env.sh')}
    (BASE/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps({'status':manifest['status'],'checks':checks,'license_acceptance_written':False}, indent=2))
    if any(c['exit'] for c in checks): raise SystemExit(1)

if __name__ == '__main__':
    main()
